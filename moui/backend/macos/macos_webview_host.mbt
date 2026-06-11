///|
#borrow(call_closure)
#owned(callback)
extern "C" fn macos_webview_install_event_callback(
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
) -> Unit = "moui_macos_webview_install_event_callback"

///|
extern "C" fn macos_webview_native_available() -> Int = "moui_macos_webview_available"

///|
extern "C" fn macos_webview_platform_views_begin(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_webview_platform_views_begin"

///|
#borrow(id, url, title)
extern "C" fn macos_webview_sync(
  raw_content_view_handle : UInt64,
  id : Bytes,
  url : Bytes,
  title : Bytes,
  policy : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_macos_webview_sync"

///|
extern "C" fn macos_webview_platform_views_end(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_webview_platform_views_end"

///|
extern "C" fn macos_webview_platform_views_dispose(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_webview_platform_views_dispose"

///|
#borrow(id, text, detail)
extern "C" fn macos_webview_command(
  raw_content_view_handle : UInt64,
  id : Bytes,
  command : Int,
  text : Bytes,
  detail : Bytes,
) -> Unit = "moui_macos_webview_command"

///|
pub fn macos_webview_capabilities() -> @host.HostWebViewCapabilities {
  if macos_webview_native_available() != 0 {
    @host.HostWebViewCapabilities::native_available(
      description="macOS WKWebView native embedding is available.",
    )
  } else {
    @host.HostWebViewCapabilities::unavailable(
      description="macOS WKWebView native embedding is unavailable.",
    )
  }
}

///|
pub fn install_macos_webview_event_dispatcher(
  dispatch : (UInt64, String, @core.WebViewEvent) -> Unit,
) -> Unit {
  macos_webview_install_event_callback(
    fn(callback, raw_handle, kind, id, url, detail, flag) {
      callback(raw_handle, kind, id, url, detail, flag)
    },
    (raw_handle, kind, id, url, detail, flag) => {
      dispatch(
        raw_handle,
        decode_webview_string(id),
        native_webview_event(kind, url, detail, flag),
      )
    },
  )
}

///|
pub fn sync_macos_platform_views(
  window : @window_macos.Window,
  frame : @core.DrawFrame,
) -> Unit {
  match macos_content_view_handle(window) {
    Some(raw_content_view_handle) => {
      macos_webview_platform_views_begin(raw_content_view_handle)
      for placement in frame.platform_views {
        if placement.kind == "web_view" {
          macos_webview_sync(
            raw_content_view_handle,
            encode_webview_string(placement.id),
            encode_webview_string(placement.url),
            encode_webview_string(placement.title),
            webview_policy_code(placement.policy),
            placement.frame.origin.x,
            placement.frame.origin.y,
            placement.frame.size.width,
            placement.frame.size.height,
          )
        }
      }
      macos_webview_platform_views_end(raw_content_view_handle)
    }
    None => ()
  }
}

///|
pub fn dispose_macos_platform_views(window : @window_macos.Window) -> Unit {
  match macos_content_view_handle(window) {
    Some(raw_content_view_handle) =>
      macos_webview_platform_views_dispose(raw_content_view_handle)
    None => ()
  }
}

///|
pub fn drain_macos_webview_commands(
  window : @window_macos.Window,
  queue : @host.HostWebViewCommandQueue,
) -> Int {
  match macos_content_view_handle(window) {
    Some(raw_content_view_handle) =>
      queue.drain_with_handler(command => {
        let (kind, text, detail) = encode_webview_command(command.command)
        macos_webview_command(
          raw_content_view_handle,
          encode_webview_string(command.id),
          kind,
          encode_webview_string(text),
          encode_webview_string(detail),
        )
      })
    None => 0
  }
}

///|
fn macos_content_view_handle(window : @window_macos.Window) -> UInt64? {
  Some(window.content_view_handle()) catch {
    _ => None
  }
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
) -> @core.WebViewEvent {
  let url_text = decode_webview_string(url)
  let detail_text = decode_webview_string(detail)
  match kind {
    0 => @core.WebViewEvent::NavigationRequested(url_text)
    1 => @core.WebViewEvent::NavigationStarted(url_text)
    2 => @core.WebViewEvent::NavigationCommitted(url_text)
    3 => @core.WebViewEvent::NavigationFinished(url_text)
    4 => @core.WebViewEvent::NavigationFailed(url_text, detail_text)
    5 => @core.WebViewEvent::TitleChanged(detail_text)
    6 => @core.WebViewEvent::CanGoBackChanged(flag != 0)
    7 => @core.WebViewEvent::CanGoForwardChanged(flag != 0)
    8 => @core.WebViewEvent::JavaScriptResult(url_text, detail_text)
    _ => @core.WebViewEvent::NavigationFailed(url_text, detail_text)
  }
}

///|
fn webview_policy_code(policy : @core.WebViewNavigationPolicy) -> Int {
  match policy {
    @core.WebViewNavigationPolicy::AllowHttpHttpsFile => 0
    @core.WebViewNavigationPolicy::AllowHttpHttps => 1
    @core.WebViewNavigationPolicy::AllowAll => 2
  }
}

///|
fn encode_webview_command(
  command : @core.WebViewCommand,
) -> (Int, String, String) {
  match command {
    @core.WebViewCommand::LoadUrl(url) => (0, url, "")
    @core.WebViewCommand::Reload => (1, "", "")
    @core.WebViewCommand::Stop => (2, "", "")
    @core.WebViewCommand::GoBack => (3, "", "")
    @core.WebViewCommand::GoForward => (4, "", "")
    @core.WebViewCommand::EvaluateJavaScript(script, request_id) =>
      (5, script, request_id)
  }
}
