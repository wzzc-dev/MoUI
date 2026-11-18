///|
/// A recorded p5 drawing operation. Graphics buffers keep operations in local
/// coordinates plus the transform that was active when they were recorded.
priv enum RecordedKind {
  FillPath(Path, Color)
  StrokePath(Path, Color, Double, StrokeCap, StrokeJoin)
  FillRect(Double, Double, Double, Double, Color)
  FillRoundRect(Double, Double, Double, Double, Double, Color)
  StrokeRoundRect(Double, Double, Double, Double, Double, Color, Double)
  DrawImage(Image, Double, Double, Double, Double, Double, Color?)
  FillText(
    String,
    Double,
    Double,
    Color,
    Color?,
    Double,
    FontSpec,
    HAlign,
    VAlign
  )
  ClipPath(Path)
  ClipEnd
}

///|
priv struct RecordedOp {
  transform : Matrix
  blend : BlendMode
  kind : RecordedKind
}

///|
/// Surface used by `create_graphics` sketches. It records vector operations
/// instead of rasterizing them; `Sketch::image` replays the list onto the
/// parent surface.
priv struct RecordingSurface {
  width : Double
  height : Double
  ops : Array[RecordedOp]
  mut matrix : Matrix
  mut blend : BlendMode
  mut smoothing : Bool
  mut clip_depth : Int32
}

///|
fn RecordingSurface::new(width : Double, height : Double) -> RecordingSurface {
  {
    width,
    height,
    ops: [],
    matrix: Matrix::identity(),
    blend: Blend,
    smoothing: true,
    clip_depth: 0,
  }
}

///|
fn RecordingSurface::clear(self : RecordingSurface) -> Unit {
  self.ops.clear()
  self.matrix = Matrix::identity()
  self.blend = Blend
  self.clip_depth = 0
}

///|
fn RecordingSurface::push_op(
  self : RecordingSurface,
  kind : RecordedKind,
) -> Unit {
  self.ops.push({ transform: self.matrix, blend: self.blend, kind, })
}

///|
impl Surface for RecordingSurface with fn set_transform(self, matrix) {
  self.matrix = matrix
}

///|
impl Surface for RecordingSurface with fn save(_) {

}

///|
impl Surface for RecordingSurface with fn restore(_) {

}

///|
impl Surface for RecordingSurface with fn fill_path(self, path, color) {
  self.push_op(FillPath(path.copy(), color))
}

///|
impl Surface for RecordingSurface with fn stroke_path(
  self,
  path,
  color,
  width,
  cap,
  join,
) {
  self.push_op(StrokePath(path.copy(), color, width, cap, join))
}

///|
impl Surface for RecordingSurface with fn fill_rect(
  self,
  x,
  y,
  width,
  height,
  color,
) {
  // A full-canvas opaque fill is p5's background replacement for this buffer.
  if x == 0.0 &&
    y == 0.0 &&
    width == self.width &&
    height == self.height &&
    color.a >= 0.999 {
    self.ops.clear()
  }
  self.push_op(FillRect(x, y, width, height, color))
}

///|
impl Surface for RecordingSurface with fn fill_rounded_rect(
  self,
  x,
  y,
  width,
  height,
  radius,
  color,
) {
  // A full-canvas opaque rect (radius 0) is background replacement here too.
  if radius <= 0.0 &&
    x == 0.0 &&
    y == 0.0 &&
    width == self.width &&
    height == self.height &&
    color.a >= 0.999 {
    self.ops.clear()
  }
  self.push_op(FillRoundRect(x, y, width, height, radius, color))
}

///|
impl Surface for RecordingSurface with fn stroke_rounded_rect(
  self,
  x,
  y,
  width,
  height,
  radius,
  color,
  stroke_width,
) {
  self.push_op(
    StrokeRoundRect(x, y, width, height, radius, color, stroke_width),
  )
}

///|
impl Surface for RecordingSurface with fn clear_rect(self, _, _, _, _) {
  self.clear()
}

///|
impl Surface for RecordingSurface with fn draw_image(
  self,
  image,
  x,
  y,
  width,
  height,
  opacity,
  tint,
) {
  self.push_op(DrawImage(image.copy(), x, y, width, height, opacity, tint))
}

///|
impl Surface for RecordingSurface with fn clip_path(self, path) {
  self.push_op(ClipPath(path.copy()))
  self.clip_depth = self.clip_depth + 1
}

///|
impl Surface for RecordingSurface with fn clip_end(self) {
  if self.clip_depth > 0 {
    self.push_op(ClipEnd)
    self.clip_depth = self.clip_depth - 1
  }
}

///|
impl Surface for RecordingSurface with fn fill_text(
  self,
  text,
  x,
  y,
  color,
  stroke,
  stroke_width,
  font,
  align_h,
  align_v,
) {
  self.push_op(
    FillText(text, x, y, color, stroke, stroke_width, font, align_h, align_v),
  )
}

///|
impl Surface for RecordingSurface with fn measure_width(_, text, font) {
  text.length().to_double() * font.size * 0.5
}

///|
impl Surface for RecordingSurface with fn text_metrics(_, font) {
  TextMetrics::new(
    width=0.0,
    height=font.size * 1.2,
    ascent=font.size * 0.8,
    descent=font.size * 0.2,
  )
}

///|
impl Surface for RecordingSurface with fn set_blend_mode(self, mode) {
  self.blend = mode
}

///|
impl Surface for RecordingSurface with fn set_smoothing(self, smooth) {
  self.smoothing = smooth
}
