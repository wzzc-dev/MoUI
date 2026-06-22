///|
/// Off-screen drawing cache backed by a Canvas. Layers are intended for GUI
/// subtrees that can redraw locally and then composite their dirty pixels into a
/// parent canvas.
pub struct Layer {
  mut canvas : Canvas
  mut x : Int
  mut y : Int
  mut visible : Bool
  mut opacity : Double
  mut blend_mode : BlendMode
  mut shader : PaintShader?
  mut filter : PaintFilter?
} derive(Debug)

///|
/// Telemetry for a dirty layer composite attempt.
pub struct LayerCompositeResult {
  composited_rect_count : Int
  local_dirty_bounds : PixelRect?
  target_dirty_bounds : PixelRect?
  uses_bounds_fallback : Bool
  did_composite : Bool
  did_clear_dirty : Bool
} derive(Debug)

///|
pub fn Layer::new(width : Int, height : Int) -> Layer {
  {
    canvas: Canvas::new(width, height),
    x: 0,
    y: 0,
    visible: true,
    opacity: 1.0,
    blend_mode: BlendMode::SourceOver,
    shader: None,
    filter: None,
  }
}

///|
pub fn Layer::get_canvas(self : Layer) -> Canvas {
  self.canvas
}

///|
pub fn Layer::get_pixmap(self : Layer) -> Pixmap {
  self.canvas.get_pixmap()
}

///|
pub fn Layer::get_width(self : Layer) -> Int {
  self.canvas.get_pixmap().get_width()
}

///|
pub fn Layer::get_height(self : Layer) -> Int {
  self.canvas.get_pixmap().get_height()
}

///|
pub fn Layer::bounds(self : Layer) -> PixelRect {
  PixelRect::new(x=0, y=0, width=self.get_width(), height=self.get_height())
}

///|
pub fn Layer::translated_bounds(self : Layer) -> PixelRect {
  translate_pixel_rect(self.bounds(), self.x, self.y)
}

///|
pub fn Layer::resize(self : Layer, width : Int, height : Int) -> Layer {
  let safe_width = width.max(0)
  let safe_height = height.max(0)
  guard safe_width != self.get_width() || safe_height != self.get_height() else {
    return self
  }
  let old_pixmap = self.canvas.get_pixmap()
  let new_canvas = Canvas::new(safe_width, safe_height)
  let copy_width = old_pixmap.get_width().min(safe_width)
  let copy_height = old_pixmap.get_height().min(safe_height)
  if copy_width > 0 && copy_height > 0 {
    let new_pixmap = new_canvas.get_pixmap()
    for y in 0..<copy_height {
      for x in 0..<copy_width {
        new_pixmap.set_pixel(x, y, old_pixmap.get_pixel(x, y))
      }
    }
  }
  new_canvas.get_dirty_region().add_all(safe_width, safe_height)
  self.canvas = new_canvas
  self
}

///|
pub fn Layer::set_position(self : Layer, x : Int, y : Int) -> Layer {
  self.x = x
  self.y = y
  self
}

///|
pub fn Layer::get_x(self : Layer) -> Int {
  self.x
}

///|
pub fn Layer::get_y(self : Layer) -> Int {
  self.y
}

///|
pub fn Layer::set_visible(self : Layer, visible : Bool) -> Layer {
  self.visible = visible
  self
}

///|
pub fn Layer::is_visible(self : Layer) -> Bool {
  self.visible
}

///|
pub fn Layer::is_compositable(self : Layer) -> Bool {
  self.is_compositable_with_style(self.opacity, self.blend_mode)
}

///|
pub fn Layer::set_opacity(self : Layer, opacity : Double) -> Layer {
  let clamped = normalize_opacity(opacity)
  guard self.opacity != clamped else { return self }
  self.opacity = clamped
  self.mark_style_dirty_for_style_change(
    self.shader,
    self.shader,
    self.filter,
    self.filter,
    self.blend_mode,
    self.blend_mode,
  )
  self
}

///|
pub fn Layer::get_opacity(self : Layer) -> Double {
  self.opacity
}

///|
pub fn Layer::set_blend_mode(self : Layer, blend_mode : BlendMode) -> Layer {
  let previous_blend_mode = self.blend_mode
  guard previous_blend_mode != blend_mode else { return self }
  self.blend_mode = blend_mode
  self.mark_style_dirty_for_style_change(
    self.shader,
    self.shader,
    self.filter,
    self.filter,
    previous_blend_mode,
    self.blend_mode,
  )
  self
}

///|
pub fn Layer::get_blend_mode(self : Layer) -> BlendMode {
  self.blend_mode
}

///|
/// Set the shader used when compositing this layer. The shader is sampled in
/// layer-local coordinates so moving a layer preserves its cached pattern.
pub fn Layer::set_shader(self : Layer, shader : PaintShader) -> Layer {
  let previous_shader = self.shader
  guard previous_shader != Some(shader) else { return self }
  self.shader = Some(shader)
  self.mark_style_dirty_for_style_change(
    previous_shader,
    self.shader,
    self.filter,
    self.filter,
    self.blend_mode,
    self.blend_mode,
  )
  self
}

