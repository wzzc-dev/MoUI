///|
fn skia_mixed_text_segments(text : String) -> Array[String] {
  let clusters = skia_bidi_visual_cluster_texts(
    skia_grapheme_cluster_texts(text),
  )
  skia_mixed_text_segments_from_clusters(clusters)
}

///|
fn skia_mixed_text_segments_from_clusters(
  clusters : Array[String],
) -> Array[String] {
  let segments : Array[String] = []
  let current : Array[Char] = []
  let mut current_class = -1
  for cluster in clusters {
    let cluster_class = skia_text_segment_class(cluster)
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
fn skia_bidi_visual_cluster_texts(clusters : Array[String]) -> Array[String] {
  let visual : Array[String] = []
  let mut index = 0
  while index < clusters.length() {
    let rtl = skia_cluster_is_rtl(clusters[index])
    let start = index
    index = index + 1
    while index < clusters.length() &&
          skia_cluster_is_rtl(clusters[index]) == rtl {
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
fn skia_cluster_is_rtl(cluster : String) -> Bool {
  skia_text_segment_class(cluster) == 4
}

///|
fn skia_join_clusters(clusters : Array[String]) -> String {
  let chars : Array[Char] = []
  for cluster in clusters {
    for ch in cluster {
      chars.push(ch)
    }
  }
  String::from_array(chars)
}

///|
fn skia_string_arrays_equal(
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
fn skia_grapheme_cluster_texts(text : String) -> Array[String] {
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
fn skia_text_segment_class(text : String) -> Int {
  let representative = skia_representative_fallback_codepoint(text)
  if skia_codepoint_is_emoji_hint(representative) {
    1
  } else if skia_codepoint_is_cjk(representative) {
    2
  } else if skia_codepoint_is_hangul_cluster_codepoint(representative) {
    3
  } else if skia_codepoint_is_rtl_script(representative) {
    4
  } else if representative < 0x0300 {
    0
  } else {
    5
  }
}

///|
fn skia_codepoint_is_cjk(codepoint : Int) -> Bool {
  skia_codepoint_is_cjk_ideograph(codepoint) ||
  skia_codepoint_is_kana(codepoint)
}

///|
fn skia_codepoint_is_cjk_ideograph(codepoint : Int) -> Bool {
  (codepoint >= 0x3400 && codepoint <= 0x4DBF) ||
  (codepoint >= 0x4E00 && codepoint <= 0x9FFF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF) ||
  (codepoint >= 0x20000 && codepoint <= 0x2FA1F)
}

///|
fn skia_codepoint_is_kana(codepoint : Int) -> Bool {
  codepoint >= 0x3040 && codepoint <= 0x30FF
}

///|
fn skia_codepoint_is_rtl_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0590 && codepoint <= 0x08FF) ||
  (codepoint >= 0xFB1D && codepoint <= 0xFDFF) ||
  (codepoint >= 0xFE70 && codepoint <= 0xFEFF)
}
