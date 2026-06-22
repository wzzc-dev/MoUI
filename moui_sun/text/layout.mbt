///|
/// Layout metrics for text
pub struct LayoutMetrics {
  width : Double
  height : Double
  baseline : Double
} derive(Eq, Debug)

///|
/// Create layout metrics
pub fn LayoutMetrics::new(
  width~ : Double,
  height~ : Double,
  baseline~ : Double,
) -> LayoutMetrics {
  { width, height, baseline }
}

///|
/// Text alignment.
pub(all) enum TextAlign {
  Left
  Center
  Right
  Justify
} derive(Eq, Debug)

///|
/// Text layout configuration
pub struct LayoutConfig {
  max_width : Double
  font_size : Double
  line_height : Double
  alignment : TextAlign
  letter_spacing : Double
  word_spacing : Double
} derive(Debug)

///|
/// Create a layout config with default values
pub fn LayoutConfig::new(
  max_width? : Double = 800.0,
  font_size? : Double = 16.0,
  line_height? : Double = 24.0,
  alignment? : TextAlign = TextAlign::Left,
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
) -> LayoutConfig {
  { max_width, font_size, line_height, alignment, letter_spacing, word_spacing }
}

///|
/// A positioned glyph for rendering
struct PositionedGlyph {
  glyph_id : Int
  origin_x : Double
  x : Double
  y : Double
  advance_width : Double
} derive(Debug)

///|
/// Get this positioned glyph's glyph id.
pub fn PositionedGlyph::get_glyph_id(self : PositionedGlyph) -> Int {
  self.glyph_id
}

///|
/// Get this positioned glyph's x position in pixels.
pub fn PositionedGlyph::get_x(self : PositionedGlyph) -> Double {
  self.x
}

///|
/// Get this positioned glyph's y position in pixels.
pub fn PositionedGlyph::get_y(self : PositionedGlyph) -> Double {
  self.y
}

///|
/// Get this positioned glyph's advance width in pixels.
pub fn PositionedGlyph::get_advance_width(self : PositionedGlyph) -> Double {
  self.advance_width
}

///|
/// A line of positioned glyphs
struct LayoutLine {
  glyphs : Array[PositionedGlyph]
  width : Double
  y : Double
} derive(Debug)

///|
/// Layout result containing positioned glyphs
struct LayoutResult {
  lines : Array[LayoutLine]
  total_width : Double
  total_height : Double
} derive(Debug)

///|
priv enum LayoutToken {
  Text(String)
  LineBreak
}

///|
priv struct LayoutLineEntry {
  line : LayoutLine
  should_justify : Bool
}

///|
/// Layout text using the font's actual metrics
fn layout_text(
  font : Font,
  text : String,
  config : LayoutConfig,
) -> LayoutResult {
  let line_entries = []
  let units_per_em = font.get_units_per_em().to_double()
  let scale = config.font_size / units_per_em
  let (ascent, descent, _) = font.get_metrics()
  let line_height = config.line_height

  // Word wrap: break text into lines that fit within max_width.
  let tokens = split_layout_tokens(text)
  let mut current_line_glyphs = []
  let mut current_line_width = 0.0
  let mut current_y = ascent.to_double() * scale
  let mut has_visible_line = false

  for token in tokens {
    match token {
      LayoutToken::LineBreak => {
        line_entries.push(
          make_layout_line_entry(
            current_line_glyphs,
            current_line_width,
            current_y,
            should_justify=false,
          ),
        )
        current_line_glyphs = []
        current_line_width = 0.0
        current_y = current_y + line_height
        has_visible_line = true
      }
      LayoutToken::Text(word) => {
        // Calculate word width
        let word_width = calculate_word_width(font, word, scale, config)
        let is_space = is_space_token(word)

        // Check if word fits on current line
        let needs_break = current_line_glyphs.length() > 0 &&
          !is_space &&
          current_line_width + word_width > config.max_width

        if needs_break {
          line_entries.push(
            make_layout_line_entry(
              current_line_glyphs,
              current_line_width,
              current_y,
              should_justify=true,
            ),
          )
          current_line_glyphs = []
          current_line_width = 0.0
          current_y = current_y + line_height
          has_visible_line = true
        }

        // Add word glyphs to current line
        let word_glyphs = shape_word(
          font, word, scale, current_line_width, config,
        )
        for g in word_glyphs {
          current_line_glyphs.push(g)
        }
        current_line_width = current_line_width + word_width
        has_visible_line = true
      }
    }
  }

  // Add final line
  if current_line_glyphs.length() > 0 || has_visible_line {
    line_entries.push(
      make_layout_line_entry(
        current_line_glyphs,
        current_line_width,
        current_y,
        should_justify=false,
      ),
    )
  }

  let aligned_lines = align_layout_lines(font, line_entries, config)

  // Calculate total dimensions
  let mut total_width = 0.0
  for line in aligned_lines {
    if line.width > total_width {
      total_width = line.width
    }
  }
  let total_height = if aligned_lines.length() > 0 {
    current_y + descent.to_double() * scale
  } else {
    0.0
  }

  { lines: aligned_lines, total_width, total_height }
}

