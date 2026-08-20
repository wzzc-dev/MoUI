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
#borrow(id, url, title, background, scheme)
extern "C" fn windows_webview_sync(
  hwnd : UInt64,
  id : Bytes,
  url : Bytes,
  title : Bytes,
  background : Bytes,
  scheme : Bytes,
  policy : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_windows_webview_sync"

///|
#borrow(id, allowed_origins, document_start, document_end)
extern "C" fn windows_webview_configure(
  hwnd : UInt64,
  id : Bytes,
  revision : UInt64,
  allowed_origins : Bytes,
  document_start : Bytes,
  document_end : Bytes,
) -> Unit = "moui_windows_webview_configure"

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
  host : @host.WebViewHost,
  dispatch : (UInt64, String, @core.PlatformViewEvent) -> Unit,
) -> Unit {
  windows_webview_install_event_callback(
    fn(callback, hwnd, kind, id, url, detail, flag) {
      callback(hwnd, kind, id, url, detail, flag)
    },
    (hwnd, kind, id, url, detail, flag) => {
      let id_str = @host.webview_decode_ffi_string(id)
      match
        host.accept_native_event(
          controller_id=id_str,
          kind~,
          navigation_raw=0UL,
          url=@host.webview_decode_ffi_string(url),
          detail=@host.webview_decode_ffi_string(detail),
          flag~,
        ) {
        Some(event) => dispatch(hwnd, id_str, event.to_platform_event())
        None => ()
      }
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
        @host.webview_encode_ffi_string(""),
        @host.webview_encode_ffi_string(placement.property_or("title", "")),
        @host.webview_encode_ffi_string(
          placement.property_or("background-color", ""),
        ),
        @host.webview_encode_ffi_string(
          placement.property_or("color-scheme", ""),
        ),
        0,
        placement.frame.origin.x,
        placement.frame.origin.y,
        placement.frame.size.width,
        placement.frame.size.height,
      )
      match frame.overlay_bounds {
        Some(bounds) =>
          windows_webview_sync_overlay_mask(
            hwnd,
            1,
            bounds.origin.x,
            bounds.origin.y,
            bounds.size.width,
            bounds.size.height,
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
  host : @host.WebViewHost,
) -> Int {
  let hwnd = window.native_window_handle()
  host.drain_commands(command => {
    match host.native_config(command.controller_id) {
      Some(config) =>
        windows_webview_configure(
          hwnd,
          @host.webview_encode_ffi_string(command.controller_id),
          config.revision,
          @host.webview_encode_ffi_string(config.allowed_origins),
          @host.webview_encode_ffi_string(config.document_start_script),
          @host.webview_encode_ffi_string(config.document_end_script),
        )
      None => ()
    }
    let (kind, _command_id, _navigation_id, text) = @host.webview_encode_native_command(
      command,
    )
    windows_webview_command(
      hwnd,
      @host.webview_encode_ffi_string(command.controller_id),
      kind,
      @host.webview_encode_ffi_string(text),
      @host.webview_encode_ffi_string(""),
    )
  })
}
