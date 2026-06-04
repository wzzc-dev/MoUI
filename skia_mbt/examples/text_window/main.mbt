///|
let text_message = "你好 Moonbit 2026 !"

///|
let text_trace_logged : Array[Bool] = [false]

///|
struct App {
  mut window : @windows.Window?
}

///|
fn text_trace_enabled() -> Bool {
  match @env.get_env_var("SKIA_MBT_TEXT_TRACE") {
    Some(value) => value != ""
    None => false
  }
}

///|
fn make_text_font(size : Float) -> @native.Font? {
  let families : Array[Bytes] = [
    b"Microsoft YaHei", b"SimHei", b"SimSun", b"Segoe UI",
  ]
  for family in families {
    match @native.Typeface::from_name(family) {
      Some(typeface) =>
        match @native.Font::from_typeface(typeface, size~) {
          Some(font) => return Some(font)
          None => ()
        }
      None => ()
    }
  }
  @native.Font::default(size~)
}

///|
fn trace_text_pixmap(pixmap : @skia.Pixmap) -> Unit {
  if text_trace_logged[0] || !text_trace_enabled() {
    return
  }
  text_trace_logged[0] = true
  let bg_r = (16 : Int).to_byte()
  let bg_g = (24 : Int).to_byte()
  let bg_b = (34 : Int).to_byte()
  let alpha = (255 : Int).to_byte()
  let mut non_background_pixels = 0
  for y in 0..<pixmap.height() {
    for x in 0..<pixmap.width() {
      let offset = y * pixmap.row_bytes() + x * 4
      if pixmap.pixels[offset] != bg_r ||
        pixmap.pixels[offset + 1] != bg_g ||
        pixmap.pixels[offset + 2] != bg_b ||
        pixmap.pixels[offset + 3] != alpha {
        non_background_pixels += 1
      }
    }
  }
  println(
    "skia text render: \{pixmap.width()}x\{pixmap.height()} non_background_pixels=\{non_background_pixels} message=\{text_message}",
  )
}

///|
fn draw_text_with_skia(width : Int, height : Int) -> @skia.Pixmap? {
  if width <= 0 || height <= 0 || !@native.skia_available() {
    None
  } else {
    let size = @skia.ISize::new(width, height)
    guard @native.Surface::raster_n32_premul(size) is Some(surface) else {
      return None
    }
    guard surface.canvas() is Some(canvas) else { return None }
    canvas.clear(@skia.Color::from_rgb(16, 24, 34))
    guard make_text_font(52.0) is Some(font) else { return None }
    canvas.draw_text_utf8(
      @utf8.encode(text_message),
      @skia.Point::new(
        Float::from_int(width) * 0.08,
        Float::from_int(height) * 0.56,
      ),
      font,
      @skia.Paint::new(
        color=@skia.Color::from_rgb(245, 247, 250),
        anti_alias=true,
      ),
    )
    match surface.read_pixels() {
      Some(pixmap) => {
        trace_text_pixmap(pixmap)
        Some(pixmap)
      }
      None => None
    }
  }
}

///|
fn redraw_window(window : @windows.Window) -> Unit {
  let size = window.surface_size()
  match draw_text_with_skia(size.width(), size.height()) {
    Some(pixmap) => {
      let status = present_rgba_to_window(
        window.window_handle(),
        pixmap.width(),
        pixmap.height(),
        pixmap.row_bytes(),
        pixmap.pixels,
      )
      if status != 0 {
        println("present Skia text pixels failed: \{status}")
      }
    }
    None => println("Skia native backend is unavailable; cannot draw text")
  }
}

///|
pub impl @windows.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let window_attributes = @core.WindowAttributes::default()
    .with_title("MoonBit Skia Text")
    .with_surface_size(@dpi.PhysicalSize::PhysicalSize(760, 260).into_size())
  let window : @windows.Window? = Some(
    event_loop.try_create_window(window_attributes),
  ) catch {
    err => {
      println("error creating window: \{err}")
      event_loop.exit()
      None
    }
  }
  self.window = window
  match window {
    Some(window) => window.request_redraw()
    None => ()
  }
}

///|
pub impl @windows.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    CloseRequested => event_loop.exit()
    SurfaceResized(_) =>
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
    RedrawRequested =>
      match self.window {
        Some(window) => redraw_window(window)
        None => ()
      }
    _ => ()
  }
}

///|
fn main {
  let event_loop = @windows.EventLoop::new()
  event_loop.run_app({ window: None })
}
