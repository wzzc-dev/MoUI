///|
test "windows menu command payload records utf8 byte lengths" {
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
test "windows host options carry optional scene resolver and first-frame smoke" {
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match WindowsHostAppOptions::new().scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Windows scene resolver rejection")
  }
  assert_false(WindowsHostAppOptions::new().exit_after_first_present)
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
  let options = WindowsHostAppOptions::new(
    scene_resolver=resolver,
    exit_after_first_present=true,
    event_sources=Some(@host.HostPlatformEventSources::new()),
  )
  assert_true(options.exit_after_first_present)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Windows platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Windows scene resolver")
  }
}

///|
test "windows renderer provider exposes async image loader hook" {
  let loader_started = Ref(0)
  let loader = @host.HostAsyncImageLoader::new(start_load=(
    _id,
    _source,
    _complete,
  ) => {
    loader_started.val = loader_started.val + 1
    None
  })
  let provider = WindowsRendererProvider::new(
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
    None => fail("expected Windows async image loader hook result")
  }
  inspect(loader_started.val, content="0")
  inspect(
    provider.cancel_image_resource_loads(@host.HostWindowId::new(1)),
    content="0",
  )
}

///|
test "windows renderer provider async image hook defaults to unavailable" {
  let provider = WindowsRendererProvider::new(create_renderer=(
    _window,
    _metrics,
  ) => None)
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
    Some(_) => fail("expected absent Windows async image loader hook")
  }
}
