///|
fn skia_resolved_text_layout_result(
  input : @core.TextLayoutInput,
  fallback : @core.TextLayoutResult,
  layout~ : SkiaResolvedTextLayout,
) -> @core.TextLayoutResult {
  if layout.segments.is_empty() {
    return fallback
  }
  if layout.segments.length() == 1 && layout.segments[0].text == input.text {
    return skia_text_layout_result(
      layout.segments[0].font,
      input,
      fallback,
      glyph_run=layout.segments[0].glyph_run,
    )
  }
  let carets = skia_resolved_text_caret_positions(input.text, layout)
  let measured = skia_layout_width_from_carets(carets)
  match input.max_width {
    Some(max_width) => {
      let clamped : Array[Double] = []
      for caret in carets {
        clamped.push(caret.min(max_width))
      }
      {
        size: @core.Size::new(
          width=measured.min(max_width),
          height=layout.metrics.height,
        ),
        baseline: layout.metrics.baseline,
        caret_positions: clamped,
      }
    }
    None =>
      {
        size: @core.Size::new(width=measured, height=layout.metrics.height),
        baseline: layout.metrics.baseline,
        caret_positions: carets,
      }
  }
}

///|
fn skia_text_layout_result(
  font : @skia_native.Font,
  input : @core.TextLayoutInput,
  fallback : @core.TextLayoutResult,
  glyph_run~ : SkiaGlyphRun,
) -> @core.TextLayoutResult {
  if !skia_font_can_measure_text(font, input.text) {
    return fallback
  }
  let carets = skia_caret_positions(font, input.text, glyph_run~)
  let measured = skia_layout_width_from_carets(carets)
  let metrics = skia_text_metrics(
    font,
    fallback_baseline=fallback.baseline,
    fallback_height=fallback.size.height,
  )
  match input.max_width {
    Some(max_width) => {
      let clamped : Array[Double] = []
      for caret in carets {
        clamped.push(caret.min(max_width))
      }
      {
        size: @core.Size::new(
          width=measured.min(max_width),
          height=metrics.height,
        ),
        baseline: metrics.baseline,
        caret_positions: clamped,
      }
    }
    None =>
      {
        size: @core.Size::new(width=measured, height=metrics.height),
        baseline: metrics.baseline,
        caret_positions: carets,
      }
  }
}

///|
fn skia_resolved_text_caret_positions(
  text : String,
  layout : SkiaResolvedTextLayout,
) -> Array[Double] {
  let carets : Array[Double] = [0.0]
  for segment in layout.segments {
    let segment_carets = skia_caret_positions(
      segment.font,
      segment.text,
      glyph_run=segment.glyph_run,
    )
    if segment_carets.length() > 1 {
      for index in 1..<segment_carets.length() {
        carets.push(segment.x_offset + segment_carets[index])
      }
    }
  }
  if carets.length() != text.to_array().length() + 1 {
    return carets
  }
  skia_stabilize_grapheme_cluster_carets(text, carets)
}

///|
fn skia_font_can_measure_text(font : @skia_native.Font, text : String) -> Bool {
  text == "" || skia_measure_text_width(font, text) > 0.0
}

///|
fn skia_text_metrics(
  font : @skia_native.Font,
  fallback_baseline~ : Double,
  fallback_height~ : Double,
) -> SkiaTextMetrics {
  let metrics = font.metrics()
  let ascent = metrics.ascent.to_double()
  let descent = metrics.descent.to_double()
  let leading = metrics.leading.to_double()
  let measured_baseline = (0.0 - ascent).max(0.0)
  let measured_height = (descent - ascent + leading)
    .max(descent - ascent)
    .max(0.0)
  let baseline = if measured_baseline > 0.0 {
    measured_baseline
  } else {
    fallback_baseline
  }
  let height = if measured_height > 0.0 {
    measured_height
  } else {
    fallback_height
  }
  { baseline, height: height.max(baseline) }
}

///|
fn skia_caret_positions(
  font : @skia_native.Font,
  text : String,
  glyph_run? : SkiaGlyphRun,
) -> Array[Double] {
  match glyph_run {
    Some(run) =>
      match skia_shaped_caret_positions(text, run) {
        Some(carets) =>
          if skia_shaped_caret_positions_are_usable(text, carets) {
            return carets
          }
        None => ()
      }
    None => ()
  }
  let chars = text.to_array()
  let carets : Array[Double] = [0.0]
  for index in 1..<(chars.length() + 1) {
    let prefix = String::from_array(chars[:index])
    carets.push(skia_measure_text_width(font, prefix))
  }
  skia_stabilize_grapheme_cluster_carets(text, carets)
}

