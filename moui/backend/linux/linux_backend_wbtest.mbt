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

///|
test "linux webview fallback reports unavailable without WebKitGTK" {
  let capabilities = linux_webview_capabilities()
  if linux_webview_native_available() == 0 {
    inspect(capabilities.available, content="false")
    inspect(capabilities.native_embedding, content="false")
    assert_true(
      capabilities.description.contains("MOUI_LINUX_ENABLE_WEBKITGTK"),
    )
  } else {
    inspect(capabilities.available, content="true")
    inspect(capabilities.commands, content="true")
    inspect(capabilities.javascript_evaluation, content="true")
  }
}

///|
test "linux webview maps native title history javascript and policy events" {
  match
    native_webview_event(
      5,
      encode_webview_string(""),
      encode_webview_string("Loaded title"),
      0,
    ) {
    @core.WebViewEvent::TitleChanged("Loaded title") => ()
    _ => fail("expected Linux WebView title event")
  }
  match
    native_webview_event(
      6,
      encode_webview_string(""),
      encode_webview_string(""),
      1,
    ) {
    @core.WebViewEvent::CanGoBackChanged(true) => ()
    _ => fail("expected Linux WebView back-history event")
  }
  match
    native_webview_event(
      7,
      encode_webview_string(""),
      encode_webview_string(""),
      0,
    ) {
    @core.WebViewEvent::CanGoForwardChanged(false) => ()
    _ => fail("expected Linux WebView forward-history event")
  }
  match
    native_webview_event(
      8,
      encode_webview_string("request-1"),
      encode_webview_string("42"),
      0,
    ) {
    @core.WebViewEvent::JavaScriptResult("request-1", "42") => ()
    _ => fail("expected Linux WebView JavaScript result event")
  }
  match
    native_webview_event(
      4,
      encode_webview_string("ftp://example.test/file"),
      encode_webview_string("WebView navigation policy blocked URL"),
      0,
    ) {
    @core.WebViewEvent::NavigationFailed(url, reason) => {
      inspect(url, content="ftp://example.test/file")
      inspect(reason, content="WebView navigation policy blocked URL")
    }
    _ => fail("expected Linux WebView policy failure event")
  }
}

///|
test "linux webview encodes navigation policies and commands" {
  inspect(
    webview_policy_code(@core.WebViewNavigationPolicy::AllowHttpHttpsFile),
    content="0",
  )
  inspect(
    webview_policy_code(@core.WebViewNavigationPolicy::AllowHttpHttps),
    content="1",
  )
  inspect(
    webview_policy_code(@core.WebViewNavigationPolicy::AllowAll),
    content="2",
  )
  let load = encode_webview_command(
    @core.WebViewCommand::LoadUrl("https://example.test"),
  )
  inspect(load.0, content="0")
  inspect(load.1, content="https://example.test")
  let eval = encode_webview_command(
    @core.WebViewCommand::EvaluateJavaScript("1 + 1", "sum"),
  )
  inspect(eval.0, content="5")
  inspect(eval.1, content="1 + 1")
  inspect(eval.2, content="sum")
}

///|
test "linux webview placement applies client decoration offset" {
  let placement = @core.PlatformViewPlacement::web_view(
    spec=@core.WebViewSpec::new(
      id="main",
      url="https://example.test",
      title="Example",
    ),
    frame=@core.Rect::new(x=12.0, y=24.0, width=320.0, height=180.0),
  )
  let frame = linux_webview_platform_frame(placement, 32.0)
  inspect(frame.origin.x, content="12")
  inspect(frame.origin.y, content="56")
  inspect(frame.size.width, content="320")
  inspect(frame.size.height, content="180")
}

///|
test "linux webview command queue drains FIFO through host contract" {
  let queue = @host.HostWebViewCommandQueue::new()
  queue.load_url(id="main", url="https://example.test")
  queue.evaluate_javascript(
    id="main",
    script="document.title",
    request_id="title",
  )
  inspect(queue.pending_count(), content="2")
  let commands : Array[String] = []
  let drained = queue.drain_with_handler(command => {
    let (kind, text, detail) = encode_webview_command(command.command)
    commands.push("\{command.id}:\{kind}:\{text}:\{detail}")
  })
  inspect(drained, content="2")
  inspect(queue.pending_count(), content="0")
  inspect(commands[0], content="main:0:https://example.test:")
  inspect(commands[1], content="main:5:document.title:title")
}
