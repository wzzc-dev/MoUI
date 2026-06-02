///|
/// Portable render command recorded before a concrete backend turns it into
/// native Canvas calls.
#warnings("-deprecated_syntax")
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

///|
priv struct RenderCommandResourceCounts {
  image_resource_count : Int
  shader_resource_count : Int
  filter_resource_count : Int
  path_resource_count : Int
  text_resource_count : Int
}

///|
fn RenderCommand::resource_counts(
  self : RenderCommand,
) -> RenderCommandResourceCounts {
  let mut image_resource_count = 0
  let mut shader_resource_count = 0
  let mut filter_resource_count = 0
  let mut path_resource_count = 0
  let mut text_resource_count = 0
  for descriptor in self.resource_descriptors() {
    match descriptor.key.kind {
      ImageResource => image_resource_count += 1
      ShaderResource => shader_resource_count += 1
      PathResource => path_resource_count += 1
      ColorFilterResource | ImageFilterResource | MaskFilterResource =>
        filter_resource_count += 1
      TypefaceResource | FontResource | TextRunResource =>
        text_resource_count += 1
      _ => ()
    }
  }
  {
    image_resource_count,
    shader_resource_count,
    filter_resource_count,
    path_resource_count,
    text_resource_count,
  }
}

///|
pub fn RenderCommand::resource_count_for_kind(
  self : RenderCommand,
  kind : RendererResourceKind,
) -> Int {
  let mut count = 0
  for descriptor in self.resource_descriptors() {
    if descriptor.key.kind == kind {
      count += 1
    }
  }
  count
}

///|
pub fn RenderCommand::filter_resource_count(self : RenderCommand) -> Int {
  self.resource_counts().filter_resource_count
}

///|
pub fn RenderCommand::text_resource_count(self : RenderCommand) -> Int {
  self.resource_counts().text_resource_count
}

///|
pub fn RenderCommand::text_run_resource_key(
  self : RenderCommand,
) -> RendererResourceKey? {
  match self {
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      Some(descriptor.resource_key(text, font_key~))
    DrawCanvasShapedGlyphRunUtf8(text, glyph_run, _, _) =>
      Some(glyph_run.resource_key(text))
    _ => None
  }
}

///|
pub fn RenderCommand::resource_descriptor(
  self : RenderCommand,
) -> RendererResourceDescriptor? {
  match self {
    DrawCanvasPath(path, _) => Some(path.resource_descriptor())
    ClipCanvasPath(path, _) => Some(path.resource_descriptor())
    DrawCanvasPaintShader(shader, _) => Some(shader.resource_descriptor())
    DrawCanvasRectShader(_, shader, _) => Some(shader.resource_descriptor())
    DrawCanvasRoundRectShader(_, _, _, shader, _) =>
      Some(shader.resource_descriptor())
    DrawCanvasImage(image, _) => Some(image.resource_descriptor())
    DrawCanvasImageRect(image, _, _, _, _) => Some(image.resource_descriptor())
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      Some(descriptor.resource_descriptor(text, font_key~))
    DrawCanvasShapedGlyphRunUtf8(text, glyph_run, _, _) =>
      Some(glyph_run.resource_descriptor(text))
    DeclareRenderResource(descriptor) => Some(descriptor)
    _ => None
  }
}

///|
pub fn RenderCommand::resource_descriptors(
  self : RenderCommand,
) -> Array[RendererResourceDescriptor] {
  match self {
    SaveCanvasLayer(_, _, color_filter, image_filter, mask_filter) =>
      render_filter_resource_descriptors(
        color_filter, image_filter, mask_filter,
      )
    ClipCanvasPath(path, _) => [path.resource_descriptor()]
    DrawCanvasPaintShader(shader, _) => [shader.resource_descriptor()]
    DrawCanvasPath(path, _) => [path.resource_descriptor()]
    DrawCanvasRectShader(_, shader, _) => [shader.resource_descriptor()]
    DrawCanvasRoundRectShader(_, _, _, shader, _) =>
      [shader.resource_descriptor()]
    DrawCanvasPathShader(path, shader, _) =>
      [path.resource_descriptor(), shader.resource_descriptor()]
    DrawCanvasImage(image, _) => [image.resource_descriptor()]
    DrawCanvasImageRect(image, _, _, _, _) => [image.resource_descriptor()]
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      descriptor.resource_plan(text, font_key~).descriptors
    DrawCanvasShapedGlyphRunUtf8(text, glyph_run, _, _) =>
      glyph_run.resource_plan(text).descriptors
    DeclareRenderResource(descriptor) => [descriptor]
    _ => []
  }
}

