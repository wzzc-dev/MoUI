///|
/// Fill rule for path filling
pub(all) enum FillRule {
  NonZero
  EvenOdd
} derive(Eq, Debug)

///|
/// Paint style
pub(all) enum PaintStyle {
  Fill
  Stroke
} derive(Eq, Debug)

///|
/// Stroke cap style
pub(all) enum StrokeCap {
  Butt
  Round
  Square
} derive(Eq, Debug)

///|
/// Stroke join style
pub(all) enum StrokeJoin {
  Miter
  Round
  Bevel
} derive(Eq, Debug)

///|
/// Pixel blend mode used when compositing paint over destination pixels.
pub(all) enum BlendMode {
  Clear
  Source
  Destination
  SourceOver
  DestinationOver
  SourceIn
  DestinationIn
  SourceOut
  DestinationOut
  SourceAtop
  DestinationAtop
  Xor
  Multiply
  Screen
  Add
  Darken
  Lighten
  Difference
  Exclusion
  Overlay
  HardLight
  SoftLight
  ColorDodge
  ColorBurn
  Hue
  Saturation
  Color
  Luminosity
  LinearBurn
  Subtract
} derive(Eq, Debug)

///|
/// Paint configuration for drawing operations
pub struct Paint {
  mut color : Color
  mut shader : PaintShader?
  mut filter : PaintFilter?
  mut style : PaintStyle
  mut blend_mode : BlendMode
  mut stroke_width : Double
  mut stroke_cap : StrokeCap
  mut stroke_join : StrokeJoin
  mut miter_limit : Double
  mut stroke_dash_pattern : Array[Double]
  mut stroke_dash_offset : Double
  mut fill_rule : FillRule
  mut opacity : Double
} derive(Debug)

///|
/// Create a default paint
pub fn Paint::new() -> Paint {
  {
    color: Color::black(),
    shader: None,
    filter: None,
    style: PaintStyle::Fill,
    blend_mode: BlendMode::SourceOver,
    stroke_width: 1.0,
    stroke_cap: StrokeCap::Butt,
    stroke_join: StrokeJoin::Miter,
    miter_limit: 4.0,
    stroke_dash_pattern: [],
    stroke_dash_offset: 0.0,
    fill_rule: FillRule::NonZero,
    opacity: 1.0,
  }
}

///|
/// Set the paint color and clear any shader color source.
pub fn Paint::set_color(self : Paint, color : Color) -> Paint {
  self.color = color
  self.shader = None
  self
}

///|
/// Return the solid paint color used when no shader color source is active.
pub fn Paint::get_color(self : Paint) -> Color {
  self.color
}

///|
/// Set a shader color source for vector and mask drawing.
pub fn Paint::set_shader(self : Paint, shader : PaintShader) -> Paint {
  self.shader = Some(shader)
  self
}

///|
/// Clear shader color source and return to solid-color drawing.
pub fn Paint::clear_shader(self : Paint) -> Paint {
  self.shader = None
  self
}

///|
/// Return the configured shader color source, if any.
pub fn Paint::get_shader(self : Paint) -> PaintShader? {
  self.shader
}

///|
/// Return whether this paint has an active shader color source.
pub fn Paint::has_shader(self : Paint) -> Bool {
  self.shader is Some(_)
}

///|
/// Set a color filter applied after color sampling and before opacity.
pub fn Paint::set_filter(self : Paint, filter : PaintFilter) -> Paint {
  self.filter = Some(filter)
  self
}

///|
/// Clear the active color filter.
pub fn Paint::clear_filter(self : Paint) -> Paint {
  self.filter = None
  self
}

///|
/// Return the configured color filter, if any.
pub fn Paint::get_filter(self : Paint) -> PaintFilter? {
  self.filter
}

///|
/// Return whether this paint has an active color filter.
pub fn Paint::has_filter(self : Paint) -> Bool {
  self.filter is Some(_)
}

///|
/// Set the paint style
pub fn Paint::set_style(self : Paint, style : PaintStyle) -> Paint {
  self.style = style
  self
}

///|
/// Return the paint style.
pub fn Paint::get_style(self : Paint) -> PaintStyle {
  self.style
}

///|
/// Set pixel blend mode used when compositing this paint.
pub fn Paint::set_blend_mode(self : Paint, blend_mode : BlendMode) -> Paint {
  self.blend_mode = blend_mode
  self
}

///|
/// Return the pixel blend mode used when compositing this paint.
pub fn Paint::get_blend_mode(self : Paint) -> BlendMode {
  self.blend_mode
}

///|
/// Set stroke width
pub fn Paint::set_stroke_width(self : Paint, width : Double) -> Paint {
  self.stroke_width = normalize_stroke_width(width)
  self
}

///|
/// Return the stroke width.
pub fn Paint::get_stroke_width(self : Paint) -> Double {
  self.stroke_width
}

///|
/// Set stroke cap style
pub fn Paint::set_stroke_cap(self : Paint, cap : StrokeCap) -> Paint {
  self.stroke_cap = cap
  self
}

