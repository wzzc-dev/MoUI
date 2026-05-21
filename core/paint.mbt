///|
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FontSpec {
  family : String
  size : Double
  weight : Int
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
pub(all) enum Brush {
  Solid(Color)
  LinearGradient(LinearGradientSpec)
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
pub fn FontSpec::new(
  family? : String = "-apple-system, BlinkMacSystemFont, \"SF Pro Text\", \"Segoe UI\", system-ui, sans-serif",
  size? : Double = 16.0,
  weight? : Int = 400,
) -> FontSpec {
  { family, size, weight }
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
pub fn Brush::fallback_color(self : Brush) -> Color {
  match self {
    Solid(color) => color
    LinearGradient(gradient) => gradient.start_color
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
