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
  visible : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_macos_webview_sync"

///|
#borrow(id, regions)
extern "C" fn macos_webview_set_no_drag_regions(
  raw_content_view_handle : UInt64,
  id : Bytes,
  regions : Bytes,
) -> Unit = "moui_macos_webview_set_no_drag_regions"

///|
#borrow(id, allowed_origins, document_start, document_end)
extern "C" fn macos_webview_configure(
  raw_content_view_handle : UInt64,
  id : Bytes,
  revision : UInt64,
  allowed_origins : Bytes,
  document_start : Bytes,
  document_end : Bytes,
) -> Unit = "moui_macos_webview_configure"

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
  host : @host.WebViewHost,
  dispatch : (UInt64, String, @core.PlatformViewEvent) -> Unit,
) -> Unit {
  macos_webview_install_event_callback(
    fn(callback, raw_handle, kind, id, url, detail, flag) {
      callback(raw_handle, kind, id, url, detail, flag)
    },
    (raw_handle, kind, id, url, detail, flag) => {
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
        Some(event) => dispatch(raw_handle, id_str, event.to_platform_event())
        None => ()
      }
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
      let has_visible_webview = frame.platform_views.any(placement => {
        placement.kind == "web_view" &&
        placement.property_or("visible", "true") == "true"
      })
      macos_webview_platform_views_begin(raw_content_view_handle)
      for placement in frame.platform_views {
        if placement.kind == "web_view" {
          macos_webview_sync(
            raw_content_view_handle,
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
            if placement.property_or("visible", "true") == "true" {
              1
            } else {
              0
            },
            placement.frame.origin.x,
            placement.frame.origin.y,
            placement.frame.size.width,
            placement.frame.size.height,
          )
          macos_webview_set_no_drag_regions(
            raw_content_view_handle,
            @host.webview_encode_ffi_string(placement.id),
            @host.webview_encode_ffi_string(
              placement.property_or("no-drag-regions", "[]"),
            ),
          )
          match
            (placement.property_or("visible", "true"), frame.overlay_bounds) {
            ("true", Some(bounds)) =>
              macos_webview_sync_overlay_mask(
                raw_content_view_handle,
                @host.webview_encode_ffi_string(placement.id),
                1,
                bounds.origin.x,
                bounds.origin.y,
                bounds.size.width,
                bounds.size.height,
              )
            ("true", None) =>
              macos_webview_sync_overlay_mask(
                raw_content_view_handle,
                @host.webview_encode_ffi_string(placement.id),
                0,
                0.0,
                0.0,
                0.0,
                0.0,
              )
            _ => ()
          }
        }
      }
      if !has_visible_webview {
        for placement in frame.platform_views {
          if placement.kind == "web_view" {
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
  host : @host.WebViewHost,
) -> Int {
  match macos_content_view_handle(window) {
    Some(raw_content_view_handle) =>
      host.drain_commands(command => {
        match host.native_config(command.controller_id) {
          Some(config) =>
            macos_webview_configure(
              raw_content_view_handle,
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
        macos_webview_command(
          raw_content_view_handle,
          @host.webview_encode_ffi_string(command.controller_id),
          kind,
          @host.webview_encode_ffi_string(text),
          @host.webview_encode_ffi_string(""),
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
