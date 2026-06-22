///|
/// Paint color filter applied after color sampling and before opacity.
struct PaintFilter {
  filters : Array[PaintFilterKind]
} derive(Eq, Debug)

///|
/// Public filter stage family used for inspection and paint pipeline planning.
pub(all) enum PaintFilterType {
  Modulate
  Grayscale
  Invert
  Brightness
  Contrast
  Saturate
  Sepia
  ColorMatrix
} derive(Eq, Debug)

///|
priv enum PaintFilterKind {
  Modulate(Color)
  Grayscale
  Invert
  Brightness(Double)
  Contrast(Double)
  Saturate(Double)
  Sepia
  ColorMatrix(Array[Double])
} derive(Eq, Debug)

///|
/// Create a filter chain with no stages. Applying it returns the source color.
pub fn PaintFilter::identity() -> PaintFilter {
  { filters: [] }
}

///|
/// Create a filter that multiplies each source channel by a color.
pub fn PaintFilter::modulate(color : Color) -> PaintFilter {
  make_paint_filter(Modulate(color))
}

///|
/// Create a filter that converts RGB channels to luminance and preserves alpha.
pub fn PaintFilter::grayscale() -> PaintFilter {
  make_paint_filter(Grayscale)
}

///|
/// Create a filter that inverts RGB channels and preserves alpha.
pub fn PaintFilter::invert() -> PaintFilter {
  make_paint_filter(Invert)
}

///|
/// Create a filter that scales RGB brightness and preserves alpha.
pub fn PaintFilter::brightness(factor : Double) -> PaintFilter {
  make_paint_filter(Brightness(normalize_filter_factor(factor)))
}

///|
/// Create a filter that scales RGB contrast around mid-gray and preserves alpha.
pub fn PaintFilter::contrast(factor : Double) -> PaintFilter {
  make_paint_filter(Contrast(normalize_filter_factor(factor)))
}

///|
/// Create a filter that scales RGB saturation around luminance and preserves alpha.
pub fn PaintFilter::saturate(factor : Double) -> PaintFilter {
  make_paint_filter(Saturate(normalize_filter_factor(factor)))
}

///|
/// Create a filter that maps RGB channels through a warm sepia tone matrix.
pub fn PaintFilter::sepia() -> PaintFilter {
  make_paint_filter(Sepia)
}

///|
/// Create a filter from a 4x5 RGBA color matrix.
pub fn PaintFilter::color_matrix(values : Array[Double]) -> PaintFilter {
  make_paint_filter(ColorMatrix(normalize_color_matrix(values)))
}

///|
/// Return a filter that applies this filter and then the next filter.
pub fn PaintFilter::then(self : PaintFilter, next : PaintFilter) -> PaintFilter {
  { filters: concat_filter_kinds(self.filters, next.filters) }
}

///|
/// Compose two filters in application order: first, then second.
pub fn PaintFilter::compose(
  first : PaintFilter,
  second : PaintFilter,
) -> PaintFilter {
  first.then(second)
}

///|
/// Return whether this filter chain has no stages.
pub fn PaintFilter::is_identity(self : PaintFilter) -> Bool {
  self.filters.length() is 0
}

///|
/// Return the number of filter stages in this chain.
pub fn PaintFilter::get_filter_count(self : PaintFilter) -> Int {
  self.filters.length()
}

///|
/// Return the filter stage family at an index.
pub fn PaintFilter::get_stage_type(
  self : PaintFilter,
  index : Int,
) -> PaintFilterType? {
  match self.get_stage_kind(index) {
    Some(kind) => Some(paint_filter_type_of(kind))
    None => None
  }
}

///|
/// Return the stage color for color-bearing filter stages.
pub fn PaintFilter::get_stage_color(self : PaintFilter, index : Int) -> Color? {
  match self.get_stage_kind(index) {
    Some(Modulate(color)) => Some(color)
    _ => None
  }
}

///|
/// Return the numeric factor for factor-bearing filter stages.
pub fn PaintFilter::get_stage_factor(
  self : PaintFilter,
  index : Int,
) -> Double? {
  match self.get_stage_kind(index) {
    Some(Brightness(factor))
    | Some(Contrast(factor))
    | Some(Saturate(factor)) => Some(factor)
    _ => None
  }
}

