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
/// Start the WebKit content process before the first platform-view sync.
extern "C" fn macos_webview_prewarm() -> Unit = "moui_macos_webview_prewarm"

///|
extern "C" fn macos_webview_platform_views_begin(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_webview_platform_views_begin"

///|
#borrow(id, url, title, background, scheme)
extern "C" fn macos_webview_sync(
  raw_content_view_handle : UInt64,
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
) -> Unit = "moui_macos_webview_sync"

///|
#borrow(id)
extern "C" fn macos_webview_sync_overlay_mask(
  raw_content_view_handle : UInt64,
  id : Bytes,
  has_bounds : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_macos_webview_sync_overlay_mask"

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
  dispatch : (UInt64, String, @host.WebViewEvent) -> Unit,
) -> Unit {
  macos_webview_install_event_callback(
    fn(callback, raw_handle, kind, id, url, detail, flag) {
      callback(raw_handle, kind, id, url, detail, flag)
    },
    (raw_handle, kind, id, url, detail, flag) => {
      dispatch(
        raw_handle,
        @host.webview_decode_ffi_string(id),
        @host.webview_decode_native_event(kind, url, detail, flag),
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
            @host.webview_encode_ffi_string(placement.id),
            @host.webview_encode_ffi_string(placement.property_or("url", "")),
            @host.webview_encode_ffi_string(placement.property_or("title", "")),
            @host.webview_encode_ffi_string(placement.property_or("background-color", "")),
            @host.webview_encode_ffi_string(placement.property_or("color-scheme", "")),
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
            Some(bounds) =>
              macos_webview_sync_overlay_mask(
                raw_content_view_handle,
                @host.webview_encode_ffi_string(placement.id),
                1,
                bounds.origin.x,
                bounds.origin.y,
                bounds.size.width,
                bounds.size.height,
              )
            None =>
              macos_webview_sync_overlay_mask(
                raw_content_view_handle,
                @host.webview_encode_ffi_string(placement.id),
                0,
                0.0,
                0.0,
                0.0,
                0.0,
              )
          }
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
        let (kind, text, detail) = @host.webview_encode_native_command(
          command.command,
        )
        macos_webview_command(
          raw_content_view_handle,
          @host.webview_encode_ffi_string(command.id),
          kind,
          @host.webview_encode_ffi_string(text),
          @host.webview_encode_ffi_string(detail),
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