///|
fn render_filter_resource_descriptors(
  color_filter : ColorFilterDescriptor?,
  image_filter : ImageFilterDescriptor?,
  mask_filter : MaskFilterDescriptor?,
) -> Array[RendererResourceDescriptor] {
  let descriptors : Array[RendererResourceDescriptor] = []
  match color_filter {
    None => ()
    Some(descriptor) => descriptors.push(descriptor.resource_descriptor())
  }
  match image_filter {
    None => ()
    Some(descriptor) => descriptors.push(descriptor.resource_descriptor())
  }
  match mask_filter {
    None => ()
    Some(descriptor) => descriptors.push(descriptor.resource_descriptor())
  }
  descriptors
}

///|
fn render_paint_stroke_radius(paint : Paint) -> Float {
  let width : Float = if paint.stroke_width <= 0.0 {
    1.0
  } else {
    paint.stroke_width
  }
  width / 2.0
}

///|
fn point_draw_bounds(point : Point, paint : Paint) -> Rect {
  let radius = render_paint_stroke_radius(paint)
  Rect::from_xywh(
    point.x - radius,
    point.y - radius,
    radius * 2.0,
    radius * 2.0,
  )
}

///|
fn points_draw_bounds(points : Array[Point], paint : Paint) -> Rect? {
  match Rect::from_points(points) {
    None => None
    Some(bounds) => {
      let radius = render_paint_stroke_radius(paint)
      Some(bounds.outset(radius, radius))
    }
  }
}

///|
fn line_draw_bounds(start : Point, end : Point, paint : Paint) -> Rect? {
  points_draw_bounds([start, end], paint)
}

///|
let estimated_render_text_advance_per_byte : Float = 8.0

///|
let estimated_render_text_ascent : Float = 12.0

///|
let estimated_render_text_descent : Float = 4.0

///|
fn point_mode_draw_bounds(
  points : Array[Point],
  mode : PointMode,
  paint : Paint,
) -> Rect? {
  match mode {
    Points => points_draw_bounds(points, paint)
    Lines => {
      let used : Array[Point] = []
      for i = 0; i + 1 < points.length(); i = i + 2 {
        used.push(points[i])
        used.push(points[i + 1])
      }
      points_draw_bounds(used, paint)
    }
    Polygon =>
      if points.length() < 2 {
        None
      } else {
        points_draw_bounds(points, paint)
      }
  }
}

///|
fn text_utf8_draw_bounds(
  byte_count : Int,
  origin : Point,
  is_right_to_left? : Bool = false,
) -> Rect? {
  if byte_count <= 0 {
    None
  } else {
    let width = Float::from_int(byte_count) *
      estimated_render_text_advance_per_byte
    let left = if is_right_to_left { origin.x - width } else { origin.x }
    let right = if is_right_to_left { origin.x } else { origin.x + width }
    Some(
      Rect::new(
        left,
        origin.y - estimated_render_text_ascent,
        right,
        origin.y + estimated_render_text_descent,
      ).sorted(),
    )
  }
}

///|
fn text_run_draw_bounds(
  text : Bytes,
  descriptor : TextRunDescriptor,
  origin : Point,
) -> Rect? {
  let range = descriptor.range.clamp_to_text(text)
  text_utf8_draw_bounds(
    range.length(),
    origin,
    is_right_to_left=descriptor.is_right_to_left(),
  )
}

