///|
test "macos startup surface size preserves runtime logical dimensions" {
  let size = runtime_size_to_window_surface_size(
    @core.Size::new(width=800.0, height=600.0),
  )
  assert_eq(size.to_logical(2.0), @dpi.LogicalSize::LogicalSize(800.0, 600.0))
  assert_eq(size.to_physical(2.0), @dpi.PhysicalSize::PhysicalSize(1600, 1200))
}

///|
test "macos menu command payload records utf8 byte lengths" {
  let encoded = @utf8.decode_lossy(
    encode_menu_commands([
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
test "macos renderer provider exposes async image loader hook" {
  let loader_started = Ref(0)
  let loader = @render.HostAsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    loader_started.val = loader_started.val + 1
    None
  })
  let provider = MacosRendererProvider::new(
    create_renderer=(_window, _metrics) => None,
    image_loader=Some(loader),
  )
  let renderer = @render.HostWindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let source = @render.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  match
    provider.schedule_image_resource_loads(
      @host.HostWindowId::new(1),
      renderer,
      source,
    ) {
    Some(result) => {
      inspect(result.loading_count(), content="0")
      inspect(result.scheduled_count(), content="0")
    }
    None => fail("expected macOS async image loader hook result")
  }
  inspect(loader_started.val, content="0")
  inspect(
    provider.cancel_image_resource_loads(@host.HostWindowId::new(1)),
    content="0",
  )
}

///|
test "macos renderer provider async image hook defaults to unavailable" {
  let provider = MacosRendererProvider::new(create_renderer=(_window, _metrics) => {
    None
  })
  let renderer = @render.HostWindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let source = @render.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  match
    provider.schedule_image_resource_loads(
      @host.HostWindowId::new(2),
      renderer,
      source,
    ) {
    None => ()
    Some(_) => fail("expected absent macOS async image loader hook")
  }
}
