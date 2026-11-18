///|
/// Color model for the p5 sketch core.
///
/// A `Color` is always stored as gamma-encoded sRGB with channels and alpha in
/// `[0, 1]`. `color_mode` only changes how numbers are *interpreted* on input;
/// it does not change the stored representation.

///|
#derive(Eq, Debug)
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
}

///|
pub extend Color with Eq::{not_equal, equal}

///|
pub extend Color with Debug::{to_repr}

///|
pub fn Color::new(r : Double, g : Double, b : Double, a : Double) -> Color {
  { r: clamp01(r), g: clamp01(g), b: clamp01(b), a: clamp01(a), }
}

///|
pub fn Color::solid(r : Double, g : Double, b : Double) -> Color {
  Color::new(r, g, b, 1.0)
}

///|
/// Builds a color from 0..255 components.
pub fn Color::rgb(
  r : Double,
  g : Double,
  b : Double,
  a~ : Double = 255.0,
) -> Color {
  Color::new(r / 255.0, g / 255.0, b / 255.0, a / 255.0)
}

///|
/// Builds a color from a packed `0xAARRGGBB` value.
pub fn Color::from_argb(value : UInt32) -> Color {
  let channel = fn(shift : Int32) {
    ((value >> shift) & 0xFFU).to_double() / 255.0
  }
  Color::new(channel(16), channel(8), channel(0), channel(24))
}

///|
pub fn Color::white() -> Color {
  Color::new(1.0, 1.0, 1.0, 1.0)
}

///|
pub fn Color::black() -> Color {
  Color::new(0.0, 0.0, 0.0, 1.0)
}

///|
pub fn Color::transparent() -> Color {
  Color::new(0.0, 0.0, 0.0, 0.0)
}

///|
pub fn Color::with_alpha(self : Color, alpha : Double) -> Color {
  { ..self, a: clamp01(alpha), }
}

///|
pub fn Color::lerp(self : Color, other : Color, amount : Double) -> Color {
  let t = clamp01(amount)
  Color::new(
    self.r + (other.r - self.r) * t,
    self.g + (other.g - self.g) * t,
    self.b + (other.b - self.b) * t,
    self.a + (other.a - self.a) * t,
  )
}

///|
pub fn Color::to_tuple(self : Color) -> (Double, Double, Double, Double) {
  (self.r, self.g, self.b, self.a)
}

///|
pub fn Color::red(self : Color) -> Double {
  self.r * 255.0
}

///|
pub fn Color::green(self : Color) -> Double {
  self.g * 255.0
}

///|
pub fn Color::blue(self : Color) -> Double {
  self.b * 255.0
}

///|
pub fn Color::alpha(self : Color) -> Double {
  self.a * 255.0
}

///|
/// Hue in `[0, 360)`.
pub fn Color::hue(self : Color) -> Double {
  let maximum = self.r.max(self.g).max(self.b)
  let minimum = self.r.min(self.g).min(self.b)
  let delta = maximum - minimum
  if delta == 0.0 {
    return 0.0
  }
  let hue = if maximum == self.r {
    (self.g - self.b) / delta % 6.0
  } else if maximum == self.g {
    (self.b - self.r) / delta + 2.0
  } else {
    (self.r - self.g) / delta + 4.0
  }
  let degrees = hue * 60.0
  if degrees < 0.0 {
    degrees + 360.0
  } else {
    degrees
  }
}

///|
/// HSB saturation in `[0, 100]`.
pub fn Color::saturation(self : Color) -> Double {
  let maximum = self.r.max(self.g).max(self.b)
  if maximum == 0.0 {
    0.0
  } else {
    (maximum - self.r.min(self.g).min(self.b)) / maximum * 100.0
  }
}

///|
/// HSB brightness in `[0, 100]`.
pub fn Color::brightness(self : Color) -> Double {
  self.r.max(self.g).max(self.b) * 100.0
}

///|
/// HSL lightness in `[0, 100]`.
pub fn Color::lightness(self : Color) -> Double {
  (self.r.max(self.g).max(self.b) + self.r.min(self.g).min(self.b)) /
  2.0 *
  100.0
}

///|
fn clamp01(value : Double) -> Double {
  if value.is_nan() {
    0.0
  } else {
    value.max(0.0).min(1.0)
  }
}

///|
/// Color spaces supported on input.
#derive(Eq)
pub(all) enum ColorMode {
  RGB
  HSB
  HSL
}

///|
/// Upper bounds used to map user numbers into the normalized color model.
#derive(Eq)
pub(all) struct ColorRanges {
  c0 : Double
  c1 : Double
  c2 : Double
  alpha : Double
}

///|
pub fn ColorRanges::new(
  c0 : Double,
  c1 : Double,
  c2 : Double,
  alpha : Double,
) -> ColorRanges {
  { c0, c1, c2, alpha, }
}

///|
pub fn ColorRanges::uniform(mode : ColorMode, maximum : Double) -> ColorRanges {
  let _ = mode
  { c0: maximum, c1: maximum, c2: maximum, alpha: maximum, }
}

