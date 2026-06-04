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
  let mut index = 0
  while index < chars.length() {
    let cluster_end = fallback_grapheme_cluster_end(chars, index)
    if cluster_end > index + 1 {
      fallback_stabilize_caret_cluster(adjusted, index, cluster_end)
      index = cluster_end
    } else {
      index = index + 1
    }
  }
  adjusted
}

///|
fn fallback_grapheme_cluster_end(chars : Array[Char], start : Int) -> Int {
  if start < 0 || start >= chars.length() {
    return start
  }
  let codepoint = chars[start].to_int()
  if fallback_codepoint_is_regional_indicator(codepoint) {
    return fallback_regional_indicator_cluster_end(chars, start)
  }
  if fallback_codepoint_is_grapheme_prepend(codepoint) {
    return fallback_prepend_cluster_end(chars, start)
  }
  if fallback_codepoint_is_hangul_cluster_codepoint(codepoint) {
    return fallback_hangul_cluster_end(chars, start)
  }
  if fallback_codepoint_can_start_emoji_tag_sequence(codepoint) {
    let tag_end = fallback_emoji_tag_sequence_end(chars, start)
    if tag_end > start + 1 {
      return tag_end
    }
  }
  let mut end = fallback_grapheme_extend_end(chars, start + 1)
  let mut advanced = true
  while advanced {
    advanced = false
    if end < chars.length() &&
      chars[end].to_int() == 0x200D &&
      end + 1 < chars.length() {
      end = fallback_grapheme_extend_end(chars, end + 2)
      advanced = true
    } else if end < chars.length() &&
      end > start &&
      fallback_codepoint_is_virama(chars[end - 1].to_int()) {
      end = fallback_grapheme_extend_end(chars, end + 1)
      advanced = true
    }
  }
  end
}

///|
fn fallback_regional_indicator_cluster_end(
  chars : Array[Char],
  start : Int,
) -> Int {
  let mut end = start
  while end < chars.length() &&
        fallback_codepoint_is_regional_indicator(chars[end].to_int()) &&
        end - start < 2 {
    end = end + 1
  }
  end
}

///|
fn fallback_emoji_tag_sequence_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start + 1
  let mut saw_tag = false
  while end < chars.length() &&
        fallback_codepoint_is_emoji_tag(chars[end].to_int()) {
    saw_tag = true
    end = end + 1
    if chars[end - 1].to_int() == 0xE007F {
      return end
    }
  }
  if saw_tag {
    end
  } else {
    start
  }
}

///|
fn fallback_prepend_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut base = start + 1
  while base < chars.length() &&
        fallback_codepoint_is_grapheme_prepend(chars[base].to_int()) {
    base = base + 1
  }
  if base >= chars.length() {
    return base
  }
  fallback_grapheme_cluster_end(chars, base)
}

///|
fn fallback_hangul_cluster_end(chars : Array[Char], start : Int) -> Int {
  let codepoint = chars[start].to_int()
  if fallback_codepoint_is_hangul_l(codepoint) {
    return fallback_hangul_l_cluster_end(chars, start)
  }
  if fallback_codepoint_is_hangul_v(codepoint) ||
    fallback_codepoint_is_hangul_lv(codepoint) {
    return fallback_hangul_v_cluster_end(chars, start + 1)
  }
  if fallback_codepoint_is_hangul_t(codepoint) ||
    fallback_codepoint_is_hangul_lvt(codepoint) {
    return fallback_hangul_t_cluster_end(chars, start + 1)
  }
  start
}

///|
fn fallback_hangul_l_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start + 1
  while end < chars.length() &&
        fallback_codepoint_is_hangul_l(chars[end].to_int()) {
    end = end + 1
  }
  if end < chars.length() {
    let codepoint = chars[end].to_int()
    if fallback_codepoint_is_hangul_v(codepoint) ||
      fallback_codepoint_is_hangul_lv(codepoint) {
      end = fallback_hangul_v_cluster_end(chars, end + 1)
    } else if fallback_codepoint_is_hangul_lvt(codepoint) {
      end = fallback_hangul_t_cluster_end(chars, end + 1)
    }
  }
  fallback_grapheme_extend_end(chars, end)
}

///|
fn fallback_hangul_v_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() &&
        fallback_codepoint_is_hangul_v(chars[end].to_int()) {
    end = end + 1
  }
  fallback_hangul_t_cluster_end(chars, end)
}

///|
fn fallback_hangul_t_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() &&
        fallback_codepoint_is_hangul_t(chars[end].to_int()) {
    end = end + 1
  }
  fallback_grapheme_extend_end(chars, end)
}

///|
fn fallback_grapheme_extend_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() &&
        fallback_codepoint_is_grapheme_extend(chars[end].to_int()) {
    end = end + 1
  }
  end
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
  let chars = text.to_array()
  let caret = clamp_int(caret, 0, chars.length())
  if caret <= 0 {
    return 0
  }
  let mut index = 0
  while index < chars.length() {
    let end = fallback_grapheme_cluster_end_safe(chars, index)
    if caret > index && caret <= end {
      return index
    }
    index = end
  }
  clamp_int(caret - 1, 0, chars.length())
}

///|
fn text_next_grapheme_caret_boundary(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let caret = clamp_int(caret, 0, chars.length())
  if caret >= chars.length() {
    return chars.length()
  }
  let mut index = 0
  while index < chars.length() {
    let end = fallback_grapheme_cluster_end_safe(chars, index)
    if caret < end {
      return end
    }
    index = end
  }
  chars.length()
}

///|
fn fallback_grapheme_cluster_end_safe(chars : Array[Char], start : Int) -> Int {
  let end = fallback_grapheme_cluster_end(chars, start)
  if end <= start {
    min_int(start + 1, chars.length())
  } else {
    min_int(end, chars.length())
  }
}

///|
fn fallback_codepoint_is_variation_selector(codepoint : Int) -> Bool {
  (codepoint >= 0xFE00 && codepoint <= 0xFE0F) ||
  (codepoint >= 0xE0100 && codepoint <= 0xE01EF)
}

///|
fn fallback_codepoint_is_grapheme_extend(codepoint : Int) -> Bool {
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
fn fallback_codepoint_is_hangul_cluster_codepoint(codepoint : Int) -> Bool {
  fallback_codepoint_is_hangul_l(codepoint) ||
  fallback_codepoint_is_hangul_v(codepoint) ||
  fallback_codepoint_is_hangul_t(codepoint) ||
  fallback_codepoint_is_hangul_lv(codepoint) ||
  fallback_codepoint_is_hangul_lvt(codepoint)
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
fn fallback_codepoint_is_emoji_tag(codepoint : Int) -> Bool {
  (codepoint >= 0xE0020 && codepoint <= 0xE007E) || codepoint == 0xE007F
}

///|
fn fallback_codepoint_can_start_emoji_tag_sequence(codepoint : Int) -> Bool {
  codepoint == 0x1F3F4
}

///|
fn fallback_codepoint_is_regional_indicator(codepoint : Int) -> Bool {
  codepoint >= 0x1F1E6 && codepoint <= 0x1F1FF
}