///|
pub fn Layer::clear_shader(self : Layer) -> Layer {
  let previous_shader = self.shader
  guard previous_shader is Some(_) else { return self }
  self.shader = None
  self.mark_style_dirty_for_style_change(
    previous_shader,
    self.shader,
    self.filter,
    self.filter,
    self.blend_mode,
    self.blend_mode,
  )
  self
}

///|
pub fn Layer::get_shader(self : Layer) -> PaintShader? {
  self.shader
}

///|
pub fn Layer::set_filter(self : Layer, filter : PaintFilter) -> Layer {
  let previous_filter = self.filter
  guard previous_filter != Some(filter) else { return self }
  self.filter = Some(filter)
  if !paint_filter_options_are_visually_equivalent(previous_filter, self.filter) {
    self.mark_style_dirty_for_style_change(
      self.shader,
      self.shader,
      previous_filter,
      self.filter,
      self.blend_mode,
      self.blend_mode,
    )
  }
  self
}

///|
pub fn Layer::clear_filter(self : Layer) -> Layer {
  let previous_filter = self.filter
  guard previous_filter is Some(_) else { return self }
  self.filter = None
  if !paint_filter_options_are_visually_equivalent(previous_filter, self.filter) {
    self.mark_style_dirty_for_style_change(
      self.shader,
      self.shader,
      previous_filter,
      self.filter,
      self.blend_mode,
      self.blend_mode,
    )
  }
  self
}

///|
pub fn Layer::get_filter(self : Layer) -> PaintFilter? {
  self.filter
}

///|
pub fn Layer::clear(self : Layer, color : Color) -> Unit {
  self.canvas.clear(color)
}

///|
pub fn Layer::clear_dirty_region(self : Layer) -> Unit {
  self.canvas.clear_dirty_region()
}

///|
pub fn Layer::mark_dirty_rect(self : Layer, rect : PixelRect) -> Unit {
  self.canvas.get_dirty_region().add_clipped_rect(rect, self.bounds())
}

///|
pub fn Layer::mark_all_dirty(self : Layer) -> Unit {
  self.canvas.get_dirty_region().add_all(self.get_width(), self.get_height())
}

///|
fn Layer::mark_style_dirty_for_style_change(
  self : Layer,
  previous_shader : PaintShader?,
  next_shader : PaintShader?,
  previous_filter : PaintFilter?,
  next_filter : PaintFilter?,
  previous_blend_mode : BlendMode,
  next_blend_mode : BlendMode,
) -> Unit {
  if (
      self.is_compositable_with_style(self.opacity, previous_blend_mode) ||
      self.is_compositable_with_style(self.opacity, next_blend_mode)
    ) &&
    (
      self.has_nontransparent_pixels() ||
      blend_mode_blends_transparent_source(previous_blend_mode) ||
      blend_mode_blends_transparent_source(next_blend_mode) ||
      self.has_transparent_pixels_revealed_by_style(
        previous_shader,
        previous_filter,
        self.opacity,
      ) ||
      self.has_transparent_pixels_revealed_by_style(
        next_shader,
        next_filter,
        self.opacity,
      )
    ) {
    self.mark_all_dirty()
  }
}

///|
fn Layer::is_compositable_with_style(
  self : Layer,
  opacity : Double,
  blend_mode : BlendMode,
) -> Bool {
  self.visible &&
  (opacity > 0.0 || blend_mode_blends_transparent_source(blend_mode))
}

///|
fn Layer::has_transparent_pixels_revealed_by_style(
  self : Layer,
  shader : PaintShader?,
  filter : PaintFilter?,
  opacity : Double,
) -> Bool {
  match shader {
    Some(_) => false
    None =>
      paint_filter_outputs_alpha_from_transparent(filter, opacity) ||
      self.has_transparent_rgb_pixels_revealed_by_filter(filter, opacity)
  }
}

///|
fn Layer::has_nontransparent_pixels(self : Layer) -> Bool {
  let pixels = self.canvas.get_pixmap().get_pixels()
  let mut i = 3
  while i < pixels.length() {
    if pixels[i] != 0 {
      return true
    }
    i = i + 4
  }
  false
}

///|
fn Layer::has_transparent_rgb_pixels_revealed_by_filter(
  self : Layer,
  filter : PaintFilter?,
  opacity : Double,
) -> Bool {
  let pixels = self.canvas.get_pixmap().get_pixels()
  let mut i = 0
  while i + 3 < pixels.length() {
    if pixels[i + 3] == 0 &&
      (pixels[i] != 0 || pixels[i + 1] != 0 || pixels[i + 2] != 0) {
      let sampled = sample_source_color_with_filter(
        Color::new(r=pixels[i], g=pixels[i + 1], b=pixels[i + 2], a=0),
        filter,
        opacity,
      )
      if sampled.a != 0 {
        return true
      }
    }
    i = i + 4
  }
  false
}

///|
pub fn Layer::get_dirty_region(self : Layer) -> DirtyRegion {
  self.canvas.get_dirty_region()
}

///|
pub fn Layer::has_dirty(self : Layer) -> Bool {
  !self.canvas.get_dirty_region().is_empty()
}