///|
/// Return a copied 4x5 RGBA color matrix for matrix filter stages.
pub fn PaintFilter::get_stage_color_matrix(
  self : PaintFilter,
  index : Int,
) -> Array[Double]? {
  match self.get_stage_kind(index) {
    Some(ColorMatrix(matrix)) => Some(copy_filter_matrix(matrix))
    _ => None
  }
}

///|
/// Apply this filter to a straight-alpha color.
pub fn PaintFilter::apply(self : PaintFilter, color : Color) -> Color {
  let mut current = color
  for filter in self.filters {
    current = apply_filter_kind(filter, current)
  }
  current
}

///|
fn make_paint_filter(kind : PaintFilterKind) -> PaintFilter {
  { filters: [copy_filter_kind(kind)] }
}

///|
fn concat_filter_kinds(
  first : Array[PaintFilterKind],
  second : Array[PaintFilterKind],
) -> Array[PaintFilterKind] {
  let filters = []
  for kind in first {
    filters.push(copy_filter_kind(kind))
  }
  for kind in second {
    filters.push(copy_filter_kind(kind))
  }
  filters
}

///|
fn copy_filter_kind(kind : PaintFilterKind) -> PaintFilterKind {
  match kind {
    ColorMatrix(matrix) => ColorMatrix(copy_filter_matrix(matrix))
    _ => kind
  }
}

///|
fn copy_filter_matrix(matrix : Array[Double]) -> Array[Double] {
  let copied = []
  for value in matrix {
    copied.push(value)
  }
  copied
}

///|
fn normalize_filter_factor(factor : Double) -> Double {
  guard factor == factor else { return 1.0 }
  if factor < 0.0 {
    0.0
  } else {
    factor
  }
}

///|
fn PaintFilter::get_stage_kind(
  self : PaintFilter,
  index : Int,
) -> PaintFilterKind? {
  guard index >= 0 && index < self.filters.length() else { return None }
  Some(self.filters[index])
}

///|
fn paint_filter_type_of(kind : PaintFilterKind) -> PaintFilterType {
  match kind {
    Modulate(_) => PaintFilterType::Modulate
    Grayscale => PaintFilterType::Grayscale
    Invert => PaintFilterType::Invert
    Brightness(_) => PaintFilterType::Brightness
    Contrast(_) => PaintFilterType::Contrast
    Saturate(_) => PaintFilterType::Saturate
    Sepia => PaintFilterType::Sepia
    ColorMatrix(_) => PaintFilterType::ColorMatrix
  }
}

///|
fn apply_filter_kind(kind : PaintFilterKind, color : Color) -> Color {
  match kind {
    Modulate(factor) =>
      Color::new(
        r=multiply_byte(color.r, factor.r),
        g=multiply_byte(color.g, factor.g),
        b=multiply_byte(color.b, factor.b),
        a=multiply_byte(color.a, factor.a),
      )
    Grayscale => {
      let gray = luminance_byte(color)
      Color::new(r=gray, g=gray, b=gray, a=color.a)
    }
    Invert =>
      Color::new(
        r=invert_byte(color.r),
        g=invert_byte(color.g),
        b=invert_byte(color.b),
        a=color.a,
      )
    Brightness(factor) =>
      Color::new(
        r=scale_rgb_byte(color.r, factor),
        g=scale_rgb_byte(color.g, factor),
        b=scale_rgb_byte(color.b, factor),
        a=color.a,
      )
    Contrast(factor) =>
      Color::new(
        r=contrast_rgb_byte(color.r, factor),
        g=contrast_rgb_byte(color.g, factor),
        b=contrast_rgb_byte(color.b, factor),
        a=color.a,
      )
    Saturate(factor) => {
      let gray = luminance_byte(color)
      Color::new(
        r=saturate_rgb_byte(color.r, gray, factor),
        g=saturate_rgb_byte(color.g, gray, factor),
        b=saturate_rgb_byte(color.b, gray, factor),
        a=color.a,
      )
    }
    Sepia =>
      Color::new(
        r=sepia_rgb_byte(color, 393, 769, 189),
        g=sepia_rgb_byte(color, 349, 686, 168),
        b=sepia_rgb_byte(color, 272, 534, 131),
        a=color.a,
      )
    ColorMatrix(matrix) => apply_color_matrix(matrix, color)
  }
}

