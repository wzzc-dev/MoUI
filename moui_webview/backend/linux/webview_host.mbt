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
#borrow(id, url, title, background, scheme)
extern "C" fn linux_webview_sync(
  wl_display : UInt64,
  wl_surface : UInt64,
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
/// Surface data returned from C
pub struct WebViewSurfaceData {
  surface_ptr : UInt64
  width : Int
  height : Int
  stride : Int // row_bytes
}

///|
/// Get surface pointer for a webview (offscreen rendering)
#borrow(id)
extern "C" fn linux_webview_get_surface_ptr(
  wl_surface : UInt64,
  id : Bytes,
) -> UInt64 = "moui_linux_webview_get_surface_ptr"

///|
/// Get surface width for a webview
#borrow(id)
extern "C" fn linux_webview_get_surface_width(
  wl_surface : UInt64,
  id : Bytes,
) -> Int = "moui_linux_webview_get_surface_width"

///|
/// Get surface height for a webview
#borrow(id)
extern "C" fn linux_webview_get_surface_height(
  wl_surface : UInt64,
  id : Bytes,
) -> Int = "moui_linux_webview_get_surface_height"

///|
/// Get surface stride for a webview
#borrow(id)
extern "C" fn linux_webview_get_surface_stride(
  wl_surface : UInt64,
  id : Bytes,
) -> Int = "moui_linux_webview_get_surface_stride"

///|
/// Get surface data for a webview by calling individual getters
pub fn linux_webview_get_surface_data(
  wl_surface : UInt64,
  id : Bytes,
) -> WebViewSurfaceData {
  let surface_ptr = linux_webview_get_surface_ptr(wl_surface, id)
  let width = linux_webview_get_surface_width(wl_surface, id)
  let height = linux_webview_get_surface_height(wl_surface, id)
  let stride = linux_webview_get_surface_stride(wl_surface, id)
  { surface_ptr, width, height, stride }
}

///|
/// Get pixel data from cairo surface pointer
extern "C" fn linux_webview_get_surface_pixels(surface_ptr : UInt64) -> Bytes = "moui_linux_webview_get_surface_pixels"

///|
pub fn linux_webview_capabilities() -> @host.HostWebViewCapabilities {
  if linux_webview_native_available() != 0 {
    @host.HostWebViewCapabilities::native_available(
      description="Linux WebKitGTK native embedding is available.",
    )
  } else {
    @host.HostWebViewCapabilities::unavailable(
      description="Linux WebKitGTK native embedding is unavailable; install libwebkit2gtk-4.1-dev and matching native dependencies to enable it.",
    )
  }
}

///|
pub fn pump_linux_webview_runtime(max_iterations? : Int = 64) -> Bool {
  let pumped = linux_webview_pump(max_iterations)
  pumped > 0 || linux_webview_has_active_work() != 0
}

///|
pub fn linux_webview_runtime_next_tick_ms(delay_ms? : Int = 16) -> Int64 {
  linux_webview_next_tick_ms(delay_ms)
}

///|
pub fn install_linux_webview_event_dispatcher(
  dispatch : (UInt64, String, @host.WebViewEvent) -> Unit,
) -> Unit {
  linux_webview_install_event_callback(
    fn(callback, wl_surface, kind, id, url, detail, flag) {
      callback(wl_surface, kind, id, url, detail, flag)
    },
    (wl_surface, kind, id, url, detail, flag) => {
      dispatch(
        wl_surface,
        @host.webview_decode_ffi_string(id),
        @host.webview_decode_native_event(kind, url, detail, flag),
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
        placement, content_offset_y,
      )
      linux_webview_sync(
        wl_display,
        wl_surface,
        @host.webview_encode_ffi_string(placement.id),
        @host.webview_encode_ffi_string(placement.property_or("url", "")),
        @host.webview_encode_ffi_string(placement.property_or("title", "")),
        @host.webview_encode_ffi_string(
          placement.property_or("background-color", ""),
        ),
        @host.webview_encode_ffi_string(placement.property_or("color-scheme", "")),
        @host.webview_native_policy_code(
          @host.WebViewNavigationPolicy::from_wire_value(
            placement.property_or("policy", "http-https-file"),
          ),
        ),
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
/// Draw webview contents using renderer's draw_platform_view_pixels method
pub fn draw_linux_webview_to_renderer(
  window : @window_linux.Window,
  renderer : @render.RendererSession,
  frame : @core.DrawFrame,
  content_offset_y? : Double = 0.0,
) -> Unit {
  let wl_surface = window.wl_surface()

  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      let id_bytes = @host.webview_encode_ffi_string(placement.id)
      let surface_data = linux_webview_get_surface_data(wl_surface, id_bytes)

      if surface_data.surface_ptr.compare(0UL) != 0 &&
        surface_data.width > 0 &&
        surface_data.height > 0 {
        // Get pixel data from Cairo surface
        let pixels = linux_webview_get_surface_pixels(surface_data.surface_ptr)

        // Calculate destination rect with content offset
        let platform_frame = linux_webview_platform_frame(
          placement, content_offset_y,
        )

        // Call renderer's platform view pixel drawing method
        renderer.draw_platform_view_pixels(
          pixels,
          surface_data.width,
          surface_data.height,
          surface_data.stride,
          platform_frame.origin.x,
          platform_frame.origin.y,
          platform_frame.size.width,
          platform_frame.size.height,
        )
      }
    }
  }
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
    let (kind, text, detail) = @host.webview_encode_native_command(
      command.command,
    )
    linux_webview_command(
      wl_surface,
      @host.webview_encode_ffi_string(command.id),
      kind,
      @host.webview_encode_ffi_string(text),
      @host.webview_encode_ffi_string(detail),
    )
  })
}