///|
/// Return the stroke cap style.
pub fn Paint::get_stroke_cap(self : Paint) -> StrokeCap {
  self.stroke_cap
}

///|
/// Set stroke join style
pub fn Paint::set_stroke_join(self : Paint, join : StrokeJoin) -> Paint {
  self.stroke_join = join
  self
}

///|
/// Return the stroke join style.
pub fn Paint::get_stroke_join(self : Paint) -> StrokeJoin {
  self.stroke_join
}

///|
/// Set stroke miter limit. Values below 1.0 are clamped to the minimum
/// meaningful ratio.
pub fn Paint::set_miter_limit(self : Paint, limit : Double) -> Paint {
  self.miter_limit = if limit > 1.0 { limit } else { 1.0 }
  self
}

///|
/// Return the stroke miter limit.
pub fn Paint::get_miter_limit(self : Paint) -> Double {
  self.miter_limit
}

///|
/// Set stroke dash pattern and phase offset. Empty or non-positive-only
/// patterns draw a solid stroke.
pub fn Paint::set_stroke_dash(
  self : Paint,
  pattern : Array[Double],
  offset : Double,
) -> Paint {
  self.stroke_dash_pattern = normalize_dash_pattern(pattern)
  self.stroke_dash_offset = offset
  self
}

///|
/// Return whether this paint has a normalized stroke dash pattern.
pub fn Paint::has_stroke_dash(self : Paint) -> Bool {
  self.stroke_dash_pattern.length() > 0
}

///|
/// Return a copied normalized stroke dash pattern.
pub fn Paint::get_stroke_dash_pattern(self : Paint) -> Array[Double] {
  copy_paint_dash_pattern(self.stroke_dash_pattern)
}

///|
/// Return the stroke dash phase offset.
pub fn Paint::get_stroke_dash_offset(self : Paint) -> Double {
  self.stroke_dash_offset
}

///|
/// Clear stroke dash pattern and return to solid strokes.
pub fn Paint::clear_stroke_dash(self : Paint) -> Paint {
  self.stroke_dash_pattern = []
  self.stroke_dash_offset = 0.0
  self
}

///|
/// Configure a round dotted stroke using the current stroke width.
pub fn Paint::set_dotted_stroke(self : Paint) -> Paint {
  let dot_length = 0.0001
  let gap = (self.stroke_width * 2.0).max(dot_length)
  self.stroke_cap = StrokeCap::Round
  self.stroke_dash_pattern = [dot_length, gap]
  self.stroke_dash_offset = 0.0
  self
}

///|
/// Set fill rule
pub fn Paint::set_fill_rule(self : Paint, fill_rule : FillRule) -> Paint {
  self.fill_rule = fill_rule
  self
}

///|
/// Return the fill rule used by path filling.
pub fn Paint::get_fill_rule(self : Paint) -> FillRule {
  self.fill_rule
}

///|
/// Set opacity (0.0 to 1.0)
pub fn Paint::set_opacity(self : Paint, opacity : Double) -> Paint {
  self.opacity = normalize_opacity(opacity)
  self
}

///|
/// Return the normalized configured opacity.
pub fn Paint::get_opacity(self : Paint) -> Double {
  self.opacity
}

///|
/// Sample this paint's active color source at a device-space point and apply
/// paint opacity.
pub fn Paint::sample_color(self : Paint, x : Double, y : Double) -> Color {
  let color = match self.shader {
    Some(shader) => shader.sample(x, y)
    None => self.color
  }
  sample_source_color_with_filter(color, self.filter, self.opacity)
}

///|
/// Apply this paint's filter and opacity to a sampled source pixel.
pub fn Paint::sample_source_color(self : Paint, color : Color) -> Color {
  sample_source_color_with_filter(color, self.filter, self.opacity)
}

///|
fn Paint::sample_masked_source_color(
  self : Paint,
  color : Color,
  x : Double,
  y : Double,
) -> Color {
  match self.shader {
    Some(_) => self.sample_color(x, y).blend_alpha_mask(color.a.to_int())
    None => self.sample_source_color(color)
  }
}

///|
fn normalize_dash_pattern(pattern : Array[Double]) -> Array[Double] {
  let normalized = []
  let mut total = 0.0
  for value in pattern {
    if value > 0.0 {
      normalized.push(value)
      total = total + value
    }
  }
  guard normalized.length() > 0 && total > 0.0 else { return [] }
  if normalized.length() % 2 == 1 {
    let original_len = normalized.length()
    for i in 0..<original_len {
      normalized.push(normalized[i])
    }
  }
  normalized
}

///|
fn normalize_stroke_width(width : Double) -> Double {
  guard width == width && width > 0.0 else { return 0.0 }
  width
}

///|
fn copy_paint_dash_pattern(pattern : Array[Double]) -> Array[Double] {
  let copied = []
  for value in pattern {
    copied.push(value)
  }
  copied
}
