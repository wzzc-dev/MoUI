///|
test "windows menu command payload records utf8 byte lengths" {
  let encoded = @utf8.decode_lossy(
    @host_services_desktop.encode_menu_commands([
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
test "windows host options carry optional scene resolver and smoke options stay separate" {
  let request = @host.WindowOpenRequest::new(
    title="Inspector",
    scene=@host.WindowScene::new(scene_id="inspector"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match WindowsHostAppOptions::new().scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Windows scene resolver rejection")
  }
  assert_false(WindowsHostSmokeOptions::new().first_frame_smoke_auto_exit)
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    @runtime.WindowSceneResolution::SceneResolved(
      @runtime.WindowSceneInstance::new(
        request~,
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = WindowsHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
  )
  let smoke_options = WindowsHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
  )
  assert_true(smoke_options.first_frame_smoke_auto_exit)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Windows platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Windows scene resolver")
  }
}

///|
test "windows coordinator exposes async image loader hook" {
  let loader_started = Ref(0)
  let loader = @render_common.AsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    loader_started.val = loader_started.val + 1
    None
  })
  let coordinator = @window_host.WindowCoordinator::new(
    window_requests=@window_host.WindowRequestQueue::new().requests(),
    scene_resolver=@runtime.WindowSceneResolver::unavailable(),
    services=windows_service_bridge(),
    event_sources=None,
  )
  let renderer = @render.WindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  let tracker = @render_common.ImageResourceRepaintTracker::new()
  let completion = @render_common.ImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  ignore(
    coordinator.attach_surface(
      @host.WindowId::new(1),
      renderer,
      @window_host.WindowSurfaceActions::new(
        focus=() => (),
        request_resize=metrics => metrics,
        sync_observed_resize=metrics => metrics,
        set_minimized=_ => (),
        set_visible=_ => (),
        request_redraw=() => (),
        request_ime_update=_ => (),
        drop=() => (),
        native_view_handle=() => None,
        dispose_platform_views=() => (),
      ),
      image_loader=Some(loader.as_loader()),
    ),
  )
  match
    coordinator.schedule_image_resource_loads(
      @host.WindowId::new(1),
      renderer,
      completion,
    ) {
    Some(result) => {
      inspect(result.loading_count(), content="0")
      inspect(result.scheduled_count(), content="0")
    }
    None => fail("expected Windows coordinator async image loader hook result")
  }
  inspect(loader_started.val, content="0")
  inspect(
    coordinator.cancel_image_resource_loads(@host.WindowId::new(1)),
    content="0",
  )
}

///|
test "windows coordinator async image hook defaults to unavailable" {
  let coordinator = @window_host.WindowCoordinator::new(
    window_requests=@window_host.WindowRequestQueue::new().requests(),
    scene_resolver=@runtime.WindowSceneResolver::unavailable(),
    services=windows_service_bridge(),
    event_sources=None,
  )
  let renderer = @render.WindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  let tracker = @render_common.ImageResourceRepaintTracker::new()
  let completion = @render_common.ImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => true,
    request_redraw=_id => (),
  )
  match
    coordinator.schedule_image_resource_loads(
      @host.WindowId::new(2),
      renderer,
      completion,
    ) {
    None => ()
    Some(_) =>
      fail("expected absent Windows coordinator async image loader hook")
  }
}