///|
fn shaped_glyph_run_draw_bounds(
  glyph_run : ShapedGlyphRunDescriptor,
  origin : Point,
) -> Rect? {
  if !glyph_run.is_valid() {
    None
  } else {
    let advance = glyph_run.shaped_run.advance
    let right = origin.x + advance.x
    let bottom = origin.y + advance.y
    Some(Rect::new(origin.x, origin.y, right, bottom).sorted())
  }
}

///|
fn image_draw_bounds(image : ImageDescriptor, top_left : Point) -> Rect? {
  match image.dimensions() {
    None => None
    Some(dimensions) =>
      Some(
        Rect::from_xywh(
          top_left.x,
          top_left.y,
          Float::from_int(dimensions.width),
          Float::from_int(dimensions.height),
        ),
      )
  }
}

///|
fn RenderCommand::draw_bounds(self : RenderCommand) -> Rect? {
  match self {
    DrawCanvasPoint(point, paint) => Some(point_draw_bounds(point, paint))
    DrawCanvasLine(start, end, paint) => line_draw_bounds(start, end, paint)
    DrawCanvasPoints(points, mode, paint) =>
      point_mode_draw_bounds(points, mode, paint)
    DrawCanvasRect(rect, _) => Some(rect.sorted())
    DrawCanvasOval(oval, _) => Some(oval.sorted())
    DrawCanvasCircle(center, radius, _) =>
      if radius <= 0.0 {
        None
      } else {
        Some(
          Rect::from_xywh(
            center.x - radius,
            center.y - radius,
            radius * 2.0,
            radius * 2.0,
          ),
        )
      }
    DrawCanvasArc(oval, _, _, _, paint) => {
      let radius = render_paint_stroke_radius(paint)
      Some(oval.sorted().outset(radius, radius))
    }
    DrawCanvasRoundRect(rect, _, _, _) => Some(rect.sorted())
    DrawCanvasRRect(rrect, _) => Some(rrect.bounds())
    DrawCanvasDRRect(outer, _, _) => Some(outer.bounds())
    DrawCanvasRectShader(rect, _, _) => Some(rect.sorted())
    DrawCanvasRoundRectShader(rect, _, _, _, _) => Some(rect.sorted())
    DrawCanvasPath(path, _) => path.bounds()
    DrawCanvasPathShader(path, _, _) => path.bounds()
    DrawCanvasImage(image, top_left) => image_draw_bounds(image, top_left)
    DrawCanvasImageRect(_, _, dst, _, _) => Some(dst.sorted())
    DrawCanvasTextUtf8(text, origin, _) =>
      text_utf8_draw_bounds(text.length(), origin)
    DrawCanvasTextRunUtf8(text, descriptor, _, origin, _) =>
      text_run_draw_bounds(text, descriptor, origin)
    DrawCanvasShapedGlyphRunUtf8(_, glyph_run, origin, _) =>
      shaped_glyph_run_draw_bounds(glyph_run, origin)
    _ => None
  }
}

///|
fn RenderCommand::save_depth_delta(self : RenderCommand) -> Int {
  match self {
    SaveCanvas | SaveCanvasLayer(_, _, _, _, _) => 1
    RestoreCanvas => -1
    _ => 0
  }
}

///|
pub(all) struct RenderCommandStats {
  command_count : Int
  draw_count : Int
  state_count : Int
  transform_count : Int
  clip_count : Int
  clear_count : Int
  present_count : Int
  text_count : Int
  resource_declaration_count : Int
  image_resource_count : Int
  shader_resource_count : Int
  filter_resource_count : Int
  path_resource_count : Int
  text_resource_count : Int
  max_save_depth : Int
  final_save_depth : Int
  unbalanced_restore_count : Int
} derive(Debug, Eq)

