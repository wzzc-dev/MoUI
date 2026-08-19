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
extern "C" fn windows_webview_sync_overlay_mask(
  hwnd : UInt64,
  has_bounds : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_windows_webview_sync_overlay_mask"

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
        @host.webview_decode_ffi_string(id),
        @host.webview_decode_native_event(kind, url, detail, flag),
      )
    },
  )
}

///|
pub fn sync_windows_platform_views(
  window : @win.Window,
  frame : @core.DrawFrame,
) -> Unit {
  let hwnd = window.native_window_handle()
  windows_webview_platform_views_begin(hwnd)
  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      windows_webview_sync(
        hwnd,
        @host.webview_encode_ffi_string(placement.id),
        @host.webview_encode_ffi_string(placement.property_or("url", "")),
        @host.webview_encode_ffi_string(placement.property_or("title", "")),
        @host.webview_native_policy_code(
          @host.WebViewNavigationPolicy::from_wire_value(
            placement.property_or("policy", "http-https-file"),
          ),
        ),
        placement.frame.origin.x,
        placement.frame.origin.y,
        placement.frame.size.width,
        placement.frame.size.height,
      )
      match frame.overlay_bounds {
        Some(bounds) => windows_webview_sync_overlay_mask(
          hwnd, 1, bounds.origin.x, bounds.origin.y,
          bounds.size.width, bounds.size.height,
        )
        None => windows_webview_sync_overlay_mask(hwnd, 0, 0.0, 0.0, 0.0, 0.0)
      }
    }
  }
  windows_webview_platform_views_end(hwnd)
}

///|
pub fn dispose_windows_platform_views(window : @win.Window) -> Unit {
  windows_webview_platform_views_dispose(window.native_window_handle())
}

///|
pub fn drain_windows_webview_commands(
  window : @win.Window,
  queue : @host.HostWebViewCommandQueue,
) -> Int {
  let hwnd = window.native_window_handle()
  queue.drain_with_handler(command => {
    let (kind, text, detail) = @host.webview_encode_native_command(
      command.command,
    )
    windows_webview_command(
      hwnd,
      @host.webview_encode_ffi_string(command.id),
      kind,
      @host.webview_encode_ffi_string(text),
      @host.webview_encode_ffi_string(detail),
    )
  })
}
