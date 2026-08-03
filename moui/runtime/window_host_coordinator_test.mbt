///|
test "window coordinator keeps image loaders bound to their surfaces" {
  let first_started = Ref(0)
  let second_started = Ref(0)
  let first_loader = @render.HostAsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    first_started.val = first_started.val + 1
    Some(() => ())
  })
  let second_loader = @render.HostAsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    second_started.val = second_started.val + 1
    Some(() => ())
  })
  let coordinator = WindowHostCoordinator::new(
    window_requests=@backend_host.HostWindowRequestQueue::new(),
    scene_resolver=HostWindowSceneResolver::unavailable(),
    services=@backend_host.HostServiceBridge::unavailable(),
    event_sources=None,
  )
  let first_renderer = renderer_with_loading_image("first.png")
  let second_renderer = renderer_with_loading_image("second.png")
  let first_id = @backend_host.HostWindowId::new(1)
  let second_id = @backend_host.HostWindowId::new(2)
  ignore(
    coordinator.attach_surface(
      first_id,
      first_renderer,
      test_window_surface_actions(),
      image_loader=Some(first_loader),
    ),
  )
  ignore(
    coordinator.attach_surface(
      second_id,
      second_renderer,
      test_window_surface_actions(),
      image_loader=Some(second_loader),
    ),
  )
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let completion = @render.HostImageResourceCompletionSource::new(
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
fn renderer_with_loading_image(source : String) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(image_resources=() => {
      [@render.ImageResourceRecord::loading(source)]
    }),
  )
}

///|
fn test_window_surface_actions() -> WindowSurfaceActions {
  WindowSurfaceActions::new(
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
  )
}
