///|
/// Typography values shared by the sketch core and backends.

///|
#derive(Eq)
pub(all) struct FontSpec {
  family : String
  size : Double
  weight : Int32
  italic : Bool
  leading : Double
}

///|
pub fn FontSpec::new(
  family~ : String = "sans-serif",
  size~ : Double = 14.0,
  weight~ : Int32 = 400,
  italic~ : Bool = false,
  leading~ : Double = 17.0,
) -> FontSpec {
  { family, size, weight, italic, leading, }
}

///|
#derive(Eq)
pub(all) struct TextMetrics {
  width : Double
  height : Double
  ascent : Double
  descent : Double
}

///|
pub fn TextMetrics::new(
  width~ : Double,
  height~ : Double,
  ascent~ : Double,
  descent~ : Double,
) -> TextMetrics {
  { width, height, ascent, descent, }
}

///|
#derive(Eq)
pub(all) enum HAlign {
  Left
  HCenter
  Right
}

///|
#derive(Eq)
pub(all) enum VAlign {
  Top
  VCenter
  Bottom
  Baseline
}

///|
#derive(Eq)
pub(all) enum TextStyle {
  Normal
  Italic
  Bold
  BoldItalic
}

///|
#derive(Eq)
pub(all) enum TextWrap {
  Word
  Char
}

///|
#derive(Eq)
pub(all) enum StrokeCap {
  Round
  Square
  Project
}

///|
#derive(Eq)
pub(all) enum StrokeJoin {
  Miter
  Bevel
  RoundJoin
}

///|
/// Blend modes the core understands. Backends map them best-effort.
#derive(Eq)
pub(all) enum BlendMode {
  Blend
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  Add
  Difference
  Exclusion
  HardLight
  SoftLight
  Dodge
  Burn
}

///|
pub extend FontSpec with Eq::{not_equal, equal}

///|
pub extend TextMetrics with Eq::{not_equal, equal}

///|
pub extend HAlign with Eq::{not_equal, equal}

///|
pub extend VAlign with Eq::{not_equal, equal}

///|
pub extend TextStyle with Eq::{not_equal, equal}

///|
pub extend TextWrap with Eq::{not_equal, equal}

///|
pub extend StrokeCap with Eq::{not_equal, equal}

///|
pub extend StrokeJoin with Eq::{not_equal, equal}

///|
pub extend BlendMode with Eq::{not_equal, equal}

///|
/// One active pointer contact. MoUI exposes pointer stream identity and
/// normalized pressure; p5-style touches use the same id for the lifetime of a
/// contact. `win_x`/`win_y` are canvas-local in this adapter (MoUI input is
/// already local to the hit element).
#derive(Eq)
pub(all) struct Touch {
  x : Double
  y : Double
  win_x : Double
  win_y : Double
  id : Int32
  /// Normalized `0.0..=1.0`; `1.0` means the host gave no pressure signal.
  pressure : Double
}

///|
pub fn Touch::new(
  x~ : Double,
  y~ : Double,
  id~ : Int32,
  pressure~ : Double = 1.0,
) -> Touch {
  let pressure = if pressure.is_nan() {
    1.0
  } else {
    pressure.max(0.0).min(1.0)
  }
  { x, y, win_x: x, win_y: y, id, pressure, }
}

///|
pub extend Touch with Eq::{not_equal, equal}

///|
/// CPU image filters, mirroring p5's `filter()` constants.
#derive(Eq)
pub(all) enum Filter {
  Threshold(Double)
  Gray
  Opaque
  Invert
  Posterize(Int32)
  Blur(Double)
  Erode
  Dilate
}

///|
pub extend Filter with Eq::{not_equal, equal}
