///|
test "window coordinator keeps image loaders bound to their surfaces" {
  let first_started = Ref(0)
  let second_started = Ref(0)
  let first_loader = @render_common.AsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    first_started.val = first_started.val + 1
    Some(() => ())
  })
  let second_loader = @render_common.AsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    second_started.val = second_started.val + 1
    Some(() => ())
  })
  let coordinator = WindowCoordinator::new(
    window_requests=WindowRequestQueue::new().requests(),
    scene_resolver=@runtime.WindowSceneResolver::unavailable(),
    services=@backend_host.HostServiceBridge::unavailable(),
    event_sources=None,
  )
  let first_renderer = renderer_with_loading_image("first.png")
  let second_renderer = renderer_with_loading_image("second.png")
  let first_id = @backend_host.WindowId::new(1)
  let second_id = @backend_host.WindowId::new(2)
  ignore(
    coordinator.attach_surface(
      first_id,
      first_renderer,
      test_window_surface_actions(),
      image_loader=Some(first_loader.as_loader()),
    ),
  )
  ignore(
    coordinator.attach_surface(
      second_id,
      second_renderer,
      test_window_surface_actions(),
      image_loader=Some(second_loader.as_loader()),
    ),
  )
  let tracker = @render_common.ImageResourceRepaintTracker::new()
  let completion = @render_common.ImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  let first_result = coordinator
    .schedule_image_resource_loads(first_id, first_renderer, completion)
    .unwrap()
  let second_result = coordinator
    .schedule_image_resource_loads(second_id, second_renderer, completion)
    .unwrap()
  inspect(first_result.scheduled_count(), content="1")
  inspect(second_result.scheduled_count(), content="1")
  inspect(first_started.val, content="1")
  inspect(second_started.val, content="1")
  inspect(coordinator.cancel_image_resource_loads(first_id), content="1")
  inspect(coordinator.cancel_image_resource_loads(second_id), content="1")
}

///|
test "window coordinator syncs observed resize as applied content metrics" {
  let coordinator = test_window_coordinator()
  let redraws = Ref(0)
  let applied = @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(width=640.0, height=360.0),
    physical_size=@core.Size::new(width=1280.0, height=720.0),
    scale_factor=2.0,
  )
  let actions = test_window_surface_actions(
    sync_observed_resize=_surface_metrics => applied,
    request_redraw=() => redraws.val = redraws.val + 1,
  )
  let renderer = test_window_renderer()
  let (window_id, driver) = open_test_window(coordinator, renderer, actions)
  let observed = @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(width=650.0, height=390.0),
    physical_size=@core.Size::new(width=1300.0, height=780.0),
    scale_factor=2.0,
  )
  match coordinator.sync_observed_resize(window_id, observed) {
    Some(metrics) => assert_true(metrics == applied)
    None => fail("expected observed resize to reach the attached surface")
  }
  assert_true(driver.size() == applied.logical_size)
  match coordinator.runtime_slot_lookup(window_id) {
    Some(slot) => assert_true(slot.record.metrics == applied)
    None => fail("expected resized runtime slot")
  }
  inspect(redraws.val, content="1")
}

///|
test "window coordinator clears queued frame after presented completion" {
  let drains = Ref(0)
  let renderer = @render.WindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    drain_present_completions=Some(() => {
      let call = drains.val
      drains.val = call + 1
      if call == 2 {
        [test_present_completion(@render.RenderPresentStatus::Presented)]
      } else {
        []
      }
    }),
    text_system=() => @core.TextSystem::fallback(),
  )
  let redraws = Ref(0)
  let coordinator = test_window_coordinator()
  let (window_id, driver) = open_test_window(
    coordinator,
    renderer,
    test_window_surface_actions(request_redraw=() => {
      redraws.val = redraws.val + 1
    }),
  )
  let renders = Ref(0)
  let render = (_renderer, _slot, _frame) => {
    renders.val = renders.val + 1
    if renders.val == 1 {
      @render.RenderFrameResult::new(queued=true)
    } else {
      @render.RenderFrameResult::new(presented=true)
    }
  }
  assert_false(coordinator.run_window_redraw(window_id, render~))
  assert_true(coordinator.surface_frame_pending(window_id))
  inspect(redraws.val, content="1")
  assert_false(coordinator.run_window_redraw(window_id, render~))
  assert_false(coordinator.surface_frame_pending(window_id))
  inspect(renders.val, content="1")
  driver.request_redraw()
  assert_false(coordinator.run_window_redraw(window_id, render~))
  assert_false(coordinator.surface_frame_pending(window_id))
  inspect(renders.val, content="2")
}

///|
test "window coordinator retries queued frame after dropped completion" {
  let drains = Ref(0)
  let renderer = @render.WindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    drain_present_completions=Some(() => {
      let call = drains.val
      drains.val = call + 1
      if call == 2 {
        [test_present_completion(@render.RenderPresentStatus::Dropped)]
      } else {
        []
      }
    }),
    text_system=() => @core.TextSystem::fallback(),
  )
  let redraws = Ref(0)
  let coordinator = test_window_coordinator()
  let (window_id, _driver) = open_test_window(
    coordinator,
    renderer,
    test_window_surface_actions(request_redraw=() => {
      redraws.val = redraws.val + 1
    }),
  )
  let renders = Ref(0)
  let render = (_renderer, _slot, _frame) => {
    renders.val = renders.val + 1
    if renders.val == 1 {
      @render.RenderFrameResult::new(queued=true)
    } else {
      @render.RenderFrameResult::new(presented=true)
    }
  }
  assert_false(coordinator.run_window_redraw(window_id, render~))
  assert_true(coordinator.surface_frame_pending(window_id))
  assert_false(coordinator.run_window_redraw(window_id, render~))
  assert_false(coordinator.surface_frame_pending(window_id))
  inspect(renders.val, content="2")
  // The pending submission requested one poll; its dropped terminal
  // completion requests the follow-up retry explicitly.
  inspect(redraws.val, content="2")
}

