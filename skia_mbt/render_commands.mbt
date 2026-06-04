///|
/// Portable render command recorded before a concrete backend turns it into
/// native Canvas calls.
pub(all) enum RenderCommand {
  SaveCanvas
  RestoreCanvas
  SaveCanvasLayer(
    Rect?,
    Paint,
    ColorFilterDescriptor?,
    ImageFilterDescriptor?,
    MaskFilterDescriptor?
  )
  TranslateCanvas(Point)
  ScaleCanvas(Size)
  RotateCanvas(Float)
  SkewCanvas(Point)
  ConcatCanvas(Matrix)
  ResetCanvasMatrix
  ClearCanvas(Color)
  ClipCanvasRect(Rect, ClipOp)
  ClipCanvasRRect(RRect, ClipOp)
  ClipCanvasPath(Path, ClipOp)
  DrawCanvasColor(Color, BlendMode)
  DrawCanvasPaint(Paint)
  DrawCanvasPaintShader(ShaderDescriptor, Paint)
  DrawCanvasPoint(Point, Paint)
  DrawCanvasLine(Point, Point, Paint)
  DrawCanvasPoints(Array[Point], PointMode, Paint)
  DrawCanvasRect(Rect, Paint)
  DrawCanvasOval(Rect, Paint)
  DrawCanvasCircle(Point, Float, Paint)
  DrawCanvasArc(Rect, Float, Float, Bool, Paint)
  DrawCanvasRoundRect(Rect, Float, Float, Paint)
  DrawCanvasRRect(RRect, Paint)
  DrawCanvasDRRect(RRect, RRect, Paint)
  DrawCanvasRectShader(Rect, ShaderDescriptor, Paint)
  DrawCanvasRoundRectShader(Rect, Float, Float, ShaderDescriptor, Paint)
  DrawCanvasPath(Path, Paint)
  DrawCanvasPathShader(Path, ShaderDescriptor, Paint)
  DrawCanvasImage(ImageDescriptor, Point)
  DrawCanvasImageRect(ImageDescriptor, Rect, Rect, Paint, SamplingOptions)
  DrawCanvasTextUtf8(Bytes, Point, Paint)
  DrawCanvasTextRunUtf8(
    Bytes,
    TextRunDescriptor,
    RendererResourceKey,
    Point,
    Paint
  )
  DrawCanvasShapedGlyphRunUtf8(Bytes, ShapedGlyphRunDescriptor, Point, Paint)
  DeclareRenderResource(RendererResourceDescriptor)
  PresentSurface
} derive(Debug, Eq)

///|
pub fn RenderCommand::clear(color : Color) -> RenderCommand {
  ClearCanvas(color)
}

///|
pub fn RenderCommand::draw_color(
  color : Color,
  blend_mode? : BlendMode = SrcOver,
) -> RenderCommand {
  DrawCanvasColor(color, blend_mode)
}

///|
pub fn RenderCommand::draw_paint(paint : Paint) -> RenderCommand {
  DrawCanvasPaint(paint)
}

///|
pub fn RenderCommand::draw_paint_shader(
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasPaintShader(shader, paint)
}

///|
pub fn RenderCommand::clip_rect(
  rect : Rect,
  op? : ClipOp = Intersect,
) -> RenderCommand {
  ClipCanvasRect(rect.sorted(), op)
}

///|
pub fn RenderCommand::clip_rrect(
  rrect : RRect,
  op? : ClipOp = Intersect,
) -> RenderCommand {
  ClipCanvasRRect(rrect, op)
}

///|
pub fn RenderCommand::clip_path(
  path : Path,
  op? : ClipOp = Intersect,
) -> RenderCommand {
  ClipCanvasPath(path, op)
}

