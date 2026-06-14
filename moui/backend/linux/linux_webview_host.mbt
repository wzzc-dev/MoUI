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
  dispatch : (UInt64, String, @host.WebViewEvent) -> Unit,
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
        placement, content_offset_y,
      )
      linux_webview_sync(
        wl_display,
        wl_surface,
        encode_webview_string(placement.id),
        encode_webview_string(placement.property_or("url", "")),
        encode_webview_string(placement.property_or("title", "")),
        webview_policy_code(
          @host.WebViewNavigationPolicy::from_revision_key(
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
/// Draw webview contents onto Skia canvas (for offscreen rendering)
pub fn draw_linux_webview_contents(
  window : @window_linux.Window,
  canvas : @skia_native.Canvas,
  frame : @core.DrawFrame,
  content_offset_y? : Double = 0.0,
) -> Unit {
  let wl_surface = window.wl_surface()

  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      let id_bytes = encode_webview_string(placement.id)
      let surface_data = linux_webview_get_surface_data(wl_surface, id_bytes)

      if surface_data.surface_ptr.compare(0UL) != 0 &&
        surface_data.width > 0 &&
        surface_data.height > 0 {
        // Get pixel data from Cairo surface
        let pixels = linux_webview_get_surface_pixels(surface_data.surface_ptr)

        // Create Skia bitmap from pixels
        // Cairo format is BGRA (native endian), which matches Skia's N32 premul on little-endian
        match
          @skia_native.Bitmap::from_pixels(
            pixels,
            surface_data.width,
            surface_data.height,
            surface_data.stride,
          ) {
          Some(bitmap) =>
            // Convert to image
            match @skia_native.Image::from_bitmap(bitmap) {
              Some(image) => {
                // Calculate destination rect with content offset
                let platform_frame = linux_webview_platform_frame(
                  placement, content_offset_y,
                )

                // Source rect covers the entire surface
                let src_rect = @moui_skia.Rect::from_xywh(
                  0.0,
                  0.0,
                  Float::from_int(surface_data.width),
                  Float::from_int(surface_data.height),
                )

                // Destination rect is the platform view frame
                let dst_rect = @moui_skia.Rect::from_xywh(
                  Float::from_double(platform_frame.origin.x),
                  Float::from_double(platform_frame.origin.y),
                  Float::from_double(platform_frame.size.width),
                  Float::from_double(platform_frame.size.height),
                )

                // Draw image
                canvas.draw_image_rect(
                  image,
                  src_rect,
                  dst_rect,
                  @moui_skia.Paint::new(),
                  sampling=@moui_skia.SamplingOptions::linear(),
                )
              }
              None => ()
            }
          None => ()
        }
      }
    }
  }
}

///|
/// Draw webview contents using renderer's draw_platform_view_pixels method
pub fn draw_linux_webview_to_renderer(
  window : @window_linux.Window,
  renderer : @host.HostWindowRenderer,
  frame : @core.DrawFrame,
  content_offset_y? : Double = 0.0,
) -> Unit {
  let wl_surface = window.wl_surface()

  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      let id_bytes = encode_webview_string(placement.id)
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