///|
fn sample_source_color_with_filter(
  color : Color,
  filter : PaintFilter?,
  opacity : Double,
) -> Color {
  apply_paint_filter(filter, color).scale_alpha(opacity)
}

///|
fn paint_filter_outputs_alpha_from_transparent(
  filter : PaintFilter?,
  opacity : Double,
) -> Bool {
  sample_source_color_with_filter(Color::transparent(), filter, opacity).a != 0
}

///|
fn paint_filter_options_are_visually_equivalent(
  left : PaintFilter?,
  right : PaintFilter?,
) -> Bool {
  if paint_filter_option_is_none_or_identity(left) &&
    paint_filter_option_is_none_or_identity(right) {
    true
  } else {
    left == right
  }
}

///|
fn paint_filter_option_is_none_or_identity(filter : PaintFilter?) -> Bool {
  match filter {
    Some(value) => value.is_identity()
    None => true
  }
}

///|
fn apply_paint_filter(filter : PaintFilter?, color : Color) -> Color {
  match filter {
    Some(value) => value.apply(color)
    None => color
  }
}

///|
fn multiply_byte(a : Byte, b : Byte) -> Byte {
  clamp_byte((a.to_int() * b.to_int() + 127) / 255)
}

///|
fn invert_byte(value : Byte) -> Byte {
  clamp_byte(255 - value.to_int())
}

///|
fn scale_rgb_byte(value : Byte, factor : Double) -> Byte {
  guard factor == factor else { return value }
  guard factor > 0.0 else { return 0 }
  clamp_byte((value.to_int().to_double() * factor + 0.5).to_int())
}

///|
fn contrast_rgb_byte(value : Byte, factor : Double) -> Byte {
  guard factor == factor else { return value }
  guard factor > 0.0 else { return 128 }
  let centered = value.to_int().to_double() - 128.0
  clamp_byte((centered * factor + 128.0 + 0.5).to_int())
}

///|
fn saturate_rgb_byte(value : Byte, gray : Byte, factor : Double) -> Byte {
  guard factor == factor else { return value }
  guard factor > 0.0 else { return gray }
  let base = gray.to_int().to_double()
  let delta = value.to_int().to_double() - base
  clamp_byte((base + delta * factor + 0.5).to_int())
}

///|
fn sepia_rgb_byte(
  color : Color,
  red_weight : Int,
  green_weight : Int,
  blue_weight : Int,
) -> Byte {
  clamp_byte(
    (
      color.r.to_int() * red_weight +
      color.g.to_int() * green_weight +
      color.b.to_int() * blue_weight +
      500
    ) /
    1000,
  )
}

///|
fn normalize_color_matrix(values : Array[Double]) -> Array[Double] {
  guard values.length() == 20 else { return identity_color_matrix() }
  let copied = []
  for value in values {
    copied.push(if value == value { value } else { 0.0 })
  }
  copied
}

///|
fn identity_color_matrix() -> Array[Double] {
  [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ]
}

///|
fn apply_color_matrix(matrix : Array[Double], color : Color) -> Color {
  let r = color.r.to_int().to_double()
  let g = color.g.to_int().to_double()
  let b = color.b.to_int().to_double()
  let a = color.a.to_int().to_double()
  Color::new(
    r=color_matrix_byte(matrix, 0, r, g, b, a),
    g=color_matrix_byte(matrix, 1, r, g, b, a),
    b=color_matrix_byte(matrix, 2, r, g, b, a),
    a=color_matrix_byte(matrix, 3, r, g, b, a),
  )
}

///|
fn color_matrix_byte(
  matrix : Array[Double],
  row : Int,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Byte {
  let offset = row * 5
  clamp_filter_byte(
    matrix[offset] * r +
    matrix[offset + 1] * g +
    matrix[offset + 2] * b +
    matrix[offset + 3] * a +
    matrix[offset + 4],
  )
}

///|
fn clamp_filter_byte(value : Double) -> Byte {
  guard value == value else { return 0 }
  clamp_byte((value + 0.5).to_int())
}

///|
fn luminance_byte(color : Color) -> Byte {
  clamp_byte(
    (
      color.r.to_int() * 77 +
      color.g.to_int() * 150 +
      color.b.to_int() * 29 +
      128
    ) /
    256,
  )
}