///|
pub fn RenderCommandStats::empty() -> RenderCommandStats {
  {
    command_count: 0,
    draw_count: 0,
    state_count: 0,
    transform_count: 0,
    clip_count: 0,
    clear_count: 0,
    present_count: 0,
    text_count: 0,
    resource_declaration_count: 0,
    image_resource_count: 0,
    shader_resource_count: 0,
    filter_resource_count: 0,
    path_resource_count: 0,
    text_resource_count: 0,
    max_save_depth: 0,
    final_save_depth: 0,
    unbalanced_restore_count: 0,
  }
}

///|
pub fn RenderCommandStats::is_state_balanced(self : RenderCommandStats) -> Bool {
  self.final_save_depth == 0 && self.unbalanced_restore_count == 0
}

///|
/// Command stream for one render pass. This is the value-layer boundary a GUI
/// renderer can build and inspect before handing commands to native Skia.
pub(all) struct RenderCommandList {
  pass : RenderPassDescriptor
  commands : Array[RenderCommand]
} derive(Debug, Eq)

///|
pub fn RenderCommandList::new(pass : RenderPassDescriptor) -> RenderCommandList {
  { pass, commands: Array::new() }
}

///|
pub fn RenderCommandList::for_target(
  target : SurfaceTargetDescriptor,
  bounds? : IRect? = None,
  load_op? : RenderPassLoadOp = LoadExisting,
  clear_color? : Color? = None,
  store_op? : RenderPassStoreOp? = None,
) -> RenderCommandList {
  let commands = RenderCommandList::new(
    RenderPassDescriptor::for_target(
      target,
      bounds~,
      load_op~,
      clear_color~,
      store_op~,
    ),
  )
  match target.gpu_context_resource_descriptor() {
    None => commands
    Some(descriptor) => commands.declare_resource(descriptor)
  }
}

///|
pub fn RenderCommandList::length(self : RenderCommandList) -> Int {
  self.commands.length()
}

///|
pub fn RenderCommandList::is_empty(self : RenderCommandList) -> Bool {
  self.commands.is_empty()
}

///|
pub fn RenderCommandList::append(
  self : RenderCommandList,
  command : RenderCommand,
) -> RenderCommandList {
  let commands = self.commands.copy()
  commands.push(command)
  { ..self, commands, }
}

///|
pub fn RenderCommandList::save(self : RenderCommandList) -> RenderCommandList {
  self.append(SaveCanvas)
}

///|
pub fn RenderCommandList::restore(
  self : RenderCommandList,
) -> RenderCommandList {
  self.append(RestoreCanvas)
}

///|
pub fn RenderCommandList::save_layer(
  self : RenderCommandList,
  bounds? : Rect? = None,
  paint? : Paint = Paint::new(),
  color_filter? : ColorFilterDescriptor? = None,
  image_filter? : ImageFilterDescriptor? = None,
  mask_filter? : MaskFilterDescriptor? = None,
) -> RenderCommandList {
  self.append(
    RenderCommand::save_layer(
      bounds~,
      paint~,
      color_filter~,
      image_filter~,
      mask_filter~,
    ),
  )
}

///|
pub fn RenderCommandList::translate(
  self : RenderCommandList,
  delta : Point,
) -> RenderCommandList {
  self.append(RenderCommand::translate(delta))
}

///|
pub fn RenderCommandList::scale(
  self : RenderCommandList,
  scale : Size,
) -> RenderCommandList {
  self.append(RenderCommand::scale(scale))
}

///|
pub fn RenderCommandList::rotate(
  self : RenderCommandList,
  degrees : Float,
) -> RenderCommandList {
  self.append(RenderCommand::rotate(degrees))
}

///|
pub fn RenderCommandList::skew(
  self : RenderCommandList,
  skew : Point,
) -> RenderCommandList {
  self.append(RenderCommand::skew(skew))
}

///|
pub fn RenderCommandList::concat(
  self : RenderCommandList,
  matrix : Matrix,
) -> RenderCommandList {
  self.append(RenderCommand::concat(matrix))
}

///|
pub fn RenderCommandList::reset_matrix(
  self : RenderCommandList,
) -> RenderCommandList {
  self.append(RenderCommand::reset_matrix())
}