///|
pub fn RenderCommand::save_layer(
  bounds? : Rect? = None,
  paint? : Paint = Paint::new(),
  color_filter? : ColorFilterDescriptor? = None,
  image_filter? : ImageFilterDescriptor? = None,
  mask_filter? : MaskFilterDescriptor? = None,
) -> RenderCommand {
  let layer_bounds : Rect? = match bounds {
    None => None
    Some(bounds) => Some(bounds.sorted())
  }
  SaveCanvasLayer(layer_bounds, paint, color_filter, image_filter, mask_filter)
}

///|
pub fn RenderCommand::translate(delta : Point) -> RenderCommand {
  TranslateCanvas(delta)
}

///|
pub fn RenderCommand::scale(scale : Size) -> RenderCommand {
  ScaleCanvas(scale)
}

///|
pub fn RenderCommand::rotate(degrees : Float) -> RenderCommand {
  RotateCanvas(degrees)
}

///|
pub fn RenderCommand::skew(skew : Point) -> RenderCommand {
  SkewCanvas(skew)
}

///|
pub fn RenderCommand::concat(matrix : Matrix) -> RenderCommand {
  ConcatCanvas(matrix)
}

///|
pub fn RenderCommand::reset_matrix() -> RenderCommand {
  ResetCanvasMatrix
}

///|
pub fn RenderCommand::draw_point(
  point : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasPoint(point, paint)
}

///|
pub fn RenderCommand::draw_line(
  start : Point,
  end : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasLine(start, end, paint)
}

///|
pub fn RenderCommand::draw_points(
  points : Array[Point],
  paint? : Paint = Paint::new(),
  mode? : PointMode = Points,
) -> RenderCommand {
  DrawCanvasPoints(points.copy(), mode, paint)
}

///|
pub fn RenderCommand::draw_rect(
  rect : Rect,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasRect(rect.sorted(), paint)
}

///|
pub fn RenderCommand::draw_oval(
  oval : Rect,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasOval(oval.sorted(), paint)
}

///|
pub fn RenderCommand::draw_circle(
  center : Point,
  radius : Float,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasCircle(center, radius, paint)
}

///|
pub fn RenderCommand::draw_arc(
  oval : Rect,
  start_angle : Float,
  sweep_angle : Float,
  use_center : Bool,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasArc(oval.sorted(), start_angle, sweep_angle, use_center, paint)
}

///|
pub fn RenderCommand::draw_round_rect(
  rect : Rect,
  rx : Float,
  ry : Float,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasRoundRect(rect.sorted(), rx, ry, paint)
}

///|
pub fn RenderCommand::draw_rrect(
  rrect : RRect,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasRRect(rrect, paint)
}

///|
pub fn RenderCommand::draw_drrect(
  outer : RRect,
  inner : RRect,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasDRRect(outer, inner, paint)
}

///|
pub fn RenderCommand::draw_rect_shader(
  rect : Rect,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasRectShader(rect.sorted(), shader, paint)
}

///|
pub fn RenderCommand::draw_round_rect_shader(
  rect : Rect,
  rx : Float,
  ry : Float,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasRoundRectShader(rect.sorted(), rx, ry, shader, paint)
}

///|
pub fn RenderCommand::draw_path(
  path : Path,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasPath(path, paint)
}

///|
pub fn RenderCommand::draw_path_shader(
  path : Path,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasPathShader(path, shader, paint)
}

///|
pub fn RenderCommand::draw_image(
  image : ImageDescriptor,
  top_left : Point,
) -> RenderCommand {
  DrawCanvasImage(image, top_left)
}

///|
pub fn RenderCommand::draw_image_rect(
  image : ImageDescriptor,
  src : Rect,
  dst : Rect,
  paint? : Paint = Paint::new(),
  sampling? : SamplingOptions = SamplingOptions::new(),
) -> RenderCommand {
  DrawCanvasImageRect(image, src.sorted(), dst.sorted(), paint, sampling)
}

///|
pub fn RenderCommand::draw_text_utf8(
  text : Bytes,
  origin : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasTextUtf8(text, origin, paint)
}