///|
test "window coordinator tears down each resource exactly once" {
  let renderer_disposals = Ref(0)
  let platform_view_disposals = Ref(0)
  let native_drops = Ref(0)
  let renderer = @render.WindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    dispose=() => renderer_disposals.val += 1,
  )
  let actions = WindowSurfaceActions::new(
    focus=() => (),
    request_resize=identity_surface_metrics,
    sync_observed_resize=identity_surface_metrics,
    set_minimized=_ => (),
    set_visible=_ => (),
    request_redraw=() => (),
    request_ime_update=_ => (),
    drop=() => native_drops.val += 1,
    native_view_handle=() => None,
    dispose_platform_views=() => platform_view_disposals.val += 1,
  )
  let coordinator = test_window_coordinator()
  let (window_id, _driver) = open_test_window(coordinator, renderer, actions)
  coordinator.dispose_window(window_id)
  coordinator.dispose_window(window_id)
  renderer.dispose()
  inspect(renderer_disposals.val, content="1")
  inspect(platform_view_disposals.val, content="1")
  inspect(native_drops.val, content="1")
  assert_true(coordinator.runtime_slots_empty())
}

///|
test "duplicate surface attach disposes the rejected renderer" {
  let rejected_disposals = Ref(0)
  let coordinator = test_window_coordinator()
  let first = test_window_renderer()
  let request = @backend_host.WindowOpenRequest::new(
    title="Test",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=32.0, height=24.0),
    ),
  )
  let window_id = match coordinator.open_resolution(request) {
    @runtime.WindowOpenResolution::OpenResolved(resolved) => resolved.id
    @runtime.WindowOpenResolution::OpenRejected(message) => fail(message)
  }
  assert_true(
    coordinator.attach_surface(window_id, first, test_window_surface_actions()),
  )
  let rejected = @render.WindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    dispose=() => rejected_disposals.val += 1,
  )
  assert_false(
    coordinator.attach_surface(
      window_id,
      rejected,
      test_window_surface_actions(),
    ),
  )
  inspect(rejected_disposals.val, content="1")
}

///|
fn renderer_with_loading_image(source : String) -> @render.WindowRenderer {
  @render.WindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(image_resources=() => {
      [@render.ImageResourceRecord::loading(source)]
    }),
  )
}

///|
fn test_window_surface_actions(
  request_resize? : (@core.SurfaceMetrics) -> @core.SurfaceMetrics = identity_surface_metrics,
  sync_observed_resize? : (@core.SurfaceMetrics) -> @core.SurfaceMetrics = identity_surface_metrics,
  request_redraw? : () -> Unit = () => (),
) -> WindowSurfaceActions {
  WindowSurfaceActions::new(
    focus=() => (),
    request_resize~,
    sync_observed_resize~,
    set_minimized=_ => (),
    set_visible=_ => (),
    request_redraw~,
    request_ime_update=_ => (),
    drop=() => (),
    native_view_handle=() => None,
    dispose_platform_views=() => (),
  )
}

///|
fn identity_surface_metrics(
  metrics : @core.SurfaceMetrics,
) -> @core.SurfaceMetrics {
  metrics
}

///|
fn test_window_coordinator() -> WindowCoordinator {
  WindowCoordinator::new(
    window_requests=WindowRequestQueue::new().requests(),
    scene_resolver=@runtime.WindowSceneResolver::new(resolve=request => {
      @runtime.WindowSceneResolution::SceneResolved(
        @runtime.WindowSceneInstance::new(
          request~,
          runtime=@runtime.AppRuntime::new_view(
            root=(@views.empty() : @core.View[Unit]),
            size=request.metrics.logical_size,
          ),
        ),
      )
    }),
    services=@backend_host.HostServiceBridge::unavailable(),
    event_sources=None,
  )
}

///|
fn test_window_renderer() -> @render.WindowRenderer {
  @render.WindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
}

///|
fn open_test_window(
  coordinator : WindowCoordinator,
  renderer : @render.WindowRenderer,
  actions : WindowSurfaceActions,
) -> (@backend_host.WindowId, @runtime.HostRuntimeDriver) raise {
  let request = @backend_host.WindowOpenRequest::new(
    title="Test",
    scene=@backend_host.WindowScene::main(),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  match coordinator.open_resolution(request) {
    @runtime.WindowOpenResolution::OpenResolved(resolved) => {
      let driver = @runtime.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      coordinator.register_primary_runtime_slot(resolved.id, driver)
      assert_true(coordinator.attach_surface(resolved.id, renderer, actions))
      (resolved.id, driver)
    }
    @runtime.WindowOpenResolution::OpenRejected(message) => fail(message)
  }
}

///|
fn test_present_completion(
  status : @render.RenderPresentStatus,
) -> @render.RenderPresentCompletion {
  @render.RenderPresentCompletion::new(
    frame_sequence=1,
    surface_generation=1,
    image_resource_revision=0L,
    submitted_at_ms=1.0,
    completed_at_ms=2.0,
    presented_at_ms=if status is @render.RenderPresentStatus::Presented {
      2.0
    } else {
      0.0
    },
    status~,
    gpu_context_generation=1,
  )
}
