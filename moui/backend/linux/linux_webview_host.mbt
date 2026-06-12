///|
#borrow(call_closure)
#owned(callback)
extern "C" fn linux_webview_install_event_callback(
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
) -> Unit = "moui_linux_webview_install_event_callback"

///|
extern "C" fn linux_webview_native_available() -> Int = "moui_linux_webview_available"

///|
extern "C" fn linux_webview_pump(max_iterations : Int) -> Int = "moui_linux_webview_pump"

///|
extern "C" fn linux_webview_has_active_work() -> Int = "moui_linux_webview_has_active_work"

///|
extern "C" fn linux_webview_next_tick_ms(delay_ms : Int) -> Int64 = "moui_linux_webview_next_tick_ms"

///|
extern "C" fn linux_webview_platform_views_begin(wl_surface : UInt64) -> Unit = "moui_linux_webview_platform_views_begin"

///|
#borrow(id, url, title)
extern "C" fn linux_webview_sync(
  wl_display : UInt64,
  wl_surface : UInt64,
  id : Bytes,
  url : Bytes,
  title : Bytes,
  policy : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_linux_webview_sync"

///|
extern "C" fn linux_webview_platform_views_end(wl_surface : UInt64) -> Unit = "moui_linux_webview_platform_views_end"

///|
extern "C" fn linux_webview_platform_views_dispose(wl_surface : UInt64) -> Unit = "moui_linux_webview_platform_views_dispose"

///|
#borrow(id, text, detail)
extern "C" fn linux_webview_command(
  wl_surface : UInt64,
  id : Bytes,
  command : Int,
  text : Bytes,
  detail : Bytes,
) -> Unit = "moui_linux_webview_command"

///|
pub fn linux_webview_capabilities() -> @host.HostWebViewCapabilities {
  if linux_webview_native_available() != 0 {
    @host.HostWebViewCapabilities::native_available(
      description="Linux WebKitGTK native embedding is available.",
    )
  } else {
    @host.HostWebViewCapabilities::unavailable(
      description="Linux WebKitGTK native embedding is unavailable; build with MOUI_LINUX_ENABLE_WEBKITGTK and matching native dependencies to enable it.",
    )
  }
}

///|
fn pump_linux_webview_runtime(max_iterations? : Int = 64) -> Bool {
  let pumped = linux_webview_pump(max_iterations)
  pumped > 0 || linux_webview_has_active_work() != 0
}

///|
fn linux_webview_runtime_next_tick_ms(delay_ms? : Int = 16) -> Int64 {
  linux_webview_next_tick_ms(delay_ms)
}

///|
pub fn install_linux_webview_event_dispatcher(
  dispatch : (UInt64, String, @core.WebViewEvent) -> Unit,
) -> Unit {
  linux_webview_install_event_callback(
    fn(callback, wl_surface, kind, id, url, detail, flag) {
      callback(wl_surface, kind, id, url, detail, flag)
    },
    (wl_surface, kind, id, url, detail, flag) => {
      dispatch(
        wl_surface,
        decode_webview_string(id),
        native_webview_event(kind, url, detail, flag),
      )
    },
  )
}

///|
pub fn sync_linux_platform_views(
  window : @window_linux.Window,
  frame : @core.DrawFrame,
  content_offset_y? : Double = 0.0,
) -> Unit {
  let wl_display = window.wl_display()
  let wl_surface = window.wl_surface()
  linux_webview_platform_views_begin(wl_surface)
  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      let platform_frame = linux_webview_platform_frame(
        placement,
        content_offset_y,
      )
      linux_webview_sync(
        wl_display,
        wl_surface,
        encode_webview_string(placement.id),
        encode_webview_string(placement.url),
        encode_webview_string(placement.title),
        webview_policy_code(placement.policy),
        platform_frame.origin.x,
        platform_frame.origin.y,
        platform_frame.size.width,
        platform_frame.size.height,
      )
    }
  }
  linux_webview_platform_views_end(wl_surface)
}

///|
fn linux_webview_platform_frame(
  placement : @core.PlatformViewPlacement,
  content_offset_y : Double,
) -> @core.Rect {
  @core.Rect::new(
    x=placement.frame.origin.x,
    y=placement.frame.origin.y + content_offset_y,
    width=placement.frame.size.width,
    height=placement.frame.size.height,
  )
}

///|
pub fn dispose_linux_platform_views(window : @window_linux.Window) -> Unit {
  linux_webview_platform_views_dispose(window.wl_surface())
}

///|
pub fn drain_linux_webview_commands(
  window : @window_linux.Window,
  queue : @host.HostWebViewCommandQueue,
) -> Int {
  let wl_surface = window.wl_surface()
  queue.drain_with_handler(command => {
    let (kind, text, detail) = encode_webview_command(command.command)
    linux_webview_command(
      wl_surface,
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
