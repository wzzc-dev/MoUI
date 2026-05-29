///|
let message = "你好 Skia ！！"

///|
struct App {
  mut window : @macos.Window?
}

///|
fn make_text_font(size : Float) -> @native.Font? {
  let families : Array[Bytes] = [
    b"PingFang SC", b"Hiragino Sans GB", b"Heiti SC", b"Arial Unicode MS", b"Helvetica Neue",
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
fn top_half_height(height : Int) -> Int {
  Int::max(1, height / 2)
}

///|
fn draw_background(canvas : @native.Canvas, width : Int, height : Int) -> Unit {
  let w = Float::from_int(width)
  let h = Float::from_int(height)
  let split = Float::from_int(top_half_height(height))
  canvas.clear(@skia.Color::from_rgb(18, 22, 31))
  canvas.draw_rect(
    @skia.Rect::from_xywh(0.0, 0.0, w, split),
    @skia.Paint::new(color=@skia.Color::from_rgb(31, 43, 64)),
  )
  canvas.draw_rect(
    @skia.Rect::from_xywh(0.0, split, w, h - split),
    @skia.Paint::new(color=@skia.Color::from_rgb(246, 248, 252)),
  )
  canvas.draw_line(
    @skia.Point::new(0.0, split),
    @skia.Point::new(w, split),
    @skia.Paint::new(
      color=@skia.Color::from_rgb(110, 124, 148),
      anti_alias=true,
      style=@skia.Stroke,
      stroke_width=2.0,
    ),
  )
}

///|
fn draw_hello_text(canvas : @native.Canvas, width : Int, height : Int) -> Unit {
  let split = Float::from_int(top_half_height(height))
  let font_size = Float::min(64.0, Float::max(34.0, split * 0.34))
  guard make_text_font(font_size) is Some(font) else { return }
  let text = @utf8.encode(message)
  let text_width = font.measure_text_utf8(text)
  let x = Float::max(24.0, (Float::from_int(width) - text_width) * 0.5)
  let y = split * 0.58
  canvas.draw_text_utf8(
    text,
    @skia.Point::new(x, y),
    font,
    @skia.Paint::new(
      color=@skia.Color::from_rgb(252, 253, 255),
      anti_alias=true,
    ),
  )
}

///|
fn make_triangle_path(width : Int, height : Int) -> @skia.Path {
  let w = Float::from_int(width)
  let split = Float::from_int(top_half_height(height))
  let lower_h = Float::max(1.0, Float::from_int(height) - split)
  @skia.Path::new()
  .move_to(@skia.Point::new(w * 0.5, split + lower_h * 0.18))
  .line_to(@skia.Point::new(w * 0.24, split + lower_h * 0.78))
  .line_to(@skia.Point::new(w * 0.76, split + lower_h * 0.78))
  .close()
}

///|
fn draw_triangle(canvas : @native.Canvas, width : Int, height : Int) -> Unit {
  let triangle = make_triangle_path(width, height)
  canvas.draw_path_value(
    triangle,
    @skia.Paint::new(color=@skia.Color::from_rgb(239, 120, 80), anti_alias=true),
  )
  canvas.draw_path_value(
    triangle,
    @skia.Paint::new(
      color=@skia.Color::from_rgb(96, 70, 52),
      anti_alias=true,
      style=@skia.Stroke,
      stroke_width=4.0,
      stroke_join=@skia.Round,
    ),
  )
}

///|
fn draw_scene(width : Int, height : Int) -> @skia.Pixmap? {
  if width <= 0 || height <= 0 || !@native.skia_available() {
    None
  } else {
    let size = @skia.ISize::new(width, height)
    guard @native.Surface::raster_n32_premul(size) is Some(surface) else {
      return None
    }
    guard surface.canvas() is Some(canvas) else { return None }
    draw_background(canvas, width, height)
    draw_hello_text(canvas, width, height)
    draw_triangle(canvas, width, height)
    surface.read_pixels()
  }
}

///|
fn redraw_window(window : @macos.Window) -> Unit {
  let size = window.surface_size()
  match draw_scene(size.width(), size.height()) {
    Some(pixmap) => {
      window.pre_present_notify()
      let status = present_rgba_to_window(
        window.window_handle(),
        pixmap.width(),
        pixmap.height(),
        pixmap.row_bytes(),
        pixmap.pixels,
      )
      if status != 0 {
        println("present Skia pixels failed: \{status}")
      }
    }
    None =>
      println("Skia native backend is unavailable; cannot draw macOS example")
  }
}

///|
pub impl @macos.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let window_attributes = @core.WindowAttributes::default()
    .with_title("你好 Skia")
    .with_surface_size(@dpi.PhysicalSize::PhysicalSize(760, 520).into_size())
  let window : @macos.Window? = Some(
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
pub impl @macos.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    @core.WindowEvent::CloseRequested => event_loop.exit()
    @core.WindowEvent::SurfaceResized(_) =>
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
    @core.WindowEvent::RedrawRequested =>
      match self.window {
        Some(window) => redraw_window(window)
        None => ()
      }
    _ => ()
  }
}

///|
fn main {
  let event_loop = @macos.EventLoop::EventLoop()
  event_loop.run_app({ window: None })
}
