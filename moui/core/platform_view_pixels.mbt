///|
/// Renderer-neutral sink for host-owned platform-view pixels.
pub struct PlatformViewPixelSink {
  priv draw_fn : (Bytes, Int32, Int32, Int32, Double, Double, Double, Double) -> Unit
}

///|
pub fn PlatformViewPixelSink::new(
  draw~ : (Bytes, Int32, Int32, Int32, Double, Double, Double, Double) -> Unit,
) -> PlatformViewPixelSink {
  { draw_fn: draw, }
}

///|
pub fn PlatformViewPixelSink::draw(
  self : PlatformViewPixelSink,
  pixels : Bytes,
  width : Int32,
  height : Int32,
  stride : Int32,
  x : Double,
  y : Double,
  draw_width : Double,
  draw_height : Double,
) -> Unit {
  (self.draw_fn)(pixels, width, height, stride, x, y, draw_width, draw_height)
}