///|
pub fn default_color_ranges(mode : ColorMode) -> ColorRanges {
  match mode {
    RGB => { c0: 255.0, c1: 255.0, c2: 255.0, alpha: 255.0, }
    HSB | HSL => { c0: 360.0, c1: 100.0, c2: 100.0, alpha: 1.0, }
  }
}

///|
fn channel(value : Double, maximum : Double) -> Double {
  if maximum == 0.0 {
    0.0
  } else {
    clamp01(value / maximum)
  }
}

///|
/// Converts user values in `mode`/`ranges` into a normalized sRGB color.
pub fn color_from_values(
  values : ArrayView[Double],
  mode : ColorMode,
  ranges : ColorRanges,
) -> Color {
  let (c0, c1, c2, alpha) = match values {
    [gray] => (gray, gray, gray, ranges.alpha)
    [gray, a] => (gray, gray, gray, a)
    [c0, c1, c2] => (c0, c1, c2, ranges.alpha)
    [c0, c1, c2, a] => (c0, c1, c2, a)
    _ => (0.0, 0.0, 0.0, ranges.alpha)
  }
  let a = channel(alpha, ranges.alpha)
  match mode {
    RGB =>
      Color::new(
        channel(c0, ranges.c0),
        channel(c1, ranges.c1),
        channel(c2, ranges.c2),
        a,
      )
    HSB =>
      hsb_to_rgb(
        channel(c0, ranges.c0) * 360.0,
        channel(c1, ranges.c1),
        channel(c2, ranges.c2),
        a,
      )
    HSL =>
      hsl_to_rgb(
        channel(c0, ranges.c0) * 360.0,
        channel(c1, ranges.c1),
        channel(c2, ranges.c2),
        a,
      )
  }
}

///|
pub fn hsb_to_rgb(
  hue : Double,
  saturation : Double,
  brightness : Double,
  alpha : Double,
) -> Color {
  let h = (hue % 360.0 + 360.0) % 360.0 / 60.0
  let s = clamp01(saturation)
  let v = clamp01(brightness)
  let i = h.floor()
  let f = h - i
  let p = v * (1.0 - s)
  let q = v * (1.0 - f * s)
  let t = v * (1.0 - (1.0 - f) * s)
  let (r, g, b) = match i.to_int() % 6 {
    0 => (v, t, p)
    1 => (q, v, p)
    2 => (p, v, t)
    3 => (p, q, v)
    4 => (t, p, v)
    _ => (v, p, q)
  }
  Color::new(r, g, b, alpha)
}

///|
pub fn hsl_to_rgb(
  hue : Double,
  saturation : Double,
  lightness : Double,
  alpha : Double,
) -> Color {
  let h = (hue % 360.0 + 360.0) % 360.0 / 360.0
  let s = clamp01(saturation)
  let l = clamp01(lightness)
  if s == 0.0 {
    return Color::new(l, l, l, alpha)
  }
  let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s }
  let p = 2.0 * l - q
  let hue_to_rgb = fn(t0 : Double) {
    let t = (t0 % 1.0 + 1.0) % 1.0
    if t < 1.0 / 6.0 {
      p + (q - p) * 6.0 * t
    } else if t < 1.0 / 2.0 {
      q
    } else if t < 2.0 / 3.0 {
      p + (q - p) * (2.0 / 3.0 - t) * 6.0
    } else {
      p
    }
  }
  Color::new(
    hue_to_rgb(h + 1.0 / 3.0),
    hue_to_rgb(h),
    hue_to_rgb(h - 1.0 / 3.0),
    alpha,
  )
}

///|
/// Numbers accepted inside color tuples. `Int` and `Double` can be mixed.
pub(open) trait Num {
  fn to_num(Self) -> Double
}

///|
pub impl Num for Int32 with fn to_num(self) {
  self.to_double()
}

///|
pub impl Num for Double with fn to_num(self) {
  self
}

///|
/// Values accepted by `fill`, `stroke`, `background`, and `color`.
pub(open) trait ColorArg {
  fn to_color(Self, ColorMode, ColorRanges) -> Color
}

///|
pub impl ColorArg for Color with fn to_color(self, _, _) {
  self
}

///|
pub impl ColorArg for Int32 with fn to_color(self, mode, ranges) {
  color_from_values([self.to_double()], mode, ranges)
}

///|
pub impl ColorArg for Double with fn to_color(self, mode, ranges) {
  color_from_values([self], mode, ranges)
}

///|
pub impl[A : Num, B : Num] ColorArg for (A, B) with fn to_color(
  self,
  mode,
  ranges,
) {
  color_from_values([self.0.to_num(), self.1.to_num()], mode, ranges)
}

///|
pub impl[A : Num, B : Num, C : Num] ColorArg for (A, B, C) with fn to_color(
  self,
  mode,
  ranges,
) {
  color_from_values(
    [self.0.to_num(), self.1.to_num(), self.2.to_num()],
    mode,
    ranges,
  )
}

///|
pub impl[A : Num, B : Num, C : Num, D : Num] ColorArg for (A, B, C, D) with fn to_color(
  self,
  mode,
  ranges,
) {
  color_from_values(
    [self.0.to_num(), self.1.to_num(), self.2.to_num(), self.3.to_num()],
    mode,
    ranges,
  )
}