///|
fn make_layout_line_entry(
  glyphs : Array[PositionedGlyph],
  width : Double,
  y : Double,
  should_justify~ : Bool,
) -> LayoutLineEntry {
  { line: { glyphs, width, y }, should_justify }
}

///|
fn align_layout_lines(
  font : Font,
  lines : Array[LayoutLineEntry],
  config : LayoutConfig,
) -> Array[LayoutLine] {
  let aligned = []
  for i in 0..<lines.length() {
    let entry = lines[i]
    aligned.push(
      align_layout_line(
        font,
        entry.line,
        config,
        should_justify=entry.should_justify,
      ),
    )
  }
  aligned
}

///|
fn align_layout_line(
  font : Font,
  line : LayoutLine,
  config : LayoutConfig,
  should_justify~ : Bool,
) -> LayoutLine {
  match config.alignment {
    TextAlign::Left => line
    TextAlign::Center =>
      shift_layout_line(line, alignment_extra(line, config) / 2.0)
    TextAlign::Right => shift_layout_line(line, alignment_extra(line, config))
    TextAlign::Justify =>
      if should_justify {
        justify_layout_line(font, line, config)
      } else {
        line
      }
  }
}

///|
fn alignment_extra(line : LayoutLine, config : LayoutConfig) -> Double {
  let extra = config.max_width - line.width
  if extra > 0.0 {
    extra
  } else {
    0.0
  }
}

///|
fn shift_layout_line(line : LayoutLine, offset : Double) -> LayoutLine {
  guard offset != 0.0 else { return line }
  let glyphs = []
  for glyph in line.glyphs {
    glyphs.push({
      glyph_id: glyph.glyph_id,
      origin_x: glyph.origin_x + offset,
      x: glyph.x + offset,
      y: glyph.y,
      advance_width: glyph.advance_width,
    })
  }
  { glyphs, width: line.width, y: line.y }
}

///|
fn justify_layout_line(
  font : Font,
  line : LayoutLine,
  config : LayoutConfig,
) -> LayoutLine {
  let extra = alignment_extra(line, config)
  guard extra > 0.0 else { return line }
  let space_glyph_id = font.char_to_glyph(' '.to_int())
  let mut space_count = 0
  for i in 0..<line.glyphs.length() {
    if is_justifiable_space(line.glyphs, i, space_glyph_id) {
      space_count = space_count + 1
    }
  }
  guard space_count > 0 else { return line }

  let extra_per_space = extra / space_count.to_double()
  let glyphs = []
  let mut shift = 0.0
  for i in 0..<line.glyphs.length() {
    let glyph = line.glyphs[i]
    let is_space = is_justifiable_space(line.glyphs, i, space_glyph_id)
    glyphs.push({
      glyph_id: glyph.glyph_id,
      origin_x: glyph.origin_x + shift,
      x: glyph.x + shift,
      y: glyph.y,
      advance_width: if is_space {
        glyph.advance_width + extra_per_space
      } else {
        glyph.advance_width
      },
    })
    if is_space {
      shift = shift + extra_per_space
    }
  }
  { glyphs, width: config.max_width, y: line.y }
}

///|
fn is_justifiable_space(
  glyphs : Array[PositionedGlyph],
  index : Int,
  space_glyph_id : Int,
) -> Bool {
  guard glyphs[index].glyph_id == space_glyph_id else { return false }
  has_non_space_before(glyphs, index, space_glyph_id) &&
  has_non_space_after(glyphs, index, space_glyph_id)
}

///|
fn has_non_space_before(
  glyphs : Array[PositionedGlyph],
  index : Int,
  space_glyph_id : Int,
) -> Bool {
  let mut i = index - 1
  while i >= 0 {
    if glyphs[i].glyph_id != space_glyph_id {
      return true
    }
    i = i - 1
  }
  false
}

