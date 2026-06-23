///|
/// WebKitGTK webview codec/queue tests. These moved with the webview host
/// code from `moui/backend/linux` when webview became a standalone addon;
/// they exercise `moui_webview/host` codecs and the Linux WebKitGTK FFI
/// surface that live in this package.
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
    @host.webview_decode_native_event(
      5,
      @host.webview_encode_ffi_string(""),
      @host.webview_encode_ffi_string("Loaded title"),
      0,
    ) {
    @host.WebViewEvent::TitleChanged("Loaded title") => ()
    _ => fail("expected Linux WebView title event")
  }
  match
    @host.webview_decode_native_event(
      6,
      @host.webview_encode_ffi_string(""),
      @host.webview_encode_ffi_string(""),
      1,
    ) {
    @host.WebViewEvent::CanGoBackChanged(true) => ()
    _ => fail("expected Linux WebView back-history event")
  }
  match
    @host.webview_decode_native_event(
      7,
      @host.webview_encode_ffi_string(""),
      @host.webview_encode_ffi_string(""),
      0,
    ) {
    @host.WebViewEvent::CanGoForwardChanged(false) => ()
    _ => fail("expected Linux WebView forward-history event")
  }
  match
    @host.webview_decode_native_event(
      8,
      @host.webview_encode_ffi_string("request-1"),
      @host.webview_encode_ffi_string("42"),
      0,
    ) {
    @host.WebViewEvent::JavaScriptResult("request-1", "42") => ()
    _ => fail("expected Linux WebView JavaScript result event")
  }
  match
    @host.webview_decode_native_event(
      4,
      @host.webview_encode_ffi_string("ftp://example.test/file"),
      @host.webview_encode_ffi_string("WebView navigation policy blocked URL"),
      0,
    ) {
    @host.WebViewEvent::NavigationFailed(url, reason) => {
      inspect(url, content="ftp://example.test/file")
      inspect(reason, content="WebView navigation policy blocked URL")
    }
    _ => fail("expected Linux WebView policy failure event")
  }
}

///|
test "linux webview encodes navigation policies and commands" {
  inspect(
    @host.webview_native_policy_code(
      @host.WebViewNavigationPolicy::AllowHttpHttpsFile,
    ),
    content="0",
  )
  inspect(
    @host.webview_native_policy_code(
      @host.WebViewNavigationPolicy::AllowHttpHttps,
    ),
    content="1",
  )
  inspect(
    @host.webview_native_policy_code(@host.WebViewNavigationPolicy::AllowAll),
    content="2",
  )
  let load = @host.webview_encode_native_command(
    @host.WebViewCommand::LoadUrl("https://example.test"),
  )
  inspect(load.0, content="0")
  inspect(load.1, content="https://example.test")
  let eval = @host.webview_encode_native_command(
    @host.WebViewCommand::EvaluateJavaScript("1 + 1", "sum"),
  )
  inspect(eval.0, content="5")
  inspect(eval.1, content="1 + 1")
  inspect(eval.2, content="sum")
}

///|
test "linux webview placement applies client decoration offset" {
  let spec = @host.WebViewSpec::new(
    id="main",
    url="https://example.test",
    title="Example",
  )
  let placement = spec.platform_view_placement(
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
    let (kind, text, detail) = @host.webview_encode_native_command(
      command.command,
    )
    commands.push("\{command.id}:\{kind}:\{text}:\{detail}")
  })
  inspect(drained, content="2")
  inspect(queue.pending_count(), content="0")
  inspect(commands[0], content="main:0:https://example.test:")
  inspect(commands[1], content="main:5:document.title:title")
}
