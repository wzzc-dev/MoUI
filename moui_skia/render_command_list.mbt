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
