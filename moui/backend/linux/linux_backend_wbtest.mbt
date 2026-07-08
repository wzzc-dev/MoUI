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
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = LinuxHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@host.HostPlatformEventSources::new()),
  )
  let smoke_options = LinuxHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
  )
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
      inspect(result.loading_count(), content="0")
      inspect(result.scheduled_count(), content="0")
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

///|
test "linux at-spi binding publishes semantics dispatches actions and disposes" {
  let invoked = Ref(0)
  let child = @core.SemanticsNode::{
    element_id: @core.ElementId::new(12),
    role: @core.SemanticsRole::Button,
    label: "Apply",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=4.0, y=4.0, width=80.0, height=32.0),
    children: [],
  }
  let root = @core.SemanticsNode::{
    element_id: @core.ElementId::new(11),
    role: @core.SemanticsRole::Group,
    label: "Panel",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=120.0, height=80.0),
    children: [child],
  }
  let binding = LinuxATSPIBinding::new(root~, dispatch=(
    element_id,
    action,
    _value,
  ) => {
    if element_id == @core.ElementId::new(12) &&
      action == @core.SemanticsAction::Activate {
      invoked.val = invoked.val + 1
      true
    } else {
      false
    }
  })
  let published = binding.publish_semantics(root)
  inspect(published.native_binding_ready, content="true")
  inspect(published.published_node_count, content="2")
  inspect(published.disposed, content="false")
  match
    binding.perform_action(
      @host.NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(12),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @host.NativeAccessibilityActionResult::Handled => ()
    _ => fail("expected Linux AT-SPI action dispatch")
  }
  inspect(invoked.val, content="1")
  inspect(binding.diagnostics().action_dispatch_count, content="1")
  let disposed = binding.dispose()
  inspect(disposed.published_node_count, content="0")
  inspect(disposed.disposed, content="true")
  match
    binding.perform_action(
      @host.NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(12),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @host.NativeAccessibilityActionResult::BridgeUnavailable(message) =>
      inspect(message, content="Linux AT-SPI binding is disposed")
    _ => fail("expected disposed Linux AT-SPI binding to reject actions")
  }
}