///|
pub impl ColorArg for String with fn to_color(self, _, _) {
  parse_color(self).unwrap_or_else(() => Color::black())
}

///|
/// Parses `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, and a useful subset of CSS
/// named colors.
pub fn parse_color(text : String) -> Color? {
  let value = text.trim().to_lower().to_owned()
  if value.has_prefix("#") {
    return parse_hex(value[1:])
  }
  named_color(value)
}

///|
fn parse_hex(hex : StringView) -> Color? {
  let digit = fn(c : Char) -> Double? {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      Some((code - 48).to_double())
    } else if code >= 97 && code <= 102 {
      Some((code - 87).to_double())
    } else if code >= 65 && code <= 70 {
      Some((code - 55).to_double())
    } else {
      None
    }
  }
  let chars = hex.to_array()
  match chars.length() {
    3 =>
      match (digit(chars[0]), digit(chars[1]), digit(chars[2])) {
        (Some(r), Some(g), Some(b)) =>
          Some(
            Color::new(
              (r * 16.0 + r) / 255.0,
              (g * 16.0 + g) / 255.0,
              (b * 16.0 + b) / 255.0,
              1.0,
            ),
          )
        _ => None
      }
    4 =>
      match
        (digit(chars[0]), digit(chars[1]), digit(chars[2]), digit(chars[3])) {
        (Some(r), Some(g), Some(b), Some(a)) =>
          Some(
            Color::new(
              (r * 16.0 + r) / 255.0,
              (g * 16.0 + g) / 255.0,
              (b * 16.0 + b) / 255.0,
              (a * 16.0 + a) / 255.0,
            ),
          )
        _ => None
      }
    6 =>
      match (digit(chars[0]), digit(chars[1]), digit(chars[2])) {
        (Some(r1), Some(r2), Some(g1)) =>
          match (digit(chars[3]), digit(chars[4]), digit(chars[5])) {
            (Some(g2), Some(b1), Some(b2)) =>
              Some(
                Color::new(
                  (r1 * 16.0 + r2) / 255.0,
                  (g1 * 16.0 + g2) / 255.0,
                  (b1 * 16.0 + b2) / 255.0,
                  1.0,
                ),
              )
            _ => None
          }
        _ => None
      }
    8 =>
      match
        (digit(chars[0]), digit(chars[1]), digit(chars[2]), digit(chars[3])) {
        (Some(r1), Some(r2), Some(g1), Some(g2)) =>
          match
            (digit(chars[4]), digit(chars[5]), digit(chars[6]), digit(chars[7])) {
            (Some(b1), Some(b2), Some(a1), Some(a2)) =>
              Some(
                Color::new(
                  (r1 * 16.0 + r2) / 255.0,
                  (g1 * 16.0 + g2) / 255.0,
                  (b1 * 16.0 + b2) / 255.0,
                  (a1 * 16.0 + a2) / 255.0,
                ),
              )
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn named_color(name : String) -> Color? {
  match name {
    "black" => Some(Color::rgb(0, 0, 0))
    "white" => Some(Color::rgb(255, 255, 255))
    "red" => Some(Color::rgb(255, 0, 0))
    "green" => Some(Color::rgb(0, 128, 0))
    "lime" => Some(Color::rgb(0, 255, 0))
    "blue" => Some(Color::rgb(0, 0, 255))
    "yellow" => Some(Color::rgb(255, 255, 0))
    "cyan" | "aqua" => Some(Color::rgb(0, 255, 255))
    "magenta" | "fuchsia" => Some(Color::rgb(255, 0, 255))
    "gray" | "grey" => Some(Color::rgb(128, 128, 128))
    "silver" => Some(Color::rgb(192, 192, 192))
    "maroon" => Some(Color::rgb(128, 0, 0))
    "olive" => Some(Color::rgb(128, 128, 0))
    "navy" => Some(Color::rgb(0, 0, 128))
    "teal" => Some(Color::rgb(0, 128, 128))
    "purple" => Some(Color::rgb(128, 0, 128))
    "orange" => Some(Color::rgb(255, 165, 0))
    "pink" => Some(Color::rgb(255, 192, 203))
    "brown" => Some(Color::rgb(165, 42, 42))
    "gold" => Some(Color::rgb(255, 215, 0))
    "indigo" => Some(Color::rgb(75, 0, 130))
    "violet" => Some(Color::rgb(238, 130, 238))
    "coral" => Some(Color::rgb(255, 127, 80))
    "salmon" => Some(Color::rgb(250, 128, 114))
    "khaki" => Some(Color::rgb(240, 230, 140))
    "beige" => Some(Color::rgb(245, 245, 220))
    "ivory" => Some(Color::rgb(255, 255, 240))
    "transparent" => Some(Color::transparent())
    _ => None
  }
}

///|
pub extend ColorMode with Eq::{not_equal, equal}

///|
pub extend ColorRanges with Eq::{not_equal, equal}

///|
pub extend Color with ColorArg::{to_color}