///|
fn has_non_space_after(
  glyphs : Array[PositionedGlyph],
  index : Int,
  space_glyph_id : Int,
) -> Bool {
  let mut i = index + 1
  while i < glyphs.length() {
    if glyphs[i].glyph_id != space_glyph_id {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Split text into layout tokens, preserving spaces and explicit newlines.
fn split_layout_tokens(text : String) -> Array[LayoutToken] {
  let tokens = []
  let mut current_word = ""
  let mut current_word_class = None
  let mut i = 0
  let len = text.length()

  while i < len {
    let ch = text.get_char(i)
    match ch {
      Some(c) =>
        if c is '\n' || c is '\r' {
          // End current word
          if current_word.length() > 0 {
            tokens.push(LayoutToken::Text(current_word))
            current_word = ""
            current_word_class = None
          }
          tokens.push(LayoutToken::LineBreak)
          if c is '\r' {
            match text.get_char(i + 1) {
              Some('\n') => i = i + 1
              _ => ()
            }
          }
        } else if c is ' ' || c is '\t' {
          // End current word
          if current_word.length() > 0 {
            tokens.push(LayoutToken::Text(current_word))
            current_word = ""
            current_word_class = None
          }
          // Add space as separate word
          if c is ' ' {
            tokens.push(LayoutToken::Text(" "))
          }
        } else {
          let curr_class = get_line_break_class(c.to_int())
          match current_word_class {
            Some(prev_class) =>
              if should_split_unspaced_layout_token(prev_class, curr_class) {
                tokens.push(LayoutToken::Text(current_word))
                current_word = ""
                current_word_class = None
              }
            None => ()
          }
          current_word = current_word + c.to_string()
          current_word_class = Some(curr_class)
        }
      None => ignore(0)
    }
    i = i + 1
  }

  // Add final word
  if current_word.length() > 0 {
    tokens.push(LayoutToken::Text(current_word))
  }

  tokens
}

///|
fn should_split_unspaced_layout_token(
  prev_class : LineBreakClass,
  curr_class : LineBreakClass,
) -> Bool {
  is_line_break_allowed(prev_class, curr_class) &&
  can_start_unspaced_layout_token(curr_class) &&
  (
    is_unspaced_layout_break_class(prev_class) ||
    is_unspaced_layout_break_class(curr_class)
  )
}

///|
fn can_start_unspaced_layout_token(class : LineBreakClass) -> Bool {
  match class {
    LineBreakClass::CL => false
    LineBreakClass::CP => false
    LineBreakClass::EX => false
    LineBreakClass::IS => false
    LineBreakClass::SY => false
    LineBreakClass::NS => false
    _ => true
  }
}

///|
fn is_unspaced_layout_break_class(class : LineBreakClass) -> Bool {
  match class {
    LineBreakClass::ID => true
    LineBreakClass::H2 => true
    LineBreakClass::H3 => true
    LineBreakClass::JL => true
    LineBreakClass::JV => true
    LineBreakClass::JT => true
    _ => false
  }
}

///|
/// Calculate the width of a word using font metrics with kerning
fn calculate_word_width(
  font : Font,
  word : String,
  scale : Double,
  config : LayoutConfig,
) -> Double {
  let mut width = 0.0
  let mut prev_glyph_id = -1
  let mut glyph_count = 0

  for ch in word {
    let char_code = ch.to_int()
    let glyph_id = font.char_to_glyph(char_code)
    let (advance, _) = font.get_h_metrics(glyph_id)

    // Apply kerning
    if prev_glyph_id >= 0 {
      let kern = font.get_kerning(prev_glyph_id, glyph_id)
      width = width + kern.to_double() * scale
    }

    width = width + advance.to_double() * scale
    prev_glyph_id = glyph_id
    glyph_count = glyph_count + 1
  }

  if glyph_count > 1 {
    width = width + config.letter_spacing * (glyph_count - 1).to_double()
  }
  if is_space_token(word) {
    width = width + config.word_spacing
  }

  width
}

///|
/// Shape a word into positioned glyphs with kerning
fn shape_word(
  font : Font,
  word : String,
  scale : Double,
  start_x : Double,
  config : LayoutConfig,
) -> Array[PositionedGlyph] {
  let glyphs = []
  let mut cursor_x = start_x
  let mut prev_glyph_id = -1
  let mut glyph_index = 0
  let glyph_count = count_glyphs(word)
  let is_space = is_space_token(word)

  for ch in word {
    let char_code = ch.to_int()
    let glyph_id = font.char_to_glyph(char_code)
    let (advance, lsb) = font.get_h_metrics(glyph_id)
    let mut advance_width = advance.to_double() * scale
    if is_space {
      advance_width = advance_width + config.word_spacing
    } else if glyph_index < glyph_count - 1 {
      advance_width = advance_width + config.letter_spacing
    }

    // Apply kerning
    if prev_glyph_id >= 0 {
      let kern = font.get_kerning(prev_glyph_id, glyph_id)
      cursor_x = cursor_x + kern.to_double() * scale
    }

    glyphs.push({
      glyph_id,
      origin_x: cursor_x,
      x: cursor_x + lsb.to_double() * scale,
      y: 0.0, // Will be set by line layout
      advance_width,
    })

    cursor_x = cursor_x + advance_width
    prev_glyph_id = glyph_id
    glyph_index = glyph_index + 1
  }

  glyphs
}

///|
fn is_space_token(word : String) -> Bool {
  word.length() is 1 && word.get_char(0) == Some(' ')
}

///|
fn count_glyphs(word : String) -> Int {
  let mut count = 0
  for _ in word {
    count = count + 1
  }
  count
}
