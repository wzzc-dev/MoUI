///|
pub(all) struct SkiaTextVisualOrderDiagnostic {
  logical_text : String
  visual_text : String
  logical_cluster_count : Int
  visual_cluster_count : Int
  segment_count : Int
  glyph_count : Int
  width : Double
  visual_order_differs : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SkiaTextSelectionGeometryDiagnostic {
  text : String
  selection_range : @core.TextRange
  selection_rect_count : Int
  selected_line_count : Int
  line_count : Int
  hit_test_offset : Int
  hit_test_line_index : Int
  hit_test_inside : Bool
  visual_order_differs : Bool
  visual_segment_count : Int
  bidi_visual_order_observed : Bool
} derive(Eq, Debug, ToJson)

///|
priv struct SkiaParagraphClusterBox {
  has_rect : Bool
  rtl : Bool
}

///|
pub(all) struct SkiaEmojiFontFallbackDiagnostic {
  text : String
  text_system_id : String
  font_family : String
  font_source : String
  fallback_language_tags : Array[String]
  fallback_script_tag : String
  fallback_language_tag_count : Int
  fallback_request_language_count : Int
  shaper : String
  glyph_format : String
  glyph_key : String
  glyph_count : Int
  cluster_count : Int
  glyph_width : Int
  glyph_height : Int
  resolved_missing_glyph_count : Int
  fallback_character : Int
  emoji_hint : Bool
  emoji_fallback_attempted : Bool
  fallback_request_ready : Bool
  missing_glyph_recovery_ready : Bool
  deterministic_color_emoji_ready : Bool
} derive(Eq, Debug, ToJson)

///|
priv struct SkiaTextMetrics {
  baseline : Double
  height : Double
}

///|
priv struct SkiaGlyphRun {
  glyphs : Array[@skia_native.GlyphId]
  positions : Array[@moui_skia.Point]
  clusters : Array[Int]
  width : Double
}

///|
priv struct SkiaTextPlacement {
  origin : @moui_skia.Point
  clip : @core.Rect
}

///|
priv struct SkiaTextRunSegment {
  text : String
  font : @skia_native.Font
  glyph_run : SkiaGlyphRun
  x_offset : Double
}

///|
priv struct SkiaResolvedTextLayout {
  segments : Array[SkiaTextRunSegment]
  width : Double
  metrics : SkiaTextMetrics
}

///|
pub fn skia_text_visual_order_diagnostic(
  text : String,
  font? : @core.FontSpec = @core.FontSpec::new(size=20.0, weight=500),
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> SkiaTextVisualOrderDiagnostic? {
  if text == "" {
    return None
  }
  let logical_clusters = skia_grapheme_cluster_texts(text)
  let visual_clusters = skia_bidi_visual_cluster_texts(logical_clusters)
  match skia_resolved_text_layout_for_resolution(font, text, font_resolution) {
    Some(layout) => {
      let mut glyph_count = 0
      for segment in layout.segments {
        glyph_count += segment.glyph_run.glyphs.length()
      }
      Some({
        logical_text: skia_join_clusters(logical_clusters),
        visual_text: skia_join_clusters(visual_clusters),
        logical_cluster_count: logical_clusters.length(),
        visual_cluster_count: visual_clusters.length(),
        segment_count: layout.segments.length(),
        glyph_count,
        width: layout.width,
        visual_order_differs: !skia_string_arrays_equal(
          logical_clusters, visual_clusters,
        ),
      })
    }
    None => None
  }
}

///|
pub fn skia_text_selection_geometry_diagnostic(
  text : String,
  selection? : @core.TextRange? = None,
  font? : @core.FontSpec = @core.FontSpec::new(size=20.0, weight=500),
  max_width? : Double = 96.0,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> SkiaTextSelectionGeometryDiagnostic? {
  if text == "" {
    return None
  }
  let system = skia_text_system(resolution=font_resolution)
  let layout = system.layout_paragraph(
    @core.TextLayoutInput::new(text~, font~, max_width~),
  )
  if layout.lines.is_empty() {
    return None
  }
  let selection_range = match selection {
    Some(range) => range
    None => skia_default_selection_geometry_range(layout)
  }
  let normalized = @core.TextGraphemeBoundaries::new(text~).normalize_range(
    selection_range,
  )
  let selection_rects = layout.selection_rects(normalized)
  let hit_line = if layout.lines.length() > 1 {
    layout.lines[1]
  } else {
    layout.lines[0]
  }
  let hit = layout.hit_test(
    @core.Point::new(
      x=(hit_line.origin.x + hit_line.size.width * 0.5).min(max_width),
      y=hit_line.origin.y + hit_line.size.height * 0.5,
    ),
  )
  let visual = skia_text_visual_order_diagnostic(text, font~, font_resolution~)
  let (visual_order_differs, visual_segment_count, bidi_visual_order_observed) = match
    visual {
    Some(diagnostic) =>
      (
        diagnostic.visual_order_differs,
        diagnostic.segment_count,
        diagnostic.visual_order_differs &&
        diagnostic.logical_cluster_count == diagnostic.visual_cluster_count &&
        diagnostic.segment_count >= 3 &&
        diagnostic.glyph_count >= 1,
      )
    None => (false, 0, false)
  }
  Some({
    text,
    selection_range: normalized,
    selection_rect_count: selection_rects.length(),
    selected_line_count: skia_selected_line_count(layout, normalized),
    line_count: layout.line_count(),
    hit_test_offset: hit.offset,
    hit_test_line_index: hit.line_index,
    hit_test_inside: hit.is_inside,
    visual_order_differs,
    visual_segment_count,
    bidi_visual_order_observed,
  })
}

///|
pub fn skia_emoji_font_fallback_diagnostic(
  text? : String = "\u{1F469}\u{200D}\u{1F4BB}",
  font? : @core.FontSpec = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
    size=32.0,
    weight=400,
  ),
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> SkiaEmojiFontFallbackDiagnostic? {
  if text == "" {
    return None
  }
  let emoji_hint = skia_text_contains_emoji_hint(text)
  let fallback_request = skia_font_fallback_request(font, text)
  let fallback_language_tags = skia_font_fallback_language_tags(text)
  let fallback_script_tag = skia_fallback_script_tag(fallback_language_tags)
  let fallback_request_language_count = fallback_request.language_count()
  match skia_resolved_text_layout_for_resolution(font, text, font_resolution) {
    Some(layout) => {
      let glyph_count = skia_resolved_text_layout_glyph_count(layout)
      if glyph_count <= 0 || layout.width <= 0.0 || layout.metrics.height <= 0.0 {
        return None
      }
      let text_system = skia_text_system(resolution=font_resolution)
      let shaper = if @skia_native.skia_shaper_available() {
        "skshaper"
      } else {
        "fallback-glyph-run"
      }
      let fallback_character = skia_representative_fallback_codepoint(text)
      let font_source = skia_emoji_font_source_label(font_resolution)
      let glyph_format = skia_emoji_glyph_format_label()
      let resolved_missing_glyph_count = skia_resolved_text_layout_missing_glyph_count(
        layout,
      )
      Some({
        text,
        text_system_id: text_system.id(),
        font_family: "emoji",
        font_source,
        fallback_language_tags,
        fallback_script_tag,
        fallback_language_tag_count: fallback_language_tags.length(),
        fallback_request_language_count,
        shaper,
        glyph_format,
        glyph_key: skia_emoji_glyph_key(
          font_source,
          text_system.id(),
          shaper,
          fallback_script_tag,
          fallback_language_tags,
          fallback_request_language_count,
          fallback_character,
          glyph_format,
        ),
        glyph_count,
        cluster_count: skia_grapheme_cluster_texts(text).length(),
        glyph_width: skia_positive_pixel_extent(layout.width),
        glyph_height: skia_positive_pixel_extent(layout.metrics.height),
        resolved_missing_glyph_count,
        fallback_character,
        emoji_hint,
        emoji_fallback_attempted: font_resolution ==
        SkiaFontResolution::SystemFontMgr &&
        emoji_hint,
        fallback_request_ready: !fallback_request.is_empty() &&
        fallback_request.has_character() &&
        fallback_request_language_count == fallback_language_tags.length(),
        missing_glyph_recovery_ready: skia_sample_missing_glyph_recovery_ready(),
        deterministic_color_emoji_ready: false,
      })
    }
    None => None
  }
}

///|
fn skia_emoji_font_source_label(resolution : SkiaFontResolution) -> String {
  match resolution {
    SkiaFontResolution::SystemFontMgr => "skia-system-fontmgr"
    SkiaFontResolution::EmptyTypeface => "skia-empty-typeface"
  }
}

///|
fn skia_emoji_glyph_format_label() -> String {
  "rgba"
}

///|
fn skia_fallback_script_tag(tags : Array[String]) -> String {
  if tags.is_empty() {
    ""
  } else {
    tags[0]
  }
}

///|
fn skia_emoji_glyph_key(
  font_source : String,
  text_system_id : String,
  shaper : String,
  fallback_script_tag : String,
  fallback_language_tags : Array[String],
  fallback_request_language_count : Int,
  fallback_character : Int,
  glyph_format : String,
) -> String {
  let script_key = if fallback_script_tag == "" {
    "script=und"
  } else {
    "script=\{fallback_script_tag}"
  }
  let language_key = if fallback_language_tags.is_empty() {
    "lang-tags=none"
  } else {
    "lang-tags=\{fallback_language_tags.join("+")}"
  }
  "\{font_source}|\{text_system_id}|\{shaper}|\{script_key}|langs=\{fallback_request_language_count}|\{language_key}|emoji-u+\{fallback_character}|\{glyph_format}"
}

///|
fn skia_resolved_text_layout_glyph_count(
  layout : SkiaResolvedTextLayout,
) -> Int {
  let mut glyph_count = 0
  for segment in layout.segments {
    glyph_count += segment.glyph_run.glyphs.length()
  }
  glyph_count
}

///|
fn skia_resolved_text_layout_missing_glyph_count(
  layout : SkiaResolvedTextLayout,
) -> Int {
  let mut missing_glyph_count = 0
  for segment in layout.segments {
    missing_glyph_count += skia_glyph_run_missing_glyph_count(segment.glyph_run)
  }
  missing_glyph_count
}

///|
fn skia_positive_pixel_extent(value : Double) -> Int {
  value.ceil().to_int().max(1)
}

///|
fn skia_default_selection_geometry_range(
  layout : @core.TextParagraphLayoutResult,
) -> @core.TextRange {
  if layout.lines.length() > 1 {
    @core.TextRange::new(
      start=layout.lines[0].text_range.start,
      end=layout.lines[1].text_range.end,
    )
  } else {
    @core.TextRange::new(start=0, end=layout.text.to_array().length())
  }
}

///|
fn skia_selected_line_count(
  layout : @core.TextParagraphLayoutResult,
  range : @core.TextRange,
) -> Int {
  let range = range.normalized()
  if range.is_collapsed() {
    return 1
  }
  let mut count = 0
  for line in layout.lines {
    if range.start < line.text_range.end && range.end > line.text_range.start {
      count += 1
    }
  }
  count
}

///|
fn SkiaRasterRenderer::draw_text(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.TextRun,
) -> Unit {
  if !skia_text_frame_can_draw(run.frame) {
    return ()
  }
  match
    skia_resolved_text_layout_for_resolution(
      run.font,
      run.text,
      self.font_resolution,
    ) {
    Some(layout) => {
      let placement = if layout.segments.length() == 1 {
        skia_text_placement(run, layout.segments[0].glyph_run, layout.metrics)
      } else {
        skia_text_placement_for_width(run, layout.width, layout.metrics)
      }
      let saved = canvas.save()
      canvas.clip_rect(skia_rect(placement.clip), anti_alias=true)
      for segment in layout.segments {
        canvas.draw_glyphs(
          segment.glyph_run.glyphs,
          segment.glyph_run.positions,
          segment.font,
          skia_paint(run.color),
          origin=@moui_skia.Point::new(
            Float::from_double(
              placement.origin.x.to_double() + segment.x_offset,
            ),
            placement.origin.y,
          ),
        )
      }
      canvas.restore_to_count(saved)
    }
    None =>
      self.record_unsupported_command(
        "DrawText", "Skia text layout unavailable; skipped text run",
      )
  }
}

///|
fn skia_text_frame_can_draw(frame : @core.Rect) -> Bool {
  frame.size.width > 0.0 && frame.size.height > 0.0
}

///|
fn skia_text_placement(
  run : @core.TextRun,
  glyph_run : SkiaGlyphRun,
  metrics : SkiaTextMetrics,
) -> SkiaTextPlacement {
  skia_text_placement_for_width(run, glyph_run.width, metrics)
}

///|
fn skia_text_placement_for_width(
  run : @core.TextRun,
  text_width : Double,
  metrics : SkiaTextMetrics,
) -> SkiaTextPlacement {
  let x = match run.align {
    @core.TextAlign::TextStart => run.frame.origin.x
    @core.TextAlign::TextCenter =>
      run.frame.origin.x + (run.frame.size.width - text_width) / 2.0
    @core.TextAlign::TextEnd =>
      run.frame.origin.x + run.frame.size.width - text_width
  }
  let y = skia_text_baseline_y(run.frame, metrics)
  {
    origin: @moui_skia.Point::new(Float::from_double(x), Float::from_double(y)),
    clip: run.frame,
  }
}

///|
fn skia_text_baseline_y(
  frame : @core.Rect,
  metrics : SkiaTextMetrics,
) -> Double {
  let offset_y = if frame.size.height > metrics.height {
    (frame.size.height - metrics.height) / 2.0
  } else {
    0.0
  }
  frame.origin.y + offset_y + metrics.baseline
}

///|
fn skia_draw_text_payload_for_resolution(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  match skia_font_with_resolution_for_text(font_spec, text, resolution) {
    Some(font) => {
      let glyph_run = skia_glyph_run_for_resolution(font, text, resolution)
      if skia_glyph_run_can_draw_text(glyph_run) {
        Some((font, glyph_run))
      } else {
        skia_fallback_draw_payload(font_spec, text, resolution, glyph_run)
      }
    }
    None => None
  }
}

///|
fn skia_resolved_text_layout_for_resolution(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaResolvedTextLayout? {
  if text == "" {
    match skia_draw_text_payload_for_resolution(font_spec, text, resolution) {
      Some((font, glyph_run)) =>
        Some({
          segments: [{ text, font, glyph_run, x_offset: 0.0 }],
          width: glyph_run.width,
          metrics: skia_text_metrics(
            font,
            fallback_baseline=font_spec.size,
            fallback_height=font_spec.size * 1.25,
          ),
        })
      None => None
    }
  } else {
    skia_resolved_text_segments(font_spec, text, resolution)
  }
}

///|
fn skia_resolved_text_segments(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaResolvedTextLayout? {
  let text_segments = skia_mixed_text_segments(text)
  if text_segments.is_empty() {
    return None
  }
  let segments : Array[SkiaTextRunSegment] = []
  let mut x_offset = 0.0
  let mut baseline = 0.0
  let mut height = 0.0
  for segment_text in text_segments {
    match
      skia_draw_text_payload_for_resolution(font_spec, segment_text, resolution) {
      Some((font, glyph_run)) => {
        let metrics = skia_text_metrics(
          font,
          fallback_baseline=font_spec.size,
          fallback_height=font_spec.size * 1.25,
        )
        baseline = baseline.max(metrics.baseline)
        height = height.max(metrics.height)
        segments.push({ text: segment_text, font, glyph_run, x_offset })
        x_offset = x_offset + glyph_run.width
      }
      None => return None
    }
  }
  if segments.is_empty() {
    None
  } else {
    Some({
      segments,
      width: x_offset,
      metrics: { baseline, height: height.max(baseline) },
    })
  }
}

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
