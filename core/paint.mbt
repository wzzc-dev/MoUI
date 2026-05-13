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
pub(all) struct TextRun {
  text : String
  frame : Rect
  font : FontSpec
  color : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RoundedRect {
  rect : Rect
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ImageRun {
  source : String
  frame : Rect
  opacity : Double
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
pub(all) enum DrawCommand {
  Clear(Color)
  FillRect(Rect, Color)
  StrokeRect(Rect, Color, Double)
  FillRoundedRect(RoundedRect, Color)
  StrokeRoundedRect(RoundedRect, Color, Double)
  DrawText(TextRun)
  DrawImage(ImageRun)
  PushClip(Rect)
  PopClip
  PushTransform(Transform2D)
  PopTransform
  PushOpacity(Double)
  PopOpacity
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
pub fn FontSpec::new(
  family? : String = "system-ui, sans-serif",
  size? : Double = 16.0,
  weight? : Int = 400,
) -> FontSpec {
  { family, size, weight }
}

///|
pub fn RoundedRect::new(rect~ : Rect, radius? : Double = 0.0) -> RoundedRect {
  { rect, radius }
}

///|
pub fn Transform2D::identity() -> Transform2D {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0 }
}