///|
pub fn Layer::dirty_bounds(self : Layer) -> PixelRect? {
  self.canvas.get_dirty_region().bounds()
}

///|
pub fn Layer::translated_dirty_bounds(self : Layer) -> PixelRect? {
  match self.dirty_bounds() {
    Some(bounds) => Some(translate_pixel_rect(bounds, self.x, self.y))
    None => None
  }
}

///|
pub fn Layer::translated_dirty_rects(
  self : Layer,
  max_rects : Int,
) -> Array[PixelRect] {
  let rects = []
  for
    rect in self.canvas
    .get_dirty_region()
    .present_rects(self.bounds(), max_rects) {
    rects.push(translate_pixel_rect(rect, self.x, self.y))
  }
  rects
}

///|
pub fn Layer::composite_to(self : Layer, target : Canvas) -> Int {
  guard self.is_compositable() else { return 0 }
  target.draw_layer_pixmap(
    self.canvas.get_pixmap(),
    self.x,
    self.y,
    self.composite_paint(),
  )
  1
}

///|
pub fn Layer::composite_dirty_to(
  self : Layer,
  target : Canvas,
  max_rects : Int,
) -> Int {
  self.composite_dirty_to_result(target, max_rects).get_composited_rect_count()
}

///|
/// Composite dirty cache pixels and return lifecycle telemetry.
pub fn Layer::composite_dirty_to_result(
  self : Layer,
  target : Canvas,
  max_rects : Int,
) -> LayerCompositeResult {
  guard self.is_compositable() else {
    return {
      composited_rect_count: 0,
      local_dirty_bounds: self.dirty_bounds(),
      target_dirty_bounds: self.translated_dirty_bounds(),
      uses_bounds_fallback: false,
      did_composite: false,
      did_clear_dirty: false,
    }
  }
  let plan = self.canvas
    .get_dirty_region()
    .present_plan(self.bounds(), max_rects)
  let rects = plan.get_rects()
  let local_dirty_bounds = plan.get_present_bounds()
  let target_dirty_bounds = match local_dirty_bounds {
    Some(bounds) => Some(translate_pixel_rect(bounds, self.x, self.y))
    None => None
  }
  guard rects.length() > 0 else {
    return {
      composited_rect_count: 0,
      local_dirty_bounds,
      target_dirty_bounds,
      uses_bounds_fallback: plan.uses_bounds_fallback(),
      did_composite: false,
      did_clear_dirty: false,
    }
  }
  let paint = self.composite_paint()
  for rect in rects {
    target.draw_layer_pixmap_rect(
      self.canvas.get_pixmap(),
      rect,
      self.x + rect.x,
      self.y + rect.y,
      paint,
    )
  }
  self.canvas.clear_dirty_region()
  {
    composited_rect_count: rects.length(),
    local_dirty_bounds,
    target_dirty_bounds,
    uses_bounds_fallback: plan.uses_bounds_fallback(),
    did_composite: true,
    did_clear_dirty: true,
  }
}

///|
/// Return the number of dirty rectangles composited into the target.
pub fn LayerCompositeResult::get_composited_rect_count(
  self : LayerCompositeResult,
) -> Int {
  self.composited_rect_count
}

///|
/// Return the layer-local bounds covered by this composite attempt.
pub fn LayerCompositeResult::get_local_dirty_bounds(
  self : LayerCompositeResult,
) -> PixelRect? {
  self.local_dirty_bounds
}

///|
/// Return the target-space bounds covered by this composite attempt.
pub fn LayerCompositeResult::get_target_dirty_bounds(
  self : LayerCompositeResult,
) -> PixelRect? {
  self.target_dirty_bounds
}

///|
/// Return whether dirty composition fell back to the dirty bounds rectangle
/// because the candidate dirty rect count exceeded the requested limit.
pub fn LayerCompositeResult::uses_bounds_fallback(
  self : LayerCompositeResult,
) -> Bool {
  self.uses_bounds_fallback
}

///|
/// Return whether any dirty pixels were composited into the target.
pub fn LayerCompositeResult::did_composite(self : LayerCompositeResult) -> Bool {
  self.did_composite
}

///|
/// Return whether the layer dirty region was cleared after compositing.
pub fn LayerCompositeResult::did_clear_dirty(
  self : LayerCompositeResult,
) -> Bool {
  self.did_clear_dirty
}

///|
fn Layer::composite_paint(self : Layer) -> Paint {
  let paint = Paint::new()
    .set_opacity(self.opacity)
    .set_blend_mode(self.blend_mode)
  let paint = match self.shader {
    Some(shader) =>
      paint.set_shader(
        shader.transformed(
          Transform::translate(tx=self.x.to_double(), ty=self.y.to_double()),
        ),
      )
    None => paint
  }
  match self.filter {
    Some(filter) => paint.set_filter(filter)
    None => paint
  }
}

///|
fn translate_pixel_rect(rect : PixelRect, x : Int, y : Int) -> PixelRect {
  PixelRect::new(
    x=rect.x + x,
    y=rect.y + y,
    width=rect.width,
    height=rect.height,
  )
}