///|
pub fn RenderCommandList::clear(
  self : RenderCommandList,
  color : Color,
) -> RenderCommandList {
  self.append(ClearCanvas(color))
}

///|
pub fn RenderCommandList::draw_color(
  self : RenderCommandList,
  color : Color,
  blend_mode? : BlendMode = SrcOver,
) -> RenderCommandList {
  self.append(RenderCommand::draw_color(color, blend_mode~))
}

///|
pub fn RenderCommandList::draw_paint(
  self : RenderCommandList,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_paint(paint))
}

///|
pub fn RenderCommandList::draw_paint_shader(
  self : RenderCommandList,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_paint_shader(shader, paint~))
}

///|
pub fn RenderCommandList::clip_rect(
  self : RenderCommandList,
  rect : Rect,
  op? : ClipOp = Intersect,
) -> RenderCommandList {
  self.append(RenderCommand::clip_rect(rect, op~))
}

///|
pub fn RenderCommandList::clip_rrect(
  self : RenderCommandList,
  rrect : RRect,
  op? : ClipOp = Intersect,
) -> RenderCommandList {
  self.append(RenderCommand::clip_rrect(rrect, op~))
}

///|
pub fn RenderCommandList::clip_path(
  self : RenderCommandList,
  path : Path,
  op? : ClipOp = Intersect,
) -> RenderCommandList {
  self.append(RenderCommand::clip_path(path, op~))
}

///|
pub fn RenderCommandList::draw_point(
  self : RenderCommandList,
  point : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_point(point, paint~))
}

///|
pub fn RenderCommandList::draw_line(
  self : RenderCommandList,
  start : Point,
  end : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_line(start, end, paint~))
}

///|
pub fn RenderCommandList::draw_points(
  self : RenderCommandList,
  points : Array[Point],
  paint? : Paint = Paint::new(),
  mode? : PointMode = Points,
) -> RenderCommandList {
  self.append(RenderCommand::draw_points(points, paint~, mode~))
}

///|
pub fn RenderCommandList::draw_rect(
  self : RenderCommandList,
  rect : Rect,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_rect(rect, paint~))
}

///|
pub fn RenderCommandList::draw_oval(
  self : RenderCommandList,
  oval : Rect,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_oval(oval, paint~))
}

///|
pub fn RenderCommandList::draw_circle(
  self : RenderCommandList,
  center : Point,
  radius : Float,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_circle(center, radius, paint~))
}

///|
pub fn RenderCommandList::draw_arc(
  self : RenderCommandList,
  oval : Rect,
  start_angle : Float,
  sweep_angle : Float,
  use_center : Bool,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(
    RenderCommand::draw_arc(oval, start_angle, sweep_angle, use_center, paint~),
  )
}

///|
pub fn RenderCommandList::draw_round_rect(
  self : RenderCommandList,
  rect : Rect,
  rx : Float,
  ry : Float,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_round_rect(rect, rx, ry, paint~))
}

///|
pub fn RenderCommandList::draw_rrect(
  self : RenderCommandList,
  rrect : RRect,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_rrect(rrect, paint~))
}

///|
pub fn RenderCommandList::draw_drrect(
  self : RenderCommandList,
  outer : RRect,
  inner : RRect,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_drrect(outer, inner, paint~))
}

///|
pub fn RenderCommandList::draw_rect_shader(
  self : RenderCommandList,
  rect : Rect,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_rect_shader(rect, shader, paint~))
}

///|
pub fn RenderCommandList::draw_round_rect_shader(
  self : RenderCommandList,
  rect : Rect,
  rx : Float,
  ry : Float,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(
    RenderCommand::draw_round_rect_shader(rect, rx, ry, shader, paint~),
  )
}

///|
pub fn RenderCommandList::draw_path(
  self : RenderCommandList,
  path : Path,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_path(path, paint~))
}

