///|
pub(all) struct TextGraphemeBoundaries {
  priv text : String
  priv boundaries : Array[Int]
} derive(Eq, Debug, ToJson)

///|
pub fn TextGraphemeBoundaries::new(text~ : String) -> TextGraphemeBoundaries {
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
  range : TextRange,
) -> TextRange {
  let normalized = range.normalized()
  if normalized.is_collapsed() {
    TextRange::collapsed(self.nearest_boundary(normalized.start))
  } else {
    TextRange::new(
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
) -> TextRange {
  let mut start = self.nearest_boundary(caret)
  let mut end = start
  for _ in 0..<max_int(0, before) {
    start = self.previous_boundary(start)
  }
  for _ in 0..<max_int(0, after) {
    end = self.next_boundary(end)
  }
  TextRange::new(start~, end~)
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
fn fallback_stabilize_grapheme_cluster_carets(
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
      fallback_stabilize_caret_cluster(adjusted, start, end)
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
  if fallback_indic_virama_allows_no_break(chars, index) {
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
fn fallback_stabilize_caret_cluster(
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
fn text_previous_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  TextGraphemeBoundaries::new(text~).previous_boundary(caret)
}

///|
fn text_next_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  TextGraphemeBoundaries::new(text~).next_boundary(caret)
}

///|
fn fallback_codepoint_is_cr(codepoint : Int) -> Bool {
  codepoint == 0x000D
}

///|
fn fallback_codepoint_is_lf(codepoint : Int) -> Bool {
  codepoint == 0x000A
}

///|
fn fallback_codepoint_is_grapheme_break_control(codepoint : Int) -> Bool {
  fallback_codepoint_is_cr(codepoint) ||
  fallback_codepoint_is_lf(codepoint) ||
  (codepoint >= 0x0000 && codepoint <= 0x0009) ||
  (codepoint >= 0x000B && codepoint <= 0x000C) ||
  (codepoint >= 0x000E && codepoint <= 0x001F) ||
  (codepoint >= 0x007F && codepoint <= 0x009F) ||
  codepoint == 0x00AD ||
  codepoint == 0x061C ||
  codepoint == 0x180E ||
  codepoint == 0x200B ||
  (codepoint >= 0x200E && codepoint <= 0x200F) ||
  (codepoint >= 0x2028 && codepoint <= 0x202E) ||
  (codepoint >= 0x2060 && codepoint <= 0x206F) ||
  codepoint == 0xFEFF ||
  (codepoint >= 0xFFF9 && codepoint <= 0xFFFB)
}

///|
fn fallback_codepoint_is_zwj(codepoint : Int) -> Bool {
  codepoint == 0x200D
}

///|
fn fallback_codepoint_is_zwnj(codepoint : Int) -> Bool {
  codepoint == 0x200C
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
fn fallback_indic_virama_allows_no_break(
  chars : Array[Char],
  index : Int,
) -> Bool {
  let left = chars[index - 1].to_int()
  let right = chars[index].to_int()
  if fallback_codepoint_is_virama(left) {
    return fallback_codepoint_is_zwj(right) ||
      fallback_codepoint_is_indic_consonant(right)
  }
  if !fallback_codepoint_is_indic_consonant(right) || index < 2 {
    return false
  }
  if fallback_codepoint_is_zwj(left) {
    return fallback_indic_virama_before_extend_run(chars, index - 2)
  }
  if fallback_codepoint_is_grapheme_extend(left) &&
    !fallback_codepoint_is_zwnj(left) {
    return fallback_indic_virama_before_extend_run(chars, index - 1)
  }
  false
}

///|
fn fallback_indic_virama_before_extend_run(
  chars : Array[Char],
  start : Int,
) -> Bool {
  let mut cursor = start
  while cursor >= 0 {
    let codepoint = chars[cursor].to_int()
    if fallback_codepoint_is_virama(codepoint) {
      return true
    }
    if fallback_codepoint_is_grapheme_extend(codepoint) &&
      !fallback_codepoint_is_zwj(codepoint) &&
      !fallback_codepoint_is_zwnj(codepoint) {
      if cursor == 0 {
        return false
      }
      cursor = cursor - 1
      continue
    }
    return false
  }
  false
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
fn fallback_codepoint_is_variation_selector(codepoint : Int) -> Bool {
  (codepoint >= 0xFE00 && codepoint <= 0xFE0F) ||
  (codepoint >= 0xE0100 && codepoint <= 0xE01EF)
}

///|
fn fallback_codepoint_is_grapheme_extend(codepoint : Int) -> Bool {
  codepoint == 0x200C ||
  fallback_codepoint_is_variation_selector(codepoint) ||
  fallback_codepoint_is_combining_mark(codepoint) ||
  fallback_codepoint_is_spacing_mark(codepoint) ||
  fallback_codepoint_is_emoji_modifier(codepoint) ||
  fallback_codepoint_is_emoji_tag(codepoint)
}

///|
fn fallback_codepoint_is_grapheme_prepend(codepoint : Int) -> Bool {
  (codepoint >= 0x0600 && codepoint <= 0x0605) ||
  codepoint == 0x06DD ||
  codepoint == 0x070F ||
  codepoint == 0x0890 ||
  codepoint == 0x0891 ||
  codepoint == 0x08E2 ||
  codepoint == 0x110BD ||
  codepoint == 0x110CD
}

///|
fn fallback_codepoint_is_combining_mark(codepoint : Int) -> Bool {
  (codepoint >= 0x0300 && codepoint <= 0x036F) ||
  (codepoint >= 0x0591 && codepoint <= 0x05BD) ||
  codepoint == 0x05BF ||
  (codepoint >= 0x05C1 && codepoint <= 0x05C2) ||
  (codepoint >= 0x05C4 && codepoint <= 0x05C5) ||
  codepoint == 0x05C7 ||
  (codepoint >= 0x0610 && codepoint <= 0x061A) ||
  (codepoint >= 0x064B && codepoint <= 0x065F) ||
  codepoint == 0x0670 ||
  (codepoint >= 0x06D6 && codepoint <= 0x06DC) ||
  (codepoint >= 0x06DF && codepoint <= 0x06E4) ||
  (codepoint >= 0x06E7 && codepoint <= 0x06E8) ||
  (codepoint >= 0x06EA && codepoint <= 0x06ED) ||
  codepoint == 0x0711 ||
  (codepoint >= 0x0730 && codepoint <= 0x074A) ||
  (codepoint >= 0x07A6 && codepoint <= 0x07B0) ||
  (codepoint >= 0x07EB && codepoint <= 0x07F3) ||
  (codepoint >= 0x0816 && codepoint <= 0x0819) ||
  (codepoint >= 0x081B && codepoint <= 0x0823) ||
  (codepoint >= 0x0825 && codepoint <= 0x0827) ||
  (codepoint >= 0x0829 && codepoint <= 0x082D) ||
  (codepoint >= 0x0859 && codepoint <= 0x085B) ||
  (codepoint >= 0x08D3 && codepoint <= 0x08FF) ||
  (codepoint >= 0x1AB0 && codepoint <= 0x1AFF) ||
  (codepoint >= 0x1DC0 && codepoint <= 0x1DFF) ||
  (codepoint >= 0x20D0 && codepoint <= 0x20FF) ||
  (codepoint >= 0x1D165 && codepoint <= 0x1D169) ||
  (codepoint >= 0x1D16D && codepoint <= 0x1D172) ||
  (codepoint >= 0x1D17B && codepoint <= 0x1D182) ||
  (codepoint >= 0x1D185 && codepoint <= 0x1D18B) ||
  (codepoint >= 0x1D1AA && codepoint <= 0x1D1AD) ||
  (codepoint >= 0x1D242 && codepoint <= 0x1D244) ||
  (codepoint >= 0x102B && codepoint <= 0x103E) ||
  (codepoint >= 0x1056 && codepoint <= 0x1059) ||
  (codepoint >= 0x105E && codepoint <= 0x1060) ||
  (codepoint >= 0x1062 && codepoint <= 0x1064) ||
  (codepoint >= 0x1067 && codepoint <= 0x106D) ||
  (codepoint >= 0x1071 && codepoint <= 0x1074) ||
  (codepoint >= 0x1082 && codepoint <= 0x108D) ||
  codepoint == 0x108F ||
  (codepoint >= 0x109A && codepoint <= 0x109D) ||
  (codepoint >= 0x3099 && codepoint <= 0x309A) ||
  (codepoint >= 0xFE20 && codepoint <= 0xFE2F)
}

///|
fn fallback_codepoint_is_spacing_mark(codepoint : Int) -> Bool {
  (codepoint >= 0x0900 && codepoint <= 0x0903) ||
  (codepoint >= 0x093A && codepoint <= 0x093C) ||
  (codepoint >= 0x093E && codepoint <= 0x094F) ||
  (codepoint >= 0x0951 && codepoint <= 0x0957) ||
  (codepoint >= 0x0962 && codepoint <= 0x0963) ||
  (codepoint >= 0x0981 && codepoint <= 0x0983) ||
  codepoint == 0x09BC ||
  (codepoint >= 0x09BE && codepoint <= 0x09C4) ||
  (codepoint >= 0x09C7 && codepoint <= 0x09C8) ||
  (codepoint >= 0x09CB && codepoint <= 0x09CD) ||
  codepoint == 0x09D7 ||
  (codepoint >= 0x09E2 && codepoint <= 0x09E3) ||
  (codepoint >= 0x0A01 && codepoint <= 0x0A03) ||
  codepoint == 0x0A3C ||
  (codepoint >= 0x0A3E && codepoint <= 0x0A42) ||
  (codepoint >= 0x0A47 && codepoint <= 0x0A48) ||
  (codepoint >= 0x0A4B && codepoint <= 0x0A4D) ||
  codepoint == 0x0A51 ||
  (codepoint >= 0x0A70 && codepoint <= 0x0A71) ||
  codepoint == 0x0A75 ||
  (codepoint >= 0x0B01 && codepoint <= 0x0B03) ||
  codepoint == 0x0B3C ||
  (codepoint >= 0x0B3E && codepoint <= 0x0B44) ||
  (codepoint >= 0x0B47 && codepoint <= 0x0B48) ||
  (codepoint >= 0x0B4B && codepoint <= 0x0B4D) ||
  (codepoint >= 0x0B55 && codepoint <= 0x0B57) ||
  (codepoint >= 0x0B62 && codepoint <= 0x0B63) ||
  (codepoint >= 0x0C00 && codepoint <= 0x0C04) ||
  (codepoint >= 0x0C3E && codepoint <= 0x0C44) ||
  (codepoint >= 0x0C46 && codepoint <= 0x0C48) ||
  (codepoint >= 0x0C4A && codepoint <= 0x0C4D) ||
  (codepoint >= 0x0C55 && codepoint <= 0x0C56) ||
  (codepoint >= 0x0C62 && codepoint <= 0x0C63) ||
  (codepoint >= 0x0D00 && codepoint <= 0x0D03) ||
  (codepoint >= 0x0D3B && codepoint <= 0x0D44) ||
  (codepoint >= 0x0D46 && codepoint <= 0x0D48) ||
  codepoint == 0x0DCA ||
  (codepoint >= 0x0D4A && codepoint <= 0x0D4D) ||
  (codepoint >= 0x0DCF && codepoint <= 0x0DD4) ||
  codepoint == 0x0DD6 ||
  (codepoint >= 0x0DD8 && codepoint <= 0x0DDF) ||
  codepoint == 0x0D57 ||
  (codepoint >= 0x0D62 && codepoint <= 0x0D63) ||
  codepoint == 0x0E31 ||
  (codepoint >= 0x0E34 && codepoint <= 0x0E3A) ||
  (codepoint >= 0x0E47 && codepoint <= 0x0E4E) ||
  codepoint == 0x0EB1 ||
  (codepoint >= 0x0EB4 && codepoint <= 0x0EBC) ||
  (codepoint >= 0x0EC8 && codepoint <= 0x0ECD) ||
  (codepoint >= 0x17B4 && codepoint <= 0x17D3) ||
  codepoint == 0x17DD
}

///|
fn fallback_codepoint_is_virama(codepoint : Int) -> Bool {
  codepoint == 0x094D ||
  codepoint == 0x09CD ||
  codepoint == 0x0A4D ||
  codepoint == 0x0ACD ||
  codepoint == 0x0B4D ||
  codepoint == 0x0BCD ||
  codepoint == 0x0C4D ||
  codepoint == 0x0CCD ||
  codepoint == 0x0D4D ||
  codepoint == 0x0DCA ||
  codepoint == 0x1039 ||
  codepoint == 0x17D2
}

///|
fn fallback_codepoint_is_indic_consonant(codepoint : Int) -> Bool {
  (codepoint >= 0x0915 && codepoint <= 0x0939) ||
  (codepoint >= 0x0958 && codepoint <= 0x095F) ||
  (codepoint >= 0x0978 && codepoint <= 0x097F) ||
  (codepoint >= 0x0995 && codepoint <= 0x09B9) ||
  (codepoint >= 0x09DC && codepoint <= 0x09DF) ||
  (codepoint >= 0x0A15 && codepoint <= 0x0A39) ||
  (codepoint >= 0x0A59 && codepoint <= 0x0A5E) ||
  (codepoint >= 0x0A95 && codepoint <= 0x0AB9) ||
  (codepoint >= 0x0B15 && codepoint <= 0x0B39) ||
  (codepoint >= 0x0B5C && codepoint <= 0x0B5F) ||
  (codepoint >= 0x0B95 && codepoint <= 0x0BB9) ||
  (codepoint >= 0x0C15 && codepoint <= 0x0C39) ||
  (codepoint >= 0x0C95 && codepoint <= 0x0CB9) ||
  (codepoint >= 0x0D15 && codepoint <= 0x0D3A) ||
  (codepoint >= 0x0D9A && codepoint <= 0x0DC6) ||
  (codepoint >= 0x1000 && codepoint <= 0x102A) ||
  (codepoint >= 0x1050 && codepoint <= 0x1055) ||
  (codepoint >= 0x1780 && codepoint <= 0x17A2)
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
fn fallback_codepoint_is_emoji_modifier(codepoint : Int) -> Bool {
  codepoint >= 0x1F3FB && codepoint <= 0x1F3FF
}

///|
fn fallback_codepoint_is_extended_pictographic(codepoint : Int) -> Bool {
  codepoint == 0x00A9 ||
  codepoint == 0x00AE ||
  codepoint == 0x203C ||
  codepoint == 0x2049 ||
  codepoint == 0x2122 ||
  codepoint == 0x2139 ||
  (codepoint >= 0x2194 && codepoint <= 0x21AA) ||
  (codepoint >= 0x231A && codepoint <= 0x231B) ||
  codepoint == 0x2328 ||
  codepoint == 0x2388 ||
  codepoint == 0x23CF ||
  (codepoint >= 0x23E9 && codepoint <= 0x23F3) ||
  (codepoint >= 0x23F8 && codepoint <= 0x23FA) ||
  codepoint == 0x24C2 ||
  (codepoint >= 0x25AA && codepoint <= 0x25AB) ||
  codepoint == 0x25B6 ||
  codepoint == 0x25C0 ||
  (codepoint >= 0x25FB && codepoint <= 0x25FE) ||
  (codepoint >= 0x2600 && codepoint <= 0x27BF) ||
  (codepoint >= 0x2934 && codepoint <= 0x2935) ||
  (codepoint >= 0x2B05 && codepoint <= 0x2B55) ||
  codepoint == 0x3030 ||
  codepoint == 0x303D ||
  codepoint == 0x3297 ||
  codepoint == 0x3299 ||
  (codepoint >= 0x1F000 && codepoint <= 0x1FAFF)
}

///|
fn fallback_codepoint_is_emoji_tag(codepoint : Int) -> Bool {
  (codepoint >= 0xE0020 && codepoint <= 0xE007E) || codepoint == 0xE007F
}

///|
fn fallback_codepoint_is_regional_indicator(codepoint : Int) -> Bool {
  codepoint >= 0x1F1E6 && codepoint <= 0x1F1FF
}
