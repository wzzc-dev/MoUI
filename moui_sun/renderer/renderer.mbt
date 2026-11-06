///|
/// Renderer core that composes vector drawing, text masks, and pixmap output.
#derive(Debug)
pub struct Renderer {
  canvas : @graphics.Canvas
}

///|
pub extend Renderer with Debug::{to_repr}

///|
/// Create a renderer around an existing canvas.
pub fn Renderer::new(canvas : @graphics.Canvas) -> Renderer {
  { canvas, }
}

///|
/// Get the renderer canvas.
pub fn Renderer::get_canvas(self : Renderer) -> @graphics.Canvas {
  self.canvas
}
