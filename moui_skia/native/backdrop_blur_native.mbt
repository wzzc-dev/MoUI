///|
/// Draw the pixels already on the canvas, blurred, clipped to a rounded rect,
/// then tint the rect. Returns true when the blur pass ran; false means the
/// host has no readable raster pixels (GPU route) and only the tint painted.
#borrow(canvas)
extern "C" fn native_canvas_draw_backdrop_blur(
  canvas : CanvasHandle,
  x : Float,
  y : Float,
  width : Float,
  height : Float,
  radius : Float,
  blur : Float,
  tint_argb : UInt32,
) -> Bool = "moonbit_skia_canvas_draw_backdrop_blur"

///|
pub fn Canvas::draw_backdrop_blur(
  self : Canvas,
  x : Float,
  y : Float,
  width : Float,
  height : Float,
  radius~ : Float = 0.0,
  blur~ : Float = 16.0,
  tint~ : @skia.Color,
) -> Bool {
  native_canvas_draw_backdrop_blur(
    self.handle,
    x,
    y,
    width,
    height,
    radius,
    blur,
    tint.argb(),
  )
}
