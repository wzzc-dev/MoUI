///|
pub fn Canvas::is_available(self : Canvas) -> Bool {
  ignore(self.owner)
  ignore(self)
  false
}

///|
pub fn Canvas::save(self : Canvas) -> Int {
  ignore(self)
  0
}

///|
pub fn Canvas::save_layer(
  self : Canvas,
  bounds? : @skia.Rect? = None,
  paint? : @skia.Paint = @skia.Paint::new(),
  color_filter? : ColorFilter? = None,
  image_filter? : ImageFilter? = None,
  mask_filter? : MaskFilter? = None,
) -> Int {
  ignore(self)
  ignore(bounds)
  ignore(paint)
  ignore(color_filter)
  ignore(image_filter)
  ignore(mask_filter)
  0
}

///|
pub fn Canvas::restore(self : Canvas) -> Unit {
  ignore(self)
}

///|
pub fn Canvas::restore_to_count(self : Canvas, count : Int) -> Unit {
  ignore(self)
  ignore(count)
}

///|
pub fn Canvas::save_count(self : Canvas) -> Int {
  ignore(self)
  0
}

///|
pub fn Canvas::translate(self : Canvas, delta : @skia.Point) -> Unit {
  ignore(self)
  ignore(delta)
}

///|
pub fn Canvas::scale(self : Canvas, scale : @skia.Size) -> Unit {
  ignore(self)
  ignore(scale)
}

///|
pub fn Canvas::rotate(self : Canvas, degrees : Float) -> Unit {
  ignore(self)
  ignore(degrees)
}

///|
pub fn Canvas::skew(self : Canvas, skew : @skia.Point) -> Unit {
  ignore(self)
  ignore(skew)
}

///|
pub fn Canvas::concat(self : Canvas, matrix : @skia.Matrix) -> Unit {
  ignore(self)
  ignore(matrix)
}

///|
pub fn Canvas::reset_matrix(self : Canvas) -> Unit {
  ignore(self)
}

///|
pub fn Canvas::discard(self : Canvas) -> Unit {
  ignore(self)
}

///|
pub fn Canvas::clip_rect(
  self : Canvas,
  rect : @skia.Rect,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(op)
  ignore(anti_alias)
}

///|
pub fn Canvas::clip_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(rrect)
  ignore(op)
  ignore(anti_alias)
}

///|
pub fn Canvas::clip_path(
  self : Canvas,
  path : Path,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(op)
  ignore(anti_alias)
}

///|
pub fn Canvas::local_clip_bounds(self : Canvas) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Canvas::device_clip_bounds(self : Canvas) -> @skia.IRect? {
  ignore(self)
  None
}

///|
pub fn Canvas::quick_reject_rect(self : Canvas, rect : @skia.Rect) -> Bool {
  ignore(self)
  ignore(rect)
  false
}

///|
pub fn Canvas::quick_reject_path(self : Canvas, path : Path) -> Bool {
  ignore(self)
  ignore(path)
  false
}

///|
pub fn Canvas::draw_color(
  self : Canvas,
  color : @skia.Color,
  blend_mode? : @skia.BlendMode = @skia.SrcOver,
) -> Unit {
  ignore(self)
  ignore(color)
  ignore(blend_mode)
}

///|
pub fn Canvas::clear(self : Canvas, color : @skia.Color) -> Unit {
  ignore(self)
  ignore(color)
}

///|
pub fn Canvas::draw_paint(self : Canvas, paint : @skia.Paint) -> Unit {
  ignore(self)
  ignore(paint)
}

///|
pub fn Canvas::draw_point(
  self : Canvas,
  point : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(point)
  ignore(paint)
}

///|
pub fn Canvas::draw_line(
  self : Canvas,
  start : @skia.Point,
  end : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(start)
  ignore(end)
  ignore(paint)
}

