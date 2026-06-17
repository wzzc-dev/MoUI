///|
#borrow(call_closure)
#owned(callback)
extern "C" fn windows_webview_install_event_callback(
  call_closure : FuncRef[
    (
      (UInt64, Int, Bytes, Bytes, Bytes, Int) -> Unit,
      UInt64,
      Int,
      Bytes,
      Bytes,
      Bytes,
      Int,
    ) -> Unit,
  ],
  callback : (UInt64, Int, Bytes, Bytes, Bytes, Int) -> Unit,
) -> Unit = "moui_windows_webview_install_event_callback"

///|
extern "C" fn windows_webview_native_available() -> Int = "moui_windows_webview_available"

///|
extern "C" fn windows_webview_platform_views_begin(hwnd : UInt64) -> Unit = "moui_windows_webview_platform_views_begin"

///|
#borrow(id, url, title)
extern "C" fn windows_webview_sync(
  hwnd : UInt64,
  id : Bytes,
  url : Bytes,
  title : Bytes,
  policy : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_windows_webview_sync"

///|
extern "C" fn windows_webview_platform_views_end(hwnd : UInt64) -> Unit = "moui_windows_webview_platform_views_end"

///|
extern "C" fn windows_webview_platform_views_dispose(hwnd : UInt64) -> Unit = "moui_windows_webview_platform_views_dispose"

///|
#borrow(id, text, detail)
extern "C" fn windows_webview_command(
  hwnd : UInt64,
  id : Bytes,
  command : Int,
  text : Bytes,
  detail : Bytes,
) -> Unit = "moui_windows_webview_command"

///|
pub fn windows_webview_capabilities() -> @host.HostWebViewCapabilities {
  if windows_webview_native_available() != 0 {
    @host.HostWebViewCapabilities::native_available(
      description="Windows WebView2 native embedding is available.",
    )
  } else {
    @host.HostWebViewCapabilities::unavailable(
      description="Windows WebView2 native embedding is unavailable; build with MOUI_WINDOWS_ENABLE_WEBVIEW2 and the WebView2 SDK to enable it.",
    )
  }
}

///|
pub fn install_windows_webview_event_dispatcher(
  dispatch : (UInt64, String, @host.WebViewEvent) -> Unit,
) -> Unit {
  windows_webview_install_event_callback(
    fn(callback, hwnd, kind, id, url, detail, flag) {
      callback(hwnd, kind, id, url, detail, flag)
    },
    (hwnd, kind, id, url, detail, flag) => {
      dispatch(
        hwnd,
        decode_webview_string(id),
        native_webview_event(kind, url, detail, flag),
      )
    },
  )
}

///|
pub fn sync_windows_platform_views(
  window : @win.Window,
  frame : @core.DrawFrame,
) -> Unit {
  let hwnd = window.window_handle()
  windows_webview_platform_views_begin(hwnd)
  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      windows_webview_sync(
        hwnd,
        encode_webview_string(placement.id),
        encode_webview_string(placement.property_or("url", "")),
        encode_webview_string(placement.property_or("title", "")),
        webview_policy_code(
          @host.WebViewNavigationPolicy::from_revision_key(
            placement.property_or("policy", "http-https-file"),
          ),
        ),
        placement.frame.origin.x,
        placement.frame.origin.y,
        placement.frame.size.width,
        placement.frame.size.height,
      )
    }
  }
  windows_webview_platform_views_end(hwnd)
}

///|
pub fn dispose_windows_platform_views(window : @win.Window) -> Unit {
  windows_webview_platform_views_dispose(window.window_handle())
}

///|
pub fn drain_windows_webview_commands(
  window : @win.Window,
  queue : @host.HostWebViewCommandQueue,
) -> Int {
  let hwnd = window.window_handle()
  queue.drain_with_handler(command => {
    let (kind, text, detail) = encode_webview_command(command.command)
    windows_webview_command(
      hwnd,
      encode_webview_string(command.id),
      kind,
      encode_webview_string(text),
      encode_webview_string(detail),
    )
  })
}

///|
fn encode_webview_string(text : String) -> Bytes {
  @utf8.encode(text[:], bom=false)
}

///|
fn decode_webview_string(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes[:], ignore_bom=true)
}

///|
fn native_webview_event(
  kind : Int,
  url : Bytes,
  detail : Bytes,
  flag : Int,
) -> @host.WebViewEvent {
  let url_text = decode_webview_string(url)
  let detail_text = decode_webview_string(detail)
  match kind {
    0 => @host.WebViewEvent::NavigationRequested(url_text)
    1 => @host.WebViewEvent::NavigationStarted(url_text)
    2 => @host.WebViewEvent::NavigationCommitted(url_text)
    3 => @host.WebViewEvent::NavigationFinished(url_text)
    4 => @host.WebViewEvent::NavigationFailed(url_text, detail_text)
    5 => @host.WebViewEvent::TitleChanged(detail_text)
    6 => @host.WebViewEvent::CanGoBackChanged(flag != 0)
    7 => @host.WebViewEvent::CanGoForwardChanged(flag != 0)
    8 => @host.WebViewEvent::JavaScriptResult(url_text, detail_text)
    _ => @host.WebViewEvent::NavigationFailed(url_text, detail_text)
  }
}

///|
fn webview_policy_code(policy : @host.WebViewNavigationPolicy) -> Int {
  match policy {
    @host.WebViewNavigationPolicy::AllowHttpHttpsFile => 0
    @host.WebViewNavigationPolicy::AllowHttpHttps => 1
    @host.WebViewNavigationPolicy::AllowAll => 2
  }
}

///|
fn encode_webview_command(
  command : @host.WebViewCommand,
) -> (Int, String, String) {
  match command {
    @host.WebViewCommand::LoadUrl(url) => (0, url, "")
    @host.WebViewCommand::Reload => (1, "", "")
    @host.WebViewCommand::Stop => (2, "", "")
    @host.WebViewCommand::GoBack => (3, "", "")
    @host.WebViewCommand::GoForward => (4, "", "")
    @host.WebViewCommand::EvaluateJavaScript(script, request_id) =>
      (5, script, request_id)
  }
}