///|
fn skia_shaped_caret_positions_are_usable(
  text : String,
  carets : Array[Double],
) -> Bool {
  let chars = text.to_array()
  if carets.length() != chars.length() + 1 {
    return false
  }
  let clusters = @render_common.text_grapheme_clusters(text)
  if clusters.length() != chars.length() || chars.length() <= 2 {
    return true
  }
  for index in 1..<(carets.length() - 1) {
    if carets[index] > carets[index - 1] {
      return true
    }
  }
  false
}

///|
fn skia_layout_width_from_carets(carets : Array[Double]) -> Double {
  if carets.is_empty() {
    0.0
  } else {
    carets[carets.length() - 1]
  }
}

///|
fn skia_complete_monotonic_carets(
  text : String,
  carets : Array[Double],
  width : Double,
) -> Array[Double] {
  let mut previous = 0.0
  for index in 0..<carets.length() {
    if carets[index] < 0.0 || carets[index] < previous {
      carets[index] = previous
    } else {
      carets[index] = carets[index].min(width)
      previous = carets[index]
    }
  }
  carets[carets.length() - 1] = width.max(carets[carets.length() - 1])
  skia_stabilize_grapheme_cluster_carets(text, carets)
}

///|
fn skia_shaped_caret_positions(
  text : String,
  run : SkiaGlyphRun,
) -> Array[Double]? {
  if run.clusters.is_empty() ||
    run.positions.length() != run.clusters.length() ||
    run.width <= 0.0 {
    return None
  }
  let offsets = skia_utf8_char_offsets(text)
  if offsets.length() <= 1 {
    return Some([0.0])
  }
  let carets : Array[Double] = Array::new(capacity=offsets.length())
  for _ in offsets {
    carets.push(-1.0)
  }
  carets[0] = 0.0
  carets[carets.length() - 1] = run.width
  for index, cluster in run.clusters {
    match skia_char_index_for_utf8_offset(offsets, cluster) {
      Some(caret_index) => {
        let x = run.positions[index].x.to_double()
        if x >= 0.0 && x <= run.width {
          let current = carets[caret_index]
          if current < 0.0 || x < current {
            carets[caret_index] = x
          }
        }
      }
      None => ()
    }
  }
  Some(skia_complete_monotonic_carets(text, carets, run.width))
}

///|
fn skia_stabilize_grapheme_cluster_carets(
  text : String,
  carets : Array[Double],
) -> Array[Double] {
  let chars = text.to_array()
  if carets.length() != chars.length() + 1 {
    return carets
  }
  let adjusted = carets.copy()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    if end > start + 1 {
      skia_stabilize_caret_cluster(adjusted, start, end)
    }
  }
  adjusted
}

///|
fn skia_stabilize_caret_cluster(
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
fn skia_utf8_char_offsets(text : String) -> Array[Int] {
  let offsets : Array[Int] = [0]
  let mut offset = 0
  for ch in text {
    offset += @utf8.encode(ch.to_string()[:], bom=false).length()
    offsets.push(offset)
  }
  offsets
}

///|
fn skia_char_index_for_utf8_offset(offsets : Array[Int], offset : Int) -> Int? {
  if offset < 0 {
    return None
  }
  for index, current in offsets {
    if current == offset {
      return Some(index)
    }
    if current > offset {
      return Some(index)
    }
  }
  None
}

///|
/// Per-character UTF-16 code unit offsets. SkParagraph reports line
/// metrics (`fStartIndex`/`fEndIndex`) in UTF-16 units while the rect and
/// hit-test APIs accept UTF-8 bytes, so line metrics need their own table:
/// for ASCII the two coincide, and only mixed CJK/Latin text exposes the
/// difference.
fn skia_utf16_char_offsets(text : String) -> Array[Int] {
  let offsets : Array[Int] = [0]
  let mut offset = 0
  for ch in text {
    offset += if ch.to_int() < 0x10000 { 1 } else { 2 }
    offsets.push(offset)
  }
  offsets
}

///|
fn skia_char_index_for_utf16_offset(offsets : Array[Int], units : Int) -> Int? {
  skia_char_index_for_utf8_offset(offsets, units)
}