///|
pub fn Canvas::draw_points(
  self : Canvas,
  points : Array[@skia.Point],
  paint : @skia.Paint,
  mode? : @skia.PointMode = @skia.Points,
) -> Unit {
  ignore(self)
  ignore(points)
  ignore(paint)
  ignore(mode)
}

///|
pub fn Canvas::draw_rect(
  self : Canvas,
  rect : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(paint)
}

///|
pub fn Canvas::draw_oval(
  self : Canvas,
  oval : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(oval)
  ignore(paint)
}

///|
pub fn Canvas::draw_circle(
  self : Canvas,
  center : @skia.Point,
  radius : Float,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(center)
  ignore(radius)
  ignore(paint)
}

///|
pub fn Canvas::draw_arc(
  self : Canvas,
  oval : @skia.Rect,
  start_angle : Float,
  sweep_angle : Float,
  use_center : Bool,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(oval)
  ignore(start_angle)
  ignore(sweep_angle)
  ignore(use_center)
  ignore(paint)
}

///|
pub fn Canvas::draw_round_rect(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(rx)
  ignore(ry)
  ignore(paint)
}

///|
pub fn Canvas::draw_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rrect)
  ignore(paint)
}

///|
pub fn Canvas::draw_drrect(
  self : Canvas,
  outer : @skia.RRect,
  inner : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(outer)
  ignore(inner)
  ignore(paint)
}

///|
pub fn Canvas::draw_path(
  self : Canvas,
  path : Path,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(paint)
}

///|
pub fn Canvas::draw_path_shader(
  self : Canvas,
  path : Path,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_path_value(
  self : Canvas,
  path : @skia.Path,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(paint)
}

///|
pub fn Canvas::draw_image(
  self : Canvas,
  image : Image,
  top_left : @skia.Point,
) -> Unit {
  ignore(self)
  ignore(image)
  ignore(top_left)
}

///|
pub fn Canvas::draw_image_rect(
  self : Canvas,
  image : Image,
  src : @skia.Rect,
  dst : @skia.Rect,
  paint : @skia.Paint,
  sampling? : @skia.SamplingOptions = @skia.SamplingOptions::new(),
) -> Unit {
  ignore(self)
  ignore(image)
  ignore(src)
  ignore(dst)
  ignore(paint)
  ignore(sampling)
}

///|
pub fn Canvas::draw_paint_shader(
  self : Canvas,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_round_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(rx)
  ignore(ry)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_text_utf8(
  self : Canvas,
  text : Bytes,
  origin : @skia.Point,
  font : Font,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(text)
  ignore(origin)
  ignore(font)
  ignore(paint)
}

///|
pub fn Canvas::draw_glyphs(
  self : Canvas,
  glyphs : Array[GlyphId],
  positions : Array[@skia.Point],
  font : Font,
  paint : @skia.Paint,
  origin? : @skia.Point = @skia.Point::zero(),
) -> Unit {
  ignore(self)
  ignore(glyphs)
  ignore(positions)
  ignore(origin)
  ignore(font)
  ignore(paint)
}

///|
/// Replay is a counted no-op when the native Canvas target is unavailable.
pub fn Canvas::replay(
  self : Canvas,
  commands : @skia.RenderCommandList,
  font? : Font? = None,
) -> CanvasReplayStats {
  ignore(self)
  ignore(font)
  let mut command_count = 0
  let mut skipped_count = 0
  let mut draw_count = 0
  let mut text_count = 0
  let mut present_count = 0
  for command in commands.commands {
    command_count += 1
    if command.is_draw() {
      draw_count += 1
    }
    if command.is_text() {
      text_count += 1
    }
    if command.is_present() {
      present_count += 1
    } else if !command.is_resource_declaration() {
      skipped_count += 1
    }
  }
  {
    command_count,
    replayed_count: 0,
    skipped_count,
    draw_count,
    text_count,
    present_count,
  }
}

///|
/// Allocate a raster N32 premultiplied surface.
///
