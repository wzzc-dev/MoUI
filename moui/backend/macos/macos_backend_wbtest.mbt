///|
test "macos startup surface size preserves runtime logical dimensions" {
  let size = @host.core_size_to_window_surface_size(
    @core.Size::new(width=800.0, height=600.0),
  )
  assert_eq(size.to_logical(2.0), @dpi.LogicalSize::LogicalSize(800.0, 600.0))
  assert_eq(size.to_physical(2.0), @dpi.PhysicalSize::PhysicalSize(1600, 1200))
}

///|
test "macos menu command payload records utf8 byte lengths" {
  let encoded = @utf8.decode_lossy(
    @platform_bridge.encode_menu_commands([
      @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Paste,
        label="粘贴",
        enabled=false,
      ),
    ])[:],
    ignore_bom=false,
  )
  inspect(encoded, content="1:4:Copy\n0:6:粘贴")
}

///|
test "macos host options carry optional scene resolver and smoke options stay separate" {
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match MacosHostAppOptions::new().scene_resolver.resolve(request) {
    @runtime.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default macOS scene resolver rejection")
  }
  let resolver = @runtime.HostWindowSceneResolver::new(resolve=request => {
    @runtime.HostWindowSceneResolution::SceneResolved(
      @runtime.HostWindowSceneInstance::new(
        request~,
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = MacosHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
  )
  let smoke_options = MacosHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
    native_ime_runtime_smoke=true,
  )
  assert_true(smoke_options.first_frame_smoke_auto_exit)
  assert_true(smoke_options.native_ime_runtime_smoke)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured macOS platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @runtime.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured macOS scene resolver")
  }
}

///|
test "macos coordinator exposes async image loader hook" {
  let loader_started = Ref(0)
  let loader = @render.HostAsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    loader_started.val = loader_started.val + 1
    None
  })
  let coordinator = @runtime.WindowHostCoordinator::new(
    window_requests=@host.HostWindowRequestQueue::new(),
    scene_resolver=@runtime.HostWindowSceneResolver::unavailable(),
    services=macos_service_bridge(),
    event_sources=None,
  )
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
  )
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let completion = @render.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  ignore(
    coordinator.attach_surface(
      @host.HostWindowId::new(1),
      renderer,
      @runtime.WindowSurfaceActions::new(
        focus=() => (),
        request_surface_size=_ => (),
        sync_surface=_ => (),
        renderer_resize=_ => (),
        set_minimized=_ => (),
        set_visible=_ => (),
        request_redraw=() => (),
        request_ime_update=_ => (),
        drop=() => (),
        native_view_handle=() => None,
        dispose_platform_views=() => (),
      ),
      image_loader=Some(loader),
    ),
  )
  match
    coordinator.schedule_image_resource_loads(
      @host.HostWindowId::new(1),
      renderer,
      completion,
    ) {
    Some(result) => {
      inspect(result.loading_count(), content="0")
      inspect(result.scheduled_count(), content="0")
    }
    None => fail("expected macOS coordinator async image loader hook result")
  }
  inspect(loader_started.val, content="0")
  inspect(
    coordinator.cancel_image_resource_loads(@host.HostWindowId::new(1)),
    content="0",
  )
}

///|
test "macos coordinator async image hook defaults to unavailable" {
  let coordinator = @runtime.WindowHostCoordinator::new(
    window_requests=@host.HostWindowRequestQueue::new(),
    scene_resolver=@runtime.HostWindowSceneResolver::unavailable(),
    services=macos_service_bridge(),
    event_sources=None,
  )
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
  )
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let completion = @render.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  match
    coordinator.schedule_image_resource_loads(
      @host.HostWindowId::new(2),
      renderer,
      completion,
    ) {
    None => ()
    Some(_) => fail("expected absent macOS coordinator async image loader hook")
  }
}