///|
pub fn RenderCommandList::draw_path_shader(
  self : RenderCommandList,
  path : Path,
  shader : ShaderDescriptor,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_path_shader(path, shader, paint~))
}

///|
pub fn RenderCommandList::draw_image(
  self : RenderCommandList,
  image : ImageDescriptor,
  top_left : Point,
) -> RenderCommandList {
  self.append(RenderCommand::draw_image(image, top_left))
}

///|
pub fn RenderCommandList::draw_image_rect(
  self : RenderCommandList,
  image : ImageDescriptor,
  src : Rect,
  dst : Rect,
  paint? : Paint = Paint::new(),
  sampling? : SamplingOptions = SamplingOptions::new(),
) -> RenderCommandList {
  self.append(
    RenderCommand::draw_image_rect(image, src, dst, paint~, sampling~),
  )
}

///|
pub fn RenderCommandList::draw_text_utf8(
  self : RenderCommandList,
  text : Bytes,
  origin : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_text_utf8(text, origin, paint~))
}

///|
pub fn RenderCommandList::draw_text_run_utf8(
  self : RenderCommandList,
  text : Bytes,
  origin : Point,
  descriptor? : TextRunDescriptor? = None,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(
    RenderCommand::draw_text_run_utf8(
      text,
      origin,
      descriptor~,
      font_key~,
      paint~,
    ),
  )
}

///|
pub fn RenderCommandList::draw_shaped_glyph_run_utf8(
  self : RenderCommandList,
  text : Bytes,
  glyph_run : ShapedGlyphRunDescriptor,
  origin : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(
    RenderCommand::draw_shaped_glyph_run_utf8(text, glyph_run, origin, paint~),
  )
}

///|
pub fn RenderCommandList::declare_resource(
  self : RenderCommandList,
  descriptor : RendererResourceDescriptor,
) -> RenderCommandList {
  if descriptor.key.is_empty() {
    self
  } else {
    self.append(RenderCommand::declare_resource(descriptor))
  }
}

///|
pub fn RenderCommandList::declare_resources(
  self : RenderCommandList,
  descriptors : Array[RendererResourceDescriptor],
) -> RenderCommandList {
  let mut result = self
  for descriptor in descriptors {
    result = result.declare_resource(descriptor)
  }
  result
}

///|
pub fn RenderCommandList::present(
  self : RenderCommandList,
) -> RenderCommandList {
  if self.pass.needs_present() && !self.has_present() {
    self.append(PresentSurface)
  } else {
    self
  }
}

///|
pub fn RenderCommandList::finish(self : RenderCommandList) -> RenderCommandList {
  self.present()
}

///|
pub fn RenderCommandList::has_present(self : RenderCommandList) -> Bool {
  let mut found = false
  for command in self.commands {
    if command.is_present() {
      found = true
    }
  }
  found
}

///|
pub fn RenderCommandList::text_run_resource_keys(
  self : RenderCommandList,
) -> Array[RendererResourceKey] {
  let keys : Array[RendererResourceKey] = Array::new()
  for command in self.commands {
    match command.text_run_resource_key() {
      None => ()
      Some(key) => keys.push(key)
    }
  }
  keys
}

///|
fn renderer_resource_descriptor_list_contains_key(
  descriptors : Array[RendererResourceDescriptor],
  key : RendererResourceKey,
) -> Bool {
  let mut found = false
  for descriptor in descriptors {
    if descriptor.key == key {
      found = true
    }
  }
  found
}

///|
pub fn RenderCommandList::resource_descriptors(
  self : RenderCommandList,
) -> Array[RendererResourceDescriptor] {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  let target_descriptor = self.pass.resource_descriptor()
  if !target_descriptor.key.is_empty() {
    descriptors.push(target_descriptor)
  }
  for command in self.commands {
    for descriptor in command.resource_descriptors() {
      if !descriptor.key.is_empty() &&
        !renderer_resource_descriptor_list_contains_key(
          descriptors,
          descriptor.key,
        ) {
        descriptors.push(descriptor)
      }
    }
  }
  descriptors
}