///|
fn default_render_text_run_descriptor(text : Bytes) -> TextRunDescriptor {
  TextRunDescriptor::new(range=TextRange::new(0, text.length()))
}

///|
pub fn RenderCommand::draw_text_run_utf8(
  text : Bytes,
  origin : Point,
  descriptor? : TextRunDescriptor? = None,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  let descriptor = match descriptor {
    None => default_render_text_run_descriptor(text)
    Some(descriptor) => descriptor
  }
  DrawCanvasTextRunUtf8(text, descriptor, font_key, origin, paint)
}

///|
pub fn RenderCommand::draw_shaped_glyph_run_utf8(
  text : Bytes,
  glyph_run : ShapedGlyphRunDescriptor,
  origin : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasShapedGlyphRunUtf8(text, glyph_run, origin, paint)
}

///|
pub fn RenderCommand::declare_resource(
  descriptor : RendererResourceDescriptor,
) -> RenderCommand {
  DeclareRenderResource(descriptor)
}

///|
pub fn RenderCommand::is_draw(self : RenderCommand) -> Bool {
  self
  is (DrawCanvasColor(_, _)
  | DrawCanvasPaint(_)
  | DrawCanvasPaintShader(_, _)
  | DrawCanvasPoint(_, _)
  | DrawCanvasLine(_, _, _)
  | DrawCanvasPoints(_, _, _)
  | DrawCanvasRect(_, _)
  | DrawCanvasOval(_, _)
  | DrawCanvasCircle(_, _, _)
  | DrawCanvasArc(_, _, _, _, _)
  | DrawCanvasRoundRect(_, _, _, _)
  | DrawCanvasRRect(_, _)
  | DrawCanvasDRRect(_, _, _)
  | DrawCanvasRectShader(_, _, _)
  | DrawCanvasRoundRectShader(_, _, _, _, _)
  | DrawCanvasPath(_, _)
  | DrawCanvasPathShader(_, _, _)
  | DrawCanvasImage(_, _)
  | DrawCanvasImageRect(_, _, _, _, _)
  | DrawCanvasTextUtf8(_, _, _)
  | DrawCanvasTextRunUtf8(_, _, _, _, _)
  | DrawCanvasShapedGlyphRunUtf8(_, _, _, _))
}

///|
pub fn RenderCommand::is_state(self : RenderCommand) -> Bool {
  self
  is (SaveCanvas
  | RestoreCanvas
  | SaveCanvasLayer(_, _, _, _, _)
  | TranslateCanvas(_)
  | ScaleCanvas(_)
  | RotateCanvas(_)
  | SkewCanvas(_)
  | ConcatCanvas(_)
  | ResetCanvasMatrix)
}

///|
pub fn RenderCommand::is_transform(self : RenderCommand) -> Bool {
  self
  is (TranslateCanvas(_)
  | ScaleCanvas(_)
  | RotateCanvas(_)
  | SkewCanvas(_)
  | ConcatCanvas(_)
  | ResetCanvasMatrix)
}

///|
pub fn RenderCommand::is_clip(self : RenderCommand) -> Bool {
  self is (ClipCanvasRect(_, _) | ClipCanvasRRect(_, _) | ClipCanvasPath(_, _))
}

///|
pub fn RenderCommand::is_clear(self : RenderCommand) -> Bool {
  self is ClearCanvas(_)
}

///|
pub fn RenderCommand::is_present(self : RenderCommand) -> Bool {
  self is PresentSurface
}

///|
pub fn RenderCommand::is_text(self : RenderCommand) -> Bool {
  self
  is (DrawCanvasTextUtf8(_, _, _)
  | DrawCanvasTextRunUtf8(_, _, _, _, _)
  | DrawCanvasShapedGlyphRunUtf8(_, _, _, _))
}

///|
pub fn RenderCommand::is_resource_declaration(self : RenderCommand) -> Bool {
  self is DeclareRenderResource(_)
}
