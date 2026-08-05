///|
/// Shared text segmentation and codepoint classification. Skia and Sun used
/// to each maintain their own grapheme-cluster/bidi-visual-order/mixed-segment
/// pipeline and identical codepoint classifiers for fallback diagnostics.
/// This module owns that pure logic once; renderers keep their native text
/// engines and call back into these helpers.

///|
/// Split text into grapheme clusters via the shared `@core` UAX-style
/// boundary scanner, then order runs visually (RTL runs reversed).
pub fn text_bidi_visual_clusters(text : String) -> Array[String] {
  let clusters = text_grapheme_clusters(text)
  let visual : Array[String] = []
  let mut index = 0
  while index < clusters.length() {
    let rtl = text_cluster_is_rtl(clusters[index])
    let start = index
    index = index + 1
    while index < clusters.length() &&
          text_cluster_is_rtl(clusters[index]) == rtl {
      index = index + 1
    }
    if rtl {
      let mut cursor = index
      while cursor > start {
        cursor = cursor - 1
        visual.push(clusters[cursor])
      }
    } else {
      for cursor in start..<index {
        visual.push(clusters[cursor])
      }
    }
  }
  visual
}

///|
/// Split mixed-script text into grapheme-safe fallback segments in visual
/// order, one segment per contiguous same-class run.
pub fn text_mixed_segments(text : String) -> Array[String] {
  let clusters = text_bidi_visual_clusters(text)
  let segments : Array[String] = []
  let current : Array[Char] = []
  let mut current_class = -1
  for cluster in clusters {
    let cluster_class = text_segment_class(cluster)
    if !current.is_empty() && cluster_class != current_class {
      segments.push(String::from_array(current))
      current.clear()
    }
    for ch in cluster {
      current.push(ch)
    }
    current_class = cluster_class
  }
  if !current.is_empty() {
    segments.push(String::from_array(current))
  }
  segments
}

///|
fn text_cluster_is_rtl(cluster : String) -> Bool {
  text_segment_class(cluster) == 4
}

///|
/// Join grapheme clusters back into a single string.
pub fn text_join_clusters(clusters : Array[String]) -> String {
  let chars : Array[Char] = []
  for cluster in clusters {
    for ch in cluster {
      chars.push(ch)
    }
  }
  String::from_array(chars)
}

///|
pub fn text_string_arrays_equal(
  left : Array[String],
  right : Array[String],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
/// Split text into grapheme clusters using `@core.TextGraphemeBoundaries`.
pub fn text_grapheme_clusters(text : String) -> Array[String] {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  let clusters : Array[String] = []
  if boundaries.length() < 2 {
    return clusters
  }
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    if end > start {
      clusters.push(String::from_array(chars[start:end]))
    }
  }
  clusters
}

///|
/// Classify a text segment for fallback planning: 1 emoji, 2 CJK, 3 Hangul,
/// 4 RTL script, 5 combining marks, 0 other.
pub fn text_segment_class(text : String) -> Int {
  let representative = representative_fallback_codepoint(
    text,
    skip_joiners=false,
  )
  if codepoint_is_emoji_hint(representative) {
    1
  } else if codepoint_is_cjk(representative) {
    2
  } else if codepoint_is_hangul_cluster_codepoint(representative) {
    3
  } else if codepoint_is_rtl_script(representative) {
    4
  } else if representative < 0x0300 {
    0
  } else {
    5
  }
}

///|
pub fn codepoint_is_cjk(codepoint : Int) -> Bool {
  codepoint_is_cjk_ideograph(codepoint) || codepoint_is_kana(codepoint)
}

///|
pub fn codepoint_is_cjk_ideograph(codepoint : Int) -> Bool {
  (codepoint >= 0x3400 && codepoint <= 0x4DBF) ||
  (codepoint >= 0x4E00 && codepoint <= 0x9FFF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF) ||
  (codepoint >= 0x20000 && codepoint <= 0x2FA1F)
}

///|
pub fn codepoint_is_kana(codepoint : Int) -> Bool {
  codepoint >= 0x3040 && codepoint <= 0x30FF
}

///|
pub fn codepoint_is_rtl_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0590 && codepoint <= 0x08FF) ||
  (codepoint >= 0xFB1D && codepoint <= 0xFDFF) ||
  (codepoint >= 0xFE70 && codepoint <= 0xFEFF)
}

///|
pub fn codepoint_is_emoji_hint(codepoint : Int) -> Bool {
  codepoint == 0x200D ||
  codepoint == 0xFE0F ||
  (codepoint >= 0x2600 && codepoint <= 0x27BF) ||
  (codepoint >= 0x1F000 && codepoint <= 0x1FAFF)
}

///|
pub fn codepoint_is_hangul_cluster_codepoint(codepoint : Int) -> Bool {
  codepoint_is_hangul_l(codepoint) ||
  codepoint_is_hangul_v(codepoint) ||
  codepoint_is_hangul_t(codepoint) ||
  codepoint_is_hangul_lv(codepoint) ||
  codepoint_is_hangul_lvt(codepoint)
}

///|
pub fn codepoint_is_hangul_l(codepoint : Int) -> Bool {
  (codepoint >= 0x1100 && codepoint <= 0x115F) ||
  (codepoint >= 0xA960 && codepoint <= 0xA97C)
}

///|
pub fn codepoint_is_hangul_v(codepoint : Int) -> Bool {
  (codepoint >= 0x1160 && codepoint <= 0x11A7) ||
  (codepoint >= 0xD7B0 && codepoint <= 0xD7C6)
}

///|
pub fn codepoint_is_hangul_t(codepoint : Int) -> Bool {
  (codepoint >= 0x11A8 && codepoint <= 0x11FF) ||
  (codepoint >= 0xD7CB && codepoint <= 0xD7FB)
}

///|
pub fn codepoint_is_hangul_lv(codepoint : Int) -> Bool {
  codepoint_is_hangul_syllable(codepoint) && (codepoint - 0xAC00) % 28 == 0
}

///|
pub fn codepoint_is_hangul_lvt(codepoint : Int) -> Bool {
  codepoint_is_hangul_syllable(codepoint) && (codepoint - 0xAC00) % 28 != 0
}

///|
pub fn codepoint_is_hangul_syllable(codepoint : Int) -> Bool {
  codepoint >= 0xAC00 && codepoint <= 0xD7A3
}

///|
pub fn codepoint_is_hangul_compatibility_jamo(codepoint : Int) -> Bool {
  codepoint >= 0x3130 && codepoint <= 0x318F
}

///|
/// Representative codepoint for fallback planning: the first emoji-hint
/// codepoint (optionally skipping ZWJ/VS16 joiners), else the first
/// non-ASCII codepoint, else the first codepoint.
pub fn representative_fallback_codepoint(
  text : String,
  skip_joiners? : Bool = false,
) -> Int {
  let mut first = 0
  let mut first_non_ascii = 0
  for ch in text {
    let codepoint = ch.to_int()
    if first == 0 {
      first = codepoint
    }
    if first_non_ascii == 0 && codepoint >= 0x80 {
      first_non_ascii = codepoint
    }
    if codepoint_is_emoji_hint(codepoint) &&
      (!skip_joiners || (codepoint != 0x200D && codepoint != 0xFE0F)) {
      return codepoint
    }
  }
  if first_non_ascii > 0 {
    first_non_ascii
  } else {
    first
  }
}