///|
pub fn RenderCommandList::resource_plan(
  self : RenderCommandList,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.resource_descriptors())
}

///|
fn RenderCommandStats::record_command(
  self : RenderCommandStats,
  command : RenderCommand,
  current_save_depth : Int,
) -> (RenderCommandStats, Int) {
  let mut depth = current_save_depth + command.save_depth_delta()
  let mut unbalanced_restore_count = self.unbalanced_restore_count
  if depth < 0 {
    unbalanced_restore_count += 1
    depth = 0
  }
  let draw_increment = if command.is_draw() { 1 } else { 0 }
  let state_increment = if command.is_state() { 1 } else { 0 }
  let transform_increment = if command.is_transform() { 1 } else { 0 }
  let clip_increment = if command.is_clip() { 1 } else { 0 }
  let clear_increment = if command.is_clear() { 1 } else { 0 }
  let present_increment = if command.is_present() { 1 } else { 0 }
  let text_increment = if command.is_text() { 1 } else { 0 }
  let resource_declaration_increment = if command.is_resource_declaration() {
    1
  } else {
    0
  }
  let resource_counts = command.resource_counts()
  (
    {
      command_count: self.command_count + 1,
      draw_count: self.draw_count + draw_increment,
      state_count: self.state_count + state_increment,
      transform_count: self.transform_count + transform_increment,
      clip_count: self.clip_count + clip_increment,
      clear_count: self.clear_count + clear_increment,
      present_count: self.present_count + present_increment,
      text_count: self.text_count + text_increment,
      resource_declaration_count: self.resource_declaration_count +
      resource_declaration_increment,
      image_resource_count: self.image_resource_count +
      resource_counts.image_resource_count,
      shader_resource_count: self.shader_resource_count +
      resource_counts.shader_resource_count,
      filter_resource_count: self.filter_resource_count +
      resource_counts.filter_resource_count,
      path_resource_count: self.path_resource_count +
      resource_counts.path_resource_count,
      text_resource_count: self.text_resource_count +
      resource_counts.text_resource_count,
      max_save_depth: Int::max(self.max_save_depth, depth),
      final_save_depth: depth,
      unbalanced_restore_count,
    },
    depth,
  )
}

///|
pub fn RenderCommandList::stats(self : RenderCommandList) -> RenderCommandStats {
  for stats = RenderCommandStats::empty(), depth = 0, i = 0
      i < self.commands.length()
      i = i + 1 {
    let (stats, depth) = stats.record_command(self.commands[i], depth)
    continue stats, depth, i + 1
  } nobreak {
    stats
  }
}

///|
pub fn RenderCommandList::is_state_balanced(self : RenderCommandList) -> Bool {
  self.stats().is_state_balanced()
}

///|
fn include_render_command_bounds(bounds : Rect?, next : Rect) -> Rect? {
  if next.is_empty() {
    bounds
  } else {
    match bounds {
      None => Some(next)
      Some(bounds) => Some(bounds.join(next))
    }
  }
}

///|
priv struct RenderCommandBoundsState {
  matrix : Matrix
  clip : Rect
}

///|
fn RenderCommandBoundsState::new(
  pass_bounds : Rect,
) -> RenderCommandBoundsState {
  { matrix: Matrix::identity(), clip: pass_bounds }
}

///|
fn render_command_update_matrix(
  command : RenderCommand,
  current_matrix : Matrix,
  matrix_stack : Array[Matrix],
) -> Matrix {
  match command {
    SaveCanvas | SaveCanvasLayer(_, _, _, _, _) => {
      matrix_stack.push(current_matrix)
      current_matrix
    }
    RestoreCanvas =>
      match matrix_stack.pop() {
        None => Matrix::identity()
        Some(matrix) => matrix
      }
    TranslateCanvas(delta) => current_matrix.post_translate(delta.x, delta.y)
    ScaleCanvas(scale) => current_matrix.post_scale(scale.width, scale.height)
    RotateCanvas(degrees) => current_matrix.post_rotate_degrees(degrees)
    SkewCanvas(skew) => current_matrix.post_skew(skew.x, skew.y)
    ConcatCanvas(matrix) => current_matrix.post_concat(matrix)
    ResetCanvasMatrix => Matrix::identity()
    _ => current_matrix
  }
}

