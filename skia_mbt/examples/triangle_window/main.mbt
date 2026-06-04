///|
struct App {
  mut window : @windows.Window?
}

///|
fn make_triangle_path(width : Int, height : Int) -> @skia.Path {
  let w = Float::from_int(width)
  let h = Float::from_int(height)
  @skia.Path::new()
  .move_to(@skia.Point::new(w * 0.5, h * 0.18))
  .line_to(@skia.Point::new(w * 0.18, h * 0.82))
  .line_to(@skia.Point::new(w * 0.82, h * 0.82))
  .close()
}

///|
fn draw_triangle_with_skia(width : Int, height : Int) -> @skia.Pixmap? {
  if width <= 0 || height <= 0 || !@native.skia_available() {
    None
  } else {
    let size = @skia.ISize::new(width, height)
    guard @native.Surface::raster_n32_premul(size) is Some(surface) else {
      return None
    }
    guard surface.canvas() is Some(canvas) else { return None }
    canvas.clear(@skia.Color::from_rgb(18, 24, 38))
    canvas.draw_path_value(
      make_triangle_path(width, height),
      @skia.Paint::new(
        color=@skia.Color::from_rgb(255, 188, 66),
        anti_alias=true,
      ),
    )
    surface.read_pixels()
  }
}

///|
fn redraw_window(window : @windows.Window) -> Unit {
  let size = window.surface_size()
  match draw_triangle_with_skia(size.width(), size.height()) {
    Some(pixmap) => {
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
    None => println("Skia native backend is unavailable; cannot draw triangle")
  }
}

///|
pub impl @windows.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let window_attributes = @core.WindowAttributes::default()
    .with_title("MoonBit Skia Triangle")
    .with_surface_size(@dpi.PhysicalSize::PhysicalSize(640, 420).into_size())
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
