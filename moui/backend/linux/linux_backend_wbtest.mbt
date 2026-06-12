///|
test "linux host options carry optional scene resolver and smoke options stay separate" {
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match LinuxHostAppOptions::new().scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Linux scene resolver rejection")
  }
  assert_false(LinuxHostSmokeOptions::new().first_frame_smoke_auto_exit)
  let resolver = @host.HostWindowSceneResolver::new(resolve=request => {
    @host.HostWindowSceneResolution::SceneResolved(
      @host.HostWindowSceneInstance::new(
        request~,
        runtime=@core.AppRuntime::new_view(
          root=(@core.View::empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = LinuxHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@host.HostPlatformEventSources::new()),
  )
  let smoke_options = LinuxHostSmokeOptions::new(first_frame_smoke_auto_exit=true)
  assert_true(smoke_options.first_frame_smoke_auto_exit)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Linux platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Linux scene resolver")
  }
}

///|
test "linux renderer provider exposes async image loader hook" {
  let loader_started = Ref(0)
  let loader = @host.HostAsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    loader_started.val = loader_started.val + 1
    None
  })
  let provider = LinuxRendererProvider::new(
    create_renderer=(_window, _metrics) => None,
    image_loader=Some(loader),
  )
  let renderer = @host.HostWindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  let tracker = @host.HostImageResourceRepaintTracker::new()
  let source = @host.HostImageResourceCompletionSource::new(
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
      inspect(result.loading_count, content="0")
      inspect(result.scheduled_count, content="0")
    }
    None => fail("expected Linux async image loader hook result")
  }
  inspect(loader_started.val, content="0")
  inspect(
    provider.cancel_image_resource_loads(@host.HostWindowId::new(1)),
    content="0",
  )
}

///|
test "linux renderer provider async image hook defaults to unavailable" {
  let provider = LinuxRendererProvider::new(create_renderer=(_window, _metrics) => {
    None
  })
  let renderer = @host.HostWindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  let tracker = @host.HostImageResourceRepaintTracker::new()
  let source = @host.HostImageResourceCompletionSource::new(
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
    Some(_) => fail("expected absent Linux async image loader hook")
  }
}