///|
fn render_command_clip_bounds(
  rect : Rect,
  current_matrix : Matrix,
  pass_bounds : Rect,
) -> Rect? {
  current_matrix.map_rect(rect).intersect(pass_bounds)
}

///|
fn render_command_update_clip(
  command : RenderCommand,
  current_matrix : Matrix,
  current_clip : Rect,
  pass_bounds : Rect,
  clip_stack : Array[Rect],
) -> Rect {
  match command {
    SaveCanvas | SaveCanvasLayer(_, _, _, _, _) => {
      clip_stack.push(current_clip)
      current_clip
    }
    RestoreCanvas =>
      match clip_stack.pop() {
        None => pass_bounds
        Some(clip) => clip
      }
    ResetCanvasMatrix => current_clip
    ClipCanvasRect(rect, Intersect) =>
      match render_command_clip_bounds(rect, current_matrix, pass_bounds) {
        None => Rect::empty()
        Some(clip) =>
          match current_clip.intersect(clip) {
            None => Rect::empty()
            Some(clip) => clip
          }
      }
    ClipCanvasRRect(rrect, Intersect) =>
      match
        render_command_clip_bounds(rrect.bounds(), current_matrix, pass_bounds) {
        None => Rect::empty()
        Some(clip) =>
          match current_clip.intersect(clip) {
            None => Rect::empty()
            Some(clip) => clip
          }
      }
    ClipCanvasPath(path, Intersect) =>
      match path.bounds() {
        None => Rect::empty()
        Some(bounds) =>
          match
            render_command_clip_bounds(bounds, current_matrix, pass_bounds) {
            None => Rect::empty()
            Some(clip) =>
              match current_clip.intersect(clip) {
                None => Rect::empty()
                Some(clip) => clip
              }
          }
      }
    ClipCanvasRect(_, Difference)
    | ClipCanvasRRect(_, Difference)
    | ClipCanvasPath(_, Difference) => current_clip
    _ => current_clip
  }
}

///|
fn render_command_transformed_bounds(
  command : RenderCommand,
  current_matrix : Matrix,
  current_clip : Rect,
) -> Rect? {
  match command {
    ClearCanvas(_) => Some(current_clip)
    DrawCanvasColor(_, _) | DrawCanvasPaint(_) => Some(current_clip)
    DrawCanvasPaintShader(_, _) => Some(current_clip)
    command =>
      match command.draw_bounds() {
        None => None
        Some(draw_bounds) =>
          current_matrix.map_rect(draw_bounds).intersect(current_clip)
      }
  }
}

///|
pub fn RenderCommandList::touched_bounds(self : RenderCommandList) -> Rect? {
  let pass_bounds = self.pass.bounds.to_rect()
  if pass_bounds.is_empty() {
    None
  } else {
    let initial_bounds : Rect? = None
    let matrix_stack : Array[Matrix] = []
    let clip_stack : Array[Rect] = []
    for bounds = initial_bounds, state = RenderCommandBoundsState::new(
            pass_bounds,
          ), i = 0
        i < self.commands.length()
        i = i + 1 {
      let command = self.commands[i]
      let next = render_command_transformed_bounds(
        command,
        state.matrix,
        state.clip,
      )
      let bounds = match next {
        None => bounds
        Some(next) => include_render_command_bounds(bounds, next)
      }
      let matrix = render_command_update_matrix(
        command,
        state.matrix,
        matrix_stack,
      )
      let clip = render_command_update_clip(
        command,
        state.matrix,
        state.clip,
        pass_bounds,
        clip_stack,
      )
      continue bounds, { matrix, clip }, i + 1
    } nobreak {
      bounds
    }
  }
}
