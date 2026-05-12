///|
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DrawCommand {
  Clear(Color)
  FillRect(Rect, Color)
  PushClip(Rect)
  PopClip
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