///|
/// Regression for the 0408aee7 WindowHostCoordinator refactor: `redraw_window`
/// used to persist `frame_pending = false` into the platform slot before
/// processing a terminal present completion. The refactor only cleared a local
/// copy and persisted the coordinator flag after the draw, so the
/// idle-runtime early return left the coordinator `frame_pending=true`. The
/// next redraw request then entered the `frame_pending && !prior_terminal`
/// poll branch forever, re-requesting redraws without ever drawing (showcase
/// froze after one sidebar click). The backends must persist the cleared flag
/// at the same point the pre-refactor code did; this test pins that contract.
test "macos surface frame pending handoff must persist clear or the next redraw wedges" {
  // Pass A with the fixed backend preamble: clearing the coordinator flag
  // before the idle-runtime early return must leave the surface drawable.
  let (fixed_pending, fixed_polls) = run_frame_pending_handoff(
    persist_clear=true,
  )
  assert_false(fixed_pending)
  inspect(fixed_polls, content="0")
  // Pass A with the buggy preamble (clear only a local copy): the stale flag
  // re-enters the poll branch on the next redraw request, spinning forever
  // without drawing.
  let (buggy_pending, buggy_polls) = run_frame_pending_handoff(
    persist_clear=false,
  )
  assert_true(buggy_pending)
  assert_true(buggy_polls > 0)
}

///|
fn run_frame_pending_handoff(persist_clear~ : Bool) -> (Bool, Int) {
  let coordinator = @runtime.WindowHostCoordinator::new(
    window_requests=@host.HostWindowRequestQueue::new(),
    scene_resolver=@runtime.HostWindowSceneResolver::unavailable(),
    services=macos_service_bridge(),
    event_sources=None,
  )
  let window_id = @host.HostWindowId::new(7)
  let completions_drained = Ref(0)
  let redraws = Ref(0)
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    drain_present_completions=Some(() => {
      let drained = completions_drained.val
      completions_drained.val = drained + 1
      if drained == 0 {
        [
          @render.RenderPresentCompletion::new(
            frame_sequence=1,
            surface_generation=0,
            image_resource_revision=0L,
            submitted_at_ms=0.0,
            completed_at_ms=16.0,
            presented_at_ms=16.0,
            status=@render.RenderPresentStatus::Presented,
            gpu_context_generation=0,
          ),
        ]
      } else {
        []
      }
    }),
    text_system=() => @core.TextSystem::fallback(),
  )
  ignore(
    coordinator.attach_surface(
      window_id,
      renderer,
      @runtime.WindowSurfaceActions::new(
        focus=() => (),
        request_surface_size=_ => (),
        sync_surface=_ => (),
        renderer_resize=_ => (),
        set_minimized=_ => (),
        set_visible=_ => (),
        request_redraw=() => redraws.val = redraws.val + 1,
        request_ime_update=_ => (),
        drop=() => (),
        native_view_handle=() => None,
        dispose_platform_views=() => (),
      ),
    ),
  )
  coordinator.set_surface_frame_pending(window_id, true)
  // Redraw pass A: the queued frame's terminal present completion arrives.
  let prior_completions = renderer.drain_present_completions()
  let prior_presented = @render.render_present_completions_have_presented(
    prior_completions,
  )
  let prior_terminal = @render.render_present_completions_have_terminal(
    prior_completions,
  )
  let _ = (prior_presented, prior_terminal)
  let mut frame_pending = coordinator.surface_frame_pending(window_id)
  if frame_pending {
    frame_pending = false
    if persist_clear {
      coordinator.set_surface_frame_pending(window_id, frame_pending)
    }
  }
  let pending_after_handoff = coordinator.surface_frame_pending(window_id)
  // Redraw pass B (e.g. a hover repaint): if the flag is still stale-true and
  // no completion is pending, the backend re-enters the poll branch and
  // re-requests a redraw without drawing — the wedge.
  let next_completions = renderer.drain_present_completions()
  let next_terminal = @render.render_present_completions_have_terminal(
    next_completions,
  )
  let poll_redraws = if coordinator.surface_frame_pending(window_id) &&
    !next_terminal {
    redraws.val = redraws.val + 1
    1
  } else {
    0
  }
  (pending_after_handoff, poll_redraws)
}
