///|
/// Text direction
pub enum TextDirection {
  LeftToRight
  RightToLeft
} derive(Eq, Debug)

///|
/// Left-to-right text direction.
pub fn TextDirection::left_to_right() -> TextDirection {
  TextDirection::LeftToRight
}

///|
/// Right-to-left text direction.
pub fn TextDirection::right_to_left() -> TextDirection {
  TextDirection::RightToLeft
}

///|
/// Text script (ISO 15924 code)
struct Script {
  tag : String
} derive(Eq, Debug)

///|
/// Common scripts
pub fn Script::latin() -> Script {
  { tag: "Latn" }
}

///|
pub fn Script::cyrillic() -> Script {
  { tag: "Cyrl" }
}

///|
pub fn Script::cjk() -> Script {
  { tag: "Hani" }
}

///|
/// Get the ISO 15924 script tag.
pub fn Script::get_tag(self : Script) -> String {
  self.tag
}

///|
/// Shaping buffer for text layout
struct ShapingBuffer {
  text : String
  direction : TextDirection
  script : Script
  font_size : Double
} derive(Debug)

///|
/// Create a new shaping buffer
pub fn ShapingBuffer::new(
  text : String,
  direction? : TextDirection = TextDirection::LeftToRight,
  script? : Script = Script::latin(),
  font_size? : Double = 16.0,
) -> ShapingBuffer {
  { text, direction, script, font_size }
}

///|
/// Get the text being shaped.
pub fn ShapingBuffer::get_text(self : ShapingBuffer) -> String {
  self.text
}

///|
/// Get the shaping direction.
pub fn ShapingBuffer::get_direction(self : ShapingBuffer) -> TextDirection {
  self.direction
}

///|
/// Get the shaping script.
pub fn ShapingBuffer::get_script(self : ShapingBuffer) -> Script {
  self.script
}

///|
/// Get the requested shaping font size.
pub fn ShapingBuffer::get_font_size(self : ShapingBuffer) -> Double {
  self.font_size
}

///|
/// Shape text into glyphs (simplified implementation)
/// In a real implementation, this would use the font data to perform OpenType shaping
pub fn ShapingBuffer::shape(
  self : ShapingBuffer,
  _font : FontData,
) -> ShapedText {
  let len = self.text.length()
  let glyphs = []
  let positions = []
  let mut total_width = 0

  for i in 0..<len {
    let cluster = match self.direction {
      TextDirection::LeftToRight => i
      TextDirection::RightToLeft => len - i - 1
    }
    let glyph_id = GlyphId::new(cluster)
    let char_width = (self.font_size * 0.6).to_int()

    glyphs.push(GlyphInfo::new(glyph_id~, cluster~))
    positions.push(
      GlyphPosition::new(
        glyph_id~,
        x_advance=char_width,
        y_advance=0,
        x_offset=0,
        y_offset=0,
      ),
    )
    total_width = total_width + char_width
  }

  { glyphs, positions, width: total_width }
}
