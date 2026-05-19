///|
pub(all) struct TextLayoutInput {
  text : String
  font : FontSpec
  max_width : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextLayoutResult {
  size : Size
  baseline : Double
  caret_positions : Array[Double]
} derive(Eq, Debug, ToJson)

///|
pub fn TextLayoutInput::new(
  text~ : String,
  font~ : FontSpec,
  max_width? : Double,
) -> TextLayoutInput {
  { text, font, max_width }
}

///|
pub fn measure_text_layout(input : TextLayoutInput) -> TextLayoutResult {
  let advances = text_layout_advances(input.text, input.font)
  let mut raw_width = 0.0
  for advance in advances {
    raw_width = raw_width + advance
  }
  let width = match input.max_width {
    Some(max_width) => min_double(raw_width, max_width)
    None => raw_width
  }
  let carets : Array[Double] = []
  carets.push(0.0)
  let mut cursor = 0.0
  for advance in advances {
    cursor = cursor + advance
    carets.push(min_double(cursor, width))
  }
  {
    size: Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn text_layout_advances(text : String, font : FontSpec) -> Array[Double] {
  let advances : Array[Double] = []
  for ch in text {
    advances.push(text_layout_codepoint_advance(font, ch.to_uint()))
  }
  advances
}

///|
pub fn text_layout_codepoint_advance(
  font : FontSpec,
  codepoint : UInt,
) -> Double {
  font.size *
  text_layout_advance_em(codepoint) *
  text_layout_font_width_factor(font)
}

///|
fn text_layout_advance_em(codepoint : UInt) -> Double {
  if is_zero_width_text_codepoint(codepoint) {
    0.0
  } else if is_fullwidth_text_codepoint(codepoint) {
    1.0
  } else if is_ascii_digit_text_codepoint(codepoint) {
    0.58
  } else if codepoint == 0x20U {
    0.33
  } else if is_ascii_narrow_uppercase_text_codepoint(codepoint) {
    0.34
  } else if is_ascii_wide_uppercase_text_codepoint(codepoint) {
    0.9
  } else if is_ascii_uppercase_text_codepoint(codepoint) {
    0.67
  } else if is_ascii_narrow_lowercase_text_codepoint(codepoint) {
    0.3
  } else if is_ascii_slim_lowercase_text_codepoint(codepoint) {
    0.4
  } else if is_ascii_wide_lowercase_text_codepoint(codepoint) {
    0.82
  } else if is_ascii_lowercase_text_codepoint(codepoint) {
    0.55
  } else if is_ascii_narrow_punctuation_text_codepoint(codepoint) {
    0.3
  } else if is_ascii_punctuation_text_codepoint(codepoint) {
    0.4
  } else {
    0.6
  }
}

///|
fn text_layout_font_width_factor(font : FontSpec) -> Double {
  let mut factor = 1.0
  if font.weight >= 700 {
    factor = factor * 1.08
  } else if font.weight >= 600 {
    factor = factor * 1.04
  }
  if font.family.contains("monospace") ||
    font.family.contains("Mono") ||
    font.family.contains("Menlo") ||
    font.family.contains("Consolas") {
    factor = factor * 1.1
  }
  factor
}

///|
fn is_zero_width_text_codepoint(codepoint : UInt) -> Bool {
  is_codepoint_in_range(codepoint, 0x0300U, 0x036FU) ||
  is_codepoint_in_range(codepoint, 0x1AB0U, 0x1AFFU) ||
  is_codepoint_in_range(codepoint, 0x1DC0U, 0x1DFFU) ||
  is_codepoint_in_range(codepoint, 0x20D0U, 0x20FFU) ||
  is_codepoint_in_range(codepoint, 0xFE20U, 0xFE2FU)
}

///|
fn is_ascii_digit_text_codepoint(codepoint : UInt) -> Bool {
  is_codepoint_in_range(codepoint, 0x30U, 0x39U)
}

///|
fn is_ascii_uppercase_text_codepoint(codepoint : UInt) -> Bool {
  is_codepoint_in_range(codepoint, 0x41U, 0x5AU)
}

///|
fn is_ascii_lowercase_text_codepoint(codepoint : UInt) -> Bool {
  is_codepoint_in_range(codepoint, 0x61U, 0x7AU)
}

///|
fn is_ascii_narrow_uppercase_text_codepoint(codepoint : UInt) -> Bool {
  codepoint == 0x49U // I
}

///|
fn is_ascii_wide_uppercase_text_codepoint(codepoint : UInt) -> Bool {
  codepoint == 0x4DU || codepoint == 0x57U // M W
}

///|
fn is_ascii_narrow_lowercase_text_codepoint(codepoint : UInt) -> Bool {
  codepoint == 0x69U || codepoint == 0x6AU || codepoint == 0x6CU // i j l
}

///|
fn is_ascii_slim_lowercase_text_codepoint(codepoint : UInt) -> Bool {
  codepoint == 0x66U || codepoint == 0x72U || codepoint == 0x74U // f r t
}

///|
fn is_ascii_wide_lowercase_text_codepoint(codepoint : UInt) -> Bool {
  codepoint == 0x6DU || codepoint == 0x77U // m w
}

///|
fn is_ascii_narrow_punctuation_text_codepoint(codepoint : UInt) -> Bool {
  codepoint == 0x21U || // !
  codepoint == 0x2CU || // ,
  codepoint == 0x2EU || // .
  codepoint == 0x3AU || // :
  codepoint == 0x3BU || // ;
  codepoint == 0x7CU // |
}

///|
fn is_ascii_punctuation_text_codepoint(codepoint : UInt) -> Bool {
  is_codepoint_in_range(codepoint, 0x21U, 0x2FU) ||
  is_codepoint_in_range(codepoint, 0x3AU, 0x40U) ||
  is_codepoint_in_range(codepoint, 0x5BU, 0x60U) ||
  is_codepoint_in_range(codepoint, 0x7BU, 0x7EU)
}

///|
fn is_fullwidth_text_codepoint(codepoint : UInt) -> Bool {
  is_codepoint_in_range(codepoint, 0x1100U, 0x115FU) ||
  is_codepoint_in_range(codepoint, 0x2329U, 0x232AU) ||
  is_codepoint_in_range(codepoint, 0x2E80U, 0xA4CFU) ||
  is_codepoint_in_range(codepoint, 0xAC00U, 0xD7A3U) ||
  is_codepoint_in_range(codepoint, 0xF900U, 0xFAFFU) ||
  is_codepoint_in_range(codepoint, 0xFE10U, 0xFE19U) ||
  is_codepoint_in_range(codepoint, 0xFE30U, 0xFE6FU) ||
  is_codepoint_in_range(codepoint, 0xFF00U, 0xFF60U) ||
  is_codepoint_in_range(codepoint, 0xFFE0U, 0xFFE6U)
}

///|
fn is_codepoint_in_range(codepoint : UInt, start : UInt, end : UInt) -> Bool {
  codepoint >= start && codepoint <= end
}
