///|
/// Packed Skia ARGB color in 0xAARRGGBB order.
pub(all) struct Color(UInt) derive(Debug, Eq)

///|
pub fn Color::new(argb : UInt) -> Color {
  Color(argb)
}

///|
pub fn Color::from_argb(a : Byte, r : Byte, g : Byte, b : Byte) -> Color {
  let value = (a.to_uint() << 24) |
    (r.to_uint() << 16) |
    (g.to_uint() << 8) |
    b.to_uint()
  Color::new(value)
}

///|
pub fn Color::from_rgb(r : Byte, g : Byte, b : Byte) -> Color {
  Color::from_argb(0xff, r, g, b)
}

///|
pub fn Color::argb(self : Color) -> UInt {
  let Color(value) = self
  value
}

///|
pub fn Color::a(self : Color) -> Byte {
  ((self.argb() >> 24) & 0xff).to_byte()
}

///|
pub fn Color::r(self : Color) -> Byte {
  ((self.argb() >> 16) & 0xff).to_byte()
}

///|
pub fn Color::g(self : Color) -> Byte {
  ((self.argb() >> 8) & 0xff).to_byte()
}

///|
pub fn Color::b(self : Color) -> Byte {
  (self.argb() & 0xff).to_byte()
}

///|
pub fn Color::with_alpha(self : Color, alpha : Byte) -> Color {
  Color::from_argb(alpha, self.r(), self.g(), self.b())
}

///|
pub fn Color::to_color4f(self : Color) -> Color4f {
  fn normalize(x : Byte) -> Scalar {
    Float::from_uint(x.to_uint()) / 255.0
  }

  Color4f::new(
    normalize(self.r()),
    normalize(self.g()),
    normalize(self.b()),
    normalize(self.a()),
  )
}

///|
pub fn Color::transparent() -> Color {
  Color::new(0x00000000U)
}

///|
pub fn Color::black() -> Color {
  Color::new(0xff000000U)
}

///|
pub fn Color::dark_gray() -> Color {
  Color::new(0xff444444U)
}

///|
pub fn Color::gray() -> Color {
  Color::new(0xff888888U)
}

///|
pub fn Color::light_gray() -> Color {
  Color::new(0xffccccccU)
}

///|
pub fn Color::white() -> Color {
  Color::new(0xffffffffU)
}

///|
pub fn Color::red() -> Color {
  Color::new(0xffff0000U)
}

///|
pub fn Color::green() -> Color {
  Color::new(0xff00ff00U)
}

///|
pub fn Color::blue() -> Color {
  Color::new(0xff0000ffU)
}

///|
pub fn Color::yellow() -> Color {
  Color::new(0xffffff00U)
}

///|
pub fn Color::cyan() -> Color {
  Color::new(0xff00ffffU)
}

///|
pub fn Color::magenta() -> Color {
  Color::new(0xffff00ffU)
}

///|
pub impl Default for Color with fn default() {
  Color::black()
}

///|
/// Floating-point RGBA color in linear component order.
pub(all) struct Color4f {
  r : Scalar
  g : Scalar
  b : Scalar
  a : Scalar
} derive(Debug, Eq)

///|
pub fn Color4f::new(r : Scalar, g : Scalar, b : Scalar, a : Scalar) -> Color4f {
  { r, g, b, a }
}

///|
pub fn Color4f::from_color(color : Color) -> Color4f {
  color.to_color4f()
}

///|
pub fn Color4f::from_opaque(r : Scalar, g : Scalar, b : Scalar) -> Color4f {
  Color4f::new(r, g, b, 1.0)
}

///|
pub fn Color4f::transparent() -> Color4f {
  Color4f::new(0, 0, 0, 0)
}

///|
pub fn Color4f::scale(self : Color4f, scale : Scalar) -> Color4f {
  Color4f::new(self.r * scale, self.g * scale, self.b * scale, self.a * scale)
}

///|
pub fn Color4f::with_alpha(self : Color4f, alpha : Scalar) -> Color4f {
  Color4f::new(self.r, self.g, self.b, alpha)
}

///|
pub impl Default for Color4f with fn default() {
  Color::black().to_color4f()
}
