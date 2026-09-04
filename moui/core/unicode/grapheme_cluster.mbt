///| A lightweight half-open codepoint range `[start, end)` used by the

///| grapheme boundary API. It mirrors `@core.TextRange` but keeps this

///|
/// package free of any core dependency.
pub(all) struct GraphemeRange {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub fn GraphemeRange::new(start~ : Int, end~ : Int) -> GraphemeRange {
  { start, end }
}

///|
pub fn GraphemeRange::collapsed(index : Int) -> GraphemeRange {
  { start: index, end: index }
}

///|
pub fn GraphemeRange::normalized(self : GraphemeRange) -> GraphemeRange {
  if self.start <= self.end {
    self
  } else {
    { start: self.end, end: self.start }
  }
}

///|
pub fn GraphemeRange::is_collapsed(self : GraphemeRange) -> Bool {
  self.start == self.end
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
pub struct TextGraphemeBoundaries {
  priv text : String
  priv boundaries : Array[Int]
} derive(Eq, Debug)

///|
/// All-ASCII text has a trivial grapheme segmentation: every codepoint is
/// its own cluster except the LF of a CR-LF pair. Scanning the text once
/// with a non-allocating char iterator yields boundaries identical to the
/// general fallback walk, so keystrokes in ASCII documents never pay the
/// per-pair cluster-rule evaluation and char-array copy. Returns None as
/// soon as a non-ASCII codepoint appears, falling back to the general path.
fn ascii_grapheme_boundaries(text : String) -> Array[Int]? {
  let boundaries : Array[Int] = [0]
  let mut index = 0
  let mut last_was_cr = false
  for ch in text {
    if ch.to_int() >= 128 {
      return None
    }
    let is_lf = ch == '\n'
    if index > 0 && !(last_was_cr && is_lf) {
      boundaries.push(index)
    }
    last_was_cr = ch == '\r'
    index = index + 1
  }
  if index > 0 {
    boundaries.push(index)
  }
  Some(boundaries)
}

///|
pub fn TextGraphemeBoundaries::new(text~ : String) -> TextGraphemeBoundaries {
  match ascii_grapheme_boundaries(text) {
    Some(boundaries) => return { text, boundaries }
    None => ()
  }
  let chars = text.to_array()
  let boundaries : Array[Int] = [0]
  let mut index = 1
  let mut last_boundary = 0
  while index < chars.length() {
    if fallback_grapheme_should_break(chars, last_boundary, index) {
      boundaries.push(index)
      last_boundary = index
    }
    index = index + 1
  }
  if chars.length() > 0 {
    boundaries.push(chars.length())
  }
  { text, boundaries }
}

///|
pub fn TextGraphemeBoundaries::text(self : TextGraphemeBoundaries) -> String {
  self.text
}

///|
pub fn TextGraphemeBoundaries::boundaries(
  self : TextGraphemeBoundaries,
) -> Array[Int] {
  self.boundaries.copy()
}

///|
pub fn TextGraphemeBoundaries::length(self : TextGraphemeBoundaries) -> Int {
  match self.boundaries.last() {
    Some(length) => length
    None => 0
  }
}

///|
pub fn TextGraphemeBoundaries::cluster_count(
  self : TextGraphemeBoundaries,
) -> Int {
  max_int(0, self.boundaries.length() - 1)
}

///|
pub fn TextGraphemeBoundaries::is_boundary(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Bool {
  let index = self.clamp_index(index)
  self.boundaries.any(boundary => boundary == index)
}

///|
pub fn TextGraphemeBoundaries::clamp_index(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Int {
  clamp_int(index, 0, self.length())
}

///|
pub fn TextGraphemeBoundaries::previous_boundary(
  self : TextGraphemeBoundaries,
  caret : Int,
) -> Int {
  let caret = self.clamp_index(caret)
  if caret <= 0 {
    return 0
  }
  let mut previous = 0
  for boundary in self.boundaries {
    if boundary >= caret {
      return previous
    }
    previous = boundary
  }
  previous
}

///|
pub fn TextGraphemeBoundaries::next_boundary(
  self : TextGraphemeBoundaries,
  caret : Int,
) -> Int {
  let caret = self.clamp_index(caret)
  let length = self.length()
  if caret >= length {
    return length
  }
  for boundary in self.boundaries {
    if boundary > caret {
      return boundary
    }
  }
  length
}

///|
pub fn TextGraphemeBoundaries::floor_boundary(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Int {
  let index = self.clamp_index(index)
  let mut floor = 0
  for boundary in self.boundaries {
    if boundary > index {
      return floor
    }
    floor = boundary
  }
  floor
}

///|
pub fn TextGraphemeBoundaries::ceil_boundary(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Int {
  let index = self.clamp_index(index)
  for boundary in self.boundaries {
    if boundary >= index {
      return boundary
    }
  }
  self.length()
}

///|
pub fn TextGraphemeBoundaries::nearest_boundary(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Int {
  let index = self.clamp_index(index)
  let floor = self.floor_boundary(index)
  let ceil = self.ceil_boundary(index)
  if index - floor <= ceil - index {
    floor
  } else {
    ceil
  }
}

///|
pub fn TextGraphemeBoundaries::normalize_range(
  self : TextGraphemeBoundaries,
  range : GraphemeRange,
) -> GraphemeRange {
  let normalized = range.normalized()
  if normalized.is_collapsed() {
    GraphemeRange::collapsed(self.nearest_boundary(normalized.start))
  } else {
    GraphemeRange::new(
      start=self.floor_boundary(normalized.start),
      end=self.ceil_boundary(normalized.end),
    )
  }
}

///|
pub fn TextGraphemeBoundaries::delete_range(
  self : TextGraphemeBoundaries,
  caret : Int,
  before : Int,
  after : Int,
) -> GraphemeRange {
  let mut start = self.nearest_boundary(caret)
  let mut end = start
  for _ in 0..<max_int(0, before) {
    start = self.previous_boundary(start)
  }
  for _ in 0..<max_int(0, after) {
    end = self.next_boundary(end)
  }
  GraphemeRange::new(start~, end~)
}

///|
pub fn TextGraphemeBoundaries::utf8_offset(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Int {
  let chars = self.text.to_array()
  let index = self.clamp_index(index)
  @utf8.encode(String::from_array(chars[:index])[:], bom=false).length()
}

///|
pub fn TextGraphemeBoundaries::nearest_boundary_utf8_offset(
  self : TextGraphemeBoundaries,
  index : Int,
) -> Int {
  self.utf8_offset(self.nearest_boundary(index))
}

///|
pub fn stabilize_grapheme_cluster_carets(
  text : String,
  carets : Array[Double],
) -> Array[Double] {
  let chars = text.to_array()
  if carets.length() != chars.length() + 1 {
    return carets
  }
  let adjusted = carets.copy()
  let boundaries = TextGraphemeBoundaries::new(text~).boundaries()
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    if end > start + 1 {
      stabilize_caret_cluster(adjusted, start, end)
    }
  }
  adjusted
}

///|
fn fallback_grapheme_should_break(
  chars : Array[Char],
  last_boundary : Int,
  index : Int,
) -> Bool {
  if index <= 0 || index >= chars.length() {
    return true
  }
  let left = chars[index - 1].to_int()
  let right = chars[index].to_int()
  if fallback_codepoint_is_cr(left) && fallback_codepoint_is_lf(right) {
    return false
  }
  if fallback_codepoint_is_grapheme_break_control(left) ||
    fallback_codepoint_is_grapheme_break_control(right) {
    return true
  }
  if fallback_hangul_allows_no_break(left, right) {
    return false
  }
  if fallback_codepoint_is_grapheme_extend(right) ||
    fallback_codepoint_is_zwj(right) {
    return false
  }
  if fallback_codepoint_is_spacing_mark(right) {
    return false
  }
  if fallback_codepoint_is_grapheme_prepend(left) {
    return false
  }
  if fallback_indic_conjunct_allows_no_break(chars, index) {
    return false
  }
  if fallback_emoji_zwj_allows_no_break(chars, index) {
    return false
  }
  if fallback_codepoint_is_regional_indicator(left) &&
    fallback_codepoint_is_regional_indicator(right) {
    let ri_count = fallback_regional_indicator_count_before(
      chars, last_boundary, index,
    )
    return ri_count % 2 == 0
  }
  true
}

///|
fn stabilize_caret_cluster(
  carets : Array[Double],
  start : Int,
  end : Int,
) -> Unit {
  if start < 0 || end <= start + 1 || end >= carets.length() {
    return ()
  }
  let cluster_start = carets[start]
  for caret_index in (start + 1)..<end {
    carets[caret_index] = cluster_start
  }
  if carets[end] < cluster_start {
    carets[end] = cluster_start
  }
}

///|
pub fn previous_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  TextGraphemeBoundaries::new(text~).previous_boundary(caret)
}

///|
pub fn next_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  TextGraphemeBoundaries::new(text~).next_boundary(caret)
}

///|
fn fallback_codepoint_is_cr(codepoint : Int) -> Bool {
  unicode_grapheme_is_cr_17_0(codepoint)
}

///|
fn fallback_codepoint_is_lf(codepoint : Int) -> Bool {
  unicode_grapheme_is_lf_17_0(codepoint)
}

///|
fn fallback_codepoint_is_grapheme_break_control(codepoint : Int) -> Bool {
  fallback_codepoint_is_cr(codepoint) ||
  fallback_codepoint_is_lf(codepoint) ||
  unicode_grapheme_is_control_17_0(codepoint)
}

///|
fn fallback_codepoint_is_zwj(codepoint : Int) -> Bool {
  unicode_grapheme_is_zwj_17_0(codepoint)
}

///|
fn fallback_hangul_allows_no_break(left : Int, right : Int) -> Bool {
  if fallback_codepoint_is_hangul_l(left) {
    return fallback_codepoint_is_hangul_l(right) ||
      fallback_codepoint_is_hangul_v(right) ||
      fallback_codepoint_is_hangul_lv(right) ||
      fallback_codepoint_is_hangul_lvt(right)
  }
  if fallback_codepoint_is_hangul_lv(left) ||
    fallback_codepoint_is_hangul_v(left) {
    return fallback_codepoint_is_hangul_v(right) ||
      fallback_codepoint_is_hangul_t(right)
  }
  if fallback_codepoint_is_hangul_lvt(left) ||
    fallback_codepoint_is_hangul_t(left) {
    return fallback_codepoint_is_hangul_t(right)
  }
  false
}

///|
fn fallback_indic_conjunct_allows_no_break(
  chars : Array[Char],
  index : Int,
) -> Bool {
  let right = chars[index].to_int()
  if !fallback_codepoint_is_indic_conjunct_consonant(right) {
    return false
  }
  let mut cursor = index - 1
  let mut saw_linker = false
  while cursor >= 0 {
    let codepoint = chars[cursor].to_int()
    if fallback_codepoint_is_indic_conjunct_linker(codepoint) {
      saw_linker = true
      if cursor == 0 {
        return false
      }
      cursor = cursor - 1
      continue
    }
    if fallback_codepoint_is_indic_conjunct_extend(codepoint) {
      if cursor == 0 {
        return false
      }
      cursor = cursor - 1
      continue
    }
    return saw_linker &&
      fallback_codepoint_is_indic_conjunct_consonant(codepoint)
  }
  false
}

///|
fn fallback_codepoint_is_indic_conjunct_linker(codepoint : Int) -> Bool {
  unicode_indic_conjunct_is_linker_17_0(codepoint)
}

///|
fn fallback_codepoint_is_indic_conjunct_consonant(codepoint : Int) -> Bool {
  unicode_indic_conjunct_is_consonant_17_0(codepoint)
}

///|
fn fallback_codepoint_is_indic_conjunct_extend(codepoint : Int) -> Bool {
  unicode_indic_conjunct_is_extend_17_0(codepoint)
}

///|
fn fallback_emoji_zwj_allows_no_break(chars : Array[Char], index : Int) -> Bool {
  if index <= 0 || !fallback_codepoint_is_zwj(chars[index - 1].to_int()) {
    return false
  }
  if !fallback_codepoint_is_extended_pictographic(chars[index].to_int()) {
    return false
  }
  let mut cursor = index - 2
  while cursor >= 0 &&
        fallback_codepoint_is_grapheme_extend(chars[cursor].to_int()) &&
        !fallback_codepoint_is_zwj(chars[cursor].to_int()) {
    if cursor == 0 {
      return fallback_codepoint_is_extended_pictographic(chars[cursor].to_int())
    }
    cursor = cursor - 1
  }
  cursor >= 0 &&
  fallback_codepoint_is_extended_pictographic(chars[cursor].to_int())
}

///|
fn fallback_regional_indicator_count_before(
  chars : Array[Char],
  last_boundary : Int,
  index : Int,
) -> Int {
  let mut count = 0
  let mut cursor = index - 1
  while cursor >= last_boundary &&
        fallback_codepoint_is_regional_indicator(chars[cursor].to_int()) {
    count = count + 1
    if cursor == 0 {
      return count
    }
    cursor = cursor - 1
  }
  count
}

///|
fn fallback_codepoint_is_grapheme_extend(codepoint : Int) -> Bool {
  unicode_grapheme_is_extend_17_0(codepoint)
}

///|
fn fallback_codepoint_is_grapheme_prepend(codepoint : Int) -> Bool {
  unicode_grapheme_is_prepend_17_0(codepoint)
}

///|
fn fallback_codepoint_is_spacing_mark(codepoint : Int) -> Bool {
  unicode_grapheme_is_spacing_mark_17_0(codepoint)
}

///|
fn fallback_codepoint_is_hangul_l(codepoint : Int) -> Bool {
  (codepoint >= 0x1100 && codepoint <= 0x115F) ||
  (codepoint >= 0xA960 && codepoint <= 0xA97C)
}

///|
fn fallback_codepoint_is_hangul_v(codepoint : Int) -> Bool {
  (codepoint >= 0x1160 && codepoint <= 0x11A7) ||
  (codepoint >= 0xD7B0 && codepoint <= 0xD7C6)
}

///|
fn fallback_codepoint_is_hangul_t(codepoint : Int) -> Bool {
  (codepoint >= 0x11A8 && codepoint <= 0x11FF) ||
  (codepoint >= 0xD7CB && codepoint <= 0xD7FB)
}

///|
fn fallback_codepoint_is_hangul_lv(codepoint : Int) -> Bool {
  fallback_codepoint_is_hangul_syllable(codepoint) &&
  (codepoint - 0xAC00) % 28 == 0
}

///|
fn fallback_codepoint_is_hangul_lvt(codepoint : Int) -> Bool {
  fallback_codepoint_is_hangul_syllable(codepoint) &&
  (codepoint - 0xAC00) % 28 != 0
}

///|
fn fallback_codepoint_is_hangul_syllable(codepoint : Int) -> Bool {
  codepoint >= 0xAC00 && codepoint <= 0xD7A3
}

///|
fn fallback_codepoint_is_extended_pictographic(codepoint : Int) -> Bool {
  unicode_emoji_is_extended_pictographic_17_0(codepoint)
}

///|
fn fallback_codepoint_is_regional_indicator(codepoint : Int) -> Bool {
  unicode_grapheme_is_regional_indicator_17_0(codepoint)
}
