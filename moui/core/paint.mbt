///|
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FontFamily {
  Name(String)
  SystemUi
  UiSansSerif
  UiSerif
  UiMonospace
  SansSerif
  Serif
  Monospace
  Emoji
  Math
  FangSong
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FontFamilyStack {
  families : Array[FontFamily]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FontStyle {
  Normal
  Italic
} derive(Eq, Debug, ToJson)

///|
/// A single variation axis of a variable font. `axis` is the 4-character
/// OpenType tag (e.g. "wght", "wdth", "ital", "opsz", "slnt").
pub struct FontVariation {
  axis : String
  value : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FontSpec {
  families : FontFamilyStack
  size : Double
  weight : Int
  style : FontStyle
  variations : Array[FontVariation]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum TextAlign {
  TextStart
  TextCenter
  TextEnd
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextRun {
  text : String
  frame : Rect
  font : FontSpec
  color : Color
  align : TextAlign
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RoundedRect {
  rect : Rect
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinearGradientSpec {
  start : Point
  end : Point
  start_color : Color
  end_color : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RadialGradientSpec {
  center : Point
  radius : Double
  center_color : Color
  edge_color : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) enum Brush {
  Solid(Color)
  LinearGradient(LinearGradientSpec)
  RadialGradient(RadialGradientSpec)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShadowSpec {
  rect : RoundedRect
  color : Color
  offset : Point
  blur_radius : Double
  spread : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ImageRun {
  source : String
  frame : Rect
  opacity : Double
  fit : ImageFit
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Transform2D {
  a : Double
  b : Double
  c : Double
  d : Double
  tx : Double
  ty : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum BlendMode {
  SourceOver
  Multiply
  Screen
  Overlay
  Darken
  Lighten
} derive(Eq, Debug, ToJson)

///|
pub(all) enum LayerMask {
  NoMask
  RectMask(Rect)
  RoundedMask(RoundedRect)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LayerSpec {
  opacity : Double
  blend_mode : BlendMode
  mask : LayerMask
  offscreen : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RetainedLayerSpec {
  key : String
  frame : Rect
  content_revision : Int
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum FilterEffect {
  Blur(Double)
  Saturate(Double)
  Brightness(Double)
  Contrast(Double)
  ColorMatrix(Array[Double])
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PathVerb {
  MoveTo(Point)
  LineTo(Point)
  QuadTo(Point, Point)
  CubicTo(Point, Point, Point)
  Close
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PathSpec {
  verbs : Array[PathVerb]
  fill : Brush?
  stroke : Brush?
  stroke_width : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShaderEffectSpec {
  name : String
  frame : Rect
  uniforms : Array[Double]
  fallback : Brush
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DrawCommand {
  Clear(Color)
  FillRect(Rect, Color)
  StrokeRect(Rect, Color, Double)
  FillRoundedRect(RoundedRect, Color)
  StrokeRoundedRect(RoundedRect, Color, Double)
  FillRoundedRectBrush(RoundedRect, Brush)
  StrokeRoundedRectBrush(RoundedRect, Brush, Double)
  DrawShadow(ShadowSpec)
  DrawText(TextRun)
  DrawImage(ImageRun)
  PushClip(Rect)
  PopClip
  PushRoundedClip(RoundedRect)
  PopRoundedClip
  PushTransform(Transform2D)
  PopTransform
  PushOpacity(Double)
  PopOpacity
  PushLayer(LayerSpec)
  PopLayer
  BeginRetainedLayer(RetainedLayerSpec)
  EndRetainedLayer(String)
  PushFilter(FilterEffect)
  PopFilter
  DrawPath(PathSpec)
  DrawShaderEffect(ShaderEffectSpec)
} derive(Eq, Debug, ToJson)

///|
pub fn Color::rgba(
  r~ : Double,
  g~ : Double,
  b~ : Double,
  a? : Double = 1.0,
) -> Color {
  { r, g, b, a }
}

///|
pub fn Color::white() -> Color {
  Color::rgba(r=1.0, g=1.0, b=1.0)
}

///|
pub fn Color::black() -> Color {
  Color::rgba(r=0.0, g=0.0, b=0.0)
}

///|
pub fn Color::blue() -> Color {
  Color::rgba(r=0.12, g=0.36, b=0.95)
}

///|
pub fn Color::gray() -> Color {
  Color::rgba(r=0.82, g=0.84, b=0.88)
}

///|
pub fn Color::with_alpha(self : Color, alpha : Double) -> Color {
  { ..self, a: clamp_double(alpha, 0.0, 1.0) }
}

///|
pub fn Color::multiply_alpha(self : Color, opacity : Double) -> Color {
  self.with_alpha(self.a * clamp_double(opacity, 0.0, 1.0))
}

///|
/// Linearly interpolate between this color and `other` by `t` (clamped to
/// 0..1). `t = 0` returns `self`, `t = 1` returns `other`. Used to derive
/// hover/press shades and drive color transitions without a full animation
/// pipeline.
pub fn Color::lerp(self : Color, other : Color, t : Double) -> Color {
  let u = clamp_double(t, 0.0, 1.0)
  Color::rgba(
    r=self.r + (other.r - self.r) * u,
    g=self.g + (other.g - self.g) * u,
    b=self.b + (other.b - self.b) * u,
    a=self.a + (other.a - self.a) * u,
  )
}

///|
/// Alias of `Color::lerp` with the conventional `weight` naming: a `weight`
/// of 0.0 keeps `self`, 1.0 fully adopts `other`.
pub fn Color::mix(self : Color, other : Color, weight : Double) -> Color {
  self.lerp(other, weight)
}

///|
/// Blend this color toward white by `amount` (clamped to 0..1). Useful for
/// deriving hover shades from a base palette color.
pub fn Color::lighten(self : Color, amount : Double) -> Color {
  self.lerp(Color::white(), amount)
}

///|
/// Blend this color toward black by `amount` (clamped to 0..1). Useful for
/// deriving press/active shades from a base palette color.
pub fn Color::darken(self : Color, amount : Double) -> Color {
  self.lerp(Color::black(), amount)
}

///|
pub fn FontFamily::css_name(self : FontFamily) -> String {
  match self {
    Name(name) => name
    SystemUi => "system-ui"
    UiSansSerif => "ui-sans-serif"
    UiSerif => "ui-serif"
    UiMonospace => "ui-monospace"
    SansSerif => "sans-serif"
    Serif => "serif"
    Monospace => "monospace"
    Emoji => "emoji"
    Math => "math"
    FangSong => "fangsong"
  }
}

///|
pub fn FontFamily::css_token(self : FontFamily) -> String {
  match self {
    Name(name) =>
      if font_family_name_needs_quotes(name) {
        "\"" + name.replace(old="\"", new="\\\"") + "\""
      } else {
        name
      }
    _ => self.css_name()
  }
}

///|
fn font_family_name_needs_quotes(name : String) -> Bool {
  name.contains(" ") || name.contains(",") || name.contains("\"")
}

///|
pub fn FontFamilyStack::new(families : Array[FontFamily]) -> FontFamilyStack {
  if families.is_empty() {
    FontFamilyStack::system_ui()
  } else {
    { families, }
  }
}

///|
pub fn FontFamilyStack::system_ui() -> FontFamilyStack {
  { families: [SystemUi] }
}

///|
pub fn FontFamilyStack::sans_serif() -> FontFamilyStack {
  { families: [SansSerif] }
}

///|
pub fn FontFamilyStack::serif() -> FontFamilyStack {
  { families: [Serif] }
}

///|
pub fn FontFamilyStack::monospace() -> FontFamilyStack {
  { families: [UiMonospace, Monospace] }
}

///|
pub fn FontFamilyStack::named(name : String) -> FontFamilyStack {
  { families: [FontFamily::Name(name)] }
}

///|
pub fn FontFamilyStack::with_fallback(
  self : FontFamilyStack,
  family : FontFamily,
) -> FontFamilyStack {
  let families = self.families.copy()
  families.push(family)
  { families, }
}

///|
pub fn FontFamilyStack::css(self : FontFamilyStack) -> String {
  let parts : Array[String] = []
  for family in self.families {
    parts.push(family.css_token())
  }
  parts.join(", ")
}

///|
pub fn FontVariation::new(axis~ : String, value~ : Double) -> FontVariation {
  { axis, value }
}

///|
pub fn FontVariation::axis(self : FontVariation) -> String {
  self.axis
}

///|
pub fn FontVariation::value(self : FontVariation) -> Double {
  self.value
}

///|
pub fn FontSpec::new(
  families? : FontFamilyStack = FontFamilyStack::system_ui(),
  size? : Double = 16.0,
  weight? : Int = 400,
  style? : FontStyle = FontStyle::Normal,
  variations? : Array[FontVariation] = [],
) -> FontSpec {
  { families, size, weight, style, variations }
}

///|
/// Returns a copy of this font spec with one more variable-font axis applied.
/// Later axes win when the same tag appears twice.
pub fn FontSpec::with_variation(
  self : FontSpec,
  axis~ : String,
  value~ : Double,
) -> FontSpec {
  let variations = self.variations.filter(
    fn(existing) { existing.axis != axis },
  )
  variations.push(FontVariation::new(axis~, value~))
  { ..self, variations }
}

///|
pub fn FontSpec::variation_value(self : FontSpec, axis : String) -> Double? {
  let mut found : Double? = None
  for variation in self.variations {
    if variation.axis == axis {
      found = Some(variation.value)
    }
  }
  found
}

///|
pub fn FontSpec::css_family(self : FontSpec) -> String {
  self.families.css()
}

///|
pub fn FontSpec::css_style(self : FontSpec) -> String {
  match self.style {
    Normal => "normal"
    Italic => "italic"
  }
}

///|
pub fn TextRun::new(
  text~ : String,
  frame~ : Rect,
  font~ : FontSpec,
  color~ : Color,
  align? : TextAlign = TextAlign::TextCenter,
) -> TextRun {
  { text, frame, font, color, align }
}

///|
pub fn RoundedRect::new(rect~ : Rect, radius? : Double = 0.0) -> RoundedRect {
  { rect, radius }
}

///|
pub fn LinearGradientSpec::new(
  start~ : Point,
  end~ : Point,
  start_color~ : Color,
  end_color~ : Color,
) -> LinearGradientSpec {
  { start, end, start_color, end_color }
}

///|
pub fn RadialGradientSpec::new(
  center~ : Point,
  radius~ : Double,
  center_color~ : Color,
  edge_color~ : Color,
) -> RadialGradientSpec {
  { center, radius: radius.max(0.0), center_color, edge_color }
}

///|
pub fn Brush::solid(color : Color) -> Brush {
  Solid(color)
}

///|
pub fn Brush::linear_gradient(
  start~ : Point,
  end~ : Point,
  start_color~ : Color,
  end_color~ : Color,
) -> Brush {
  LinearGradient(
    LinearGradientSpec::new(start~, end~, start_color~, end_color~),
  )
}

///|
pub fn Brush::radial_gradient(
  center~ : Point,
  radius~ : Double,
  center_color~ : Color,
  edge_color~ : Color,
) -> Brush {
  RadialGradient(
    RadialGradientSpec::new(center~, radius~, center_color~, edge_color~),
  )
}

///|
pub fn Brush::fallback_color(self : Brush) -> Color {
  match self {
    Solid(color) => color
    LinearGradient(gradient) => gradient.start_color
    RadialGradient(gradient) => gradient.center_color
  }
}

///|
pub fn Brush::multiply_alpha(self : Brush, opacity : Double) -> Brush {
  match self {
    Solid(color) => Solid(color.multiply_alpha(opacity))
    LinearGradient(gradient) =>
      LinearGradient({
        ..gradient,
        start_color: gradient.start_color.multiply_alpha(opacity),
        end_color: gradient.end_color.multiply_alpha(opacity),
      })
    RadialGradient(gradient) =>
      RadialGradient({
        ..gradient,
        center_color: gradient.center_color.multiply_alpha(opacity),
        edge_color: gradient.edge_color.multiply_alpha(opacity),
      })
  }
}

///|
pub fn ShadowSpec::new(
  rect~ : RoundedRect,
  color~ : Color,
  offset? : Point = Point::new(x=0.0, y=2.0),
  blur_radius? : Double = 8.0,
  spread? : Double = 0.0,
) -> ShadowSpec {
  { rect, color, offset, blur_radius, spread }
}

///|
pub fn Transform2D::identity() -> Transform2D {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0 }
}

///|
pub fn Transform2D::translation(dx~ : Double, dy~ : Double) -> Transform2D {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: dx, ty: dy }
}

///|
pub fn Transform2D::scale(sx~ : Double, sy~ : Double) -> Transform2D {
  { a: sx, b: 0.0, c: 0.0, d: sy, tx: 0.0, ty: 0.0 }
}

///|
pub fn LayerSpec::new(
  opacity? : Double = 1.0,
  blend_mode? : BlendMode = BlendMode::SourceOver,
  mask? : LayerMask = LayerMask::NoMask,
  offscreen? : Bool = false,
) -> LayerSpec {
  { opacity: clamp_double(opacity, 0.0, 1.0), blend_mode, mask, offscreen }
}

///|
pub fn RetainedLayerSpec::new(
  key~ : String,
  frame~ : Rect,
  content_revision~ : Int,
  scale_factor? : Double = 1.0,
) -> RetainedLayerSpec {
  { key, frame, content_revision, scale_factor }
}

///|
pub fn FilterEffect::blur(radius : Double) -> FilterEffect {
  Blur(radius)
}

///|
pub fn PathSpec::new(
  verbs~ : Array[PathVerb],
  fill? : Brush? = None,
  stroke? : Brush? = None,
  stroke_width? : Double = 1.0,
) -> PathSpec {
  { verbs, fill, stroke, stroke_width }
}

///|
pub fn ShaderEffectSpec::new(
  name~ : String,
  frame~ : Rect,
  uniforms? : Array[Double] = [],
  fallback? : Brush = Brush::solid(Color::black()),
) -> ShaderEffectSpec {
  { name, frame, uniforms, fallback }
}
