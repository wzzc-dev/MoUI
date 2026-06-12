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

///|
pub fn SkiaRasterRenderer::text_system(
  self : SkiaRasterRenderer,
) -> @core.TextSystem {
  skia_text_system(resolution=self.font_resolution)
}

///|
pub fn skia_text_system(
  resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @core.TextSystem {
  match resolution {
    SkiaFontResolution::EmptyTypeface =>
      if skia_available() {
        skia_empty_typeface_text_system()
      } else {
        @core.TextSystem::fallback()
      }
    SkiaFontResolution::SystemFontMgr => skia_system_font_mgr_text_system()
  }
}

///|
fn skia_empty_typeface_text_system() -> @core.TextSystem {
  @core.TextSystem::new(
    id="skia-raster-empty-typeface-text-system",
    measure=input => {
      skia_measure_text_for_resolution(input, SkiaFontResolution::EmptyTypeface)
    },
    paragraph_layout=Some(input => {
      skia_fallback_paragraph_layout_result(
        input,
        SkiaFontResolution::EmptyTypeface,
        "skia-raster-empty-typeface-text-system",
      )
    }),
  )
}

///|
fn skia_system_font_mgr_text_system() -> @core.TextSystem {
  @core.TextSystem::new(
    id="skia-raster-text-system",
    measure=input => {
      skia_measure_text_for_resolution(input, SkiaFontResolution::SystemFontMgr)
    },
    paragraph_layout=Some(input => {
      match skia_native_paragraph_layout_result(input) {
        Some(layout) => layout
        None =>
          skia_fallback_paragraph_layout_result(
            input,
            SkiaFontResolution::SystemFontMgr,
            "skia-raster-text-system",
          )
      }
    }),
  )
}

///|
fn skia_measure_text_for_resolution(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
) -> @core.TextLayoutResult {
  let fallback = @core.TextSystem::fallback().measure_text(input)
  match
    skia_resolved_text_layout_for_resolution(input.font, input.text, resolution) {
    Some(layout) => skia_resolved_text_layout_result(input, fallback, layout~)
    None => fallback
  }
}

///|
fn skia_fallback_paragraph_layout_result(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
  id : String,
) -> @core.TextParagraphLayoutResult {
  @core.TextSystem::new(id~, measure=measure_input => {
    skia_measure_text_for_resolution(measure_input, resolution)
  }).layout_paragraph(input)
}

///|
fn skia_native_paragraph_layout_result(
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult? {
  if input.text == "" || !@skia_native.skia_paragraph_available() {
    return None
  }
  let max_width = input.max_width.unwrap_or(1000000000.0)
  let family_name = skia_primary_paragraph_family(input.font)
  let text_bytes = @utf8.encode(input.text[:], bom=false)
  match
    @skia_native.Paragraph::layout_utf8(
      text_bytes,
      family_name~,
      size=Float::from_double(input.font.size),
      weight=input.font.weight,
      width=5,
      slant=skia_font_slant(input.font.style),
      max_width=Float::from_double(max_width),
      left_to_right=true,
    ) {
    None => None
    Some(paragraph) => {
      let offsets = skia_utf8_char_offsets(input.text)
      let lines = skia_paragraph_line_metrics(input.text, paragraph, offsets)
      if lines.is_empty() {
        return None
      }
      let caret_rects = skia_paragraph_caret_rects(
        input.text,
        paragraph,
        lines,
        offsets,
      )
      if caret_rects.length() != input.text.to_array().length() + 1 {
        return None
      }
      let all_text_boxes = paragraph.text_boxes_utf8(0, text_bytes.length())
      if all_text_boxes.is_empty() {
        return None
      }
      let probe = skia_paragraph_bidi_probe_ready(input.font)
      let visual_order = skia_paragraph_visual_order_metadata(
        input.text,
        paragraph,
        offsets,
        bidi_ready=probe,
      )
      let hit = paragraph.hit_test_utf8(
        0.0,
        Float::from_double(lines[0].baseline),
      )
      let hit_available = hit.offset >= 0 && hit.offset <= text_bytes.length()
      let selection_rects_available = all_text_boxes.length() > 0
      let line_metrics_available = !lines.is_empty()
      let native_ready = line_metrics_available &&
        selection_rects_available &&
        hit_available &&
        !caret_rects.is_empty()
      Some({
        text: input.text,
        size: @core.Size::new(
          width=paragraph.width().to_double().min(max_width),
          height=paragraph.height().to_double(),
        ),
        baseline: lines[0].baseline,
        lines,
        caret_rects,
        visual_order,
        metadata: {
          text_system_id: "skia-raster-text-system",
          paragraph_layout_available: true,
          line_metrics_available,
          selection_rects_available,
          hit_test_available: hit_available,
          native_paragraph_ready: native_ready,
          bidi_visual_order_ready: native_ready && probe,
        },
      })
    }
  }
}

///|
fn skia_primary_paragraph_family(font : @core.FontSpec) -> Bytes {
  let candidates = skia_preflight_family_candidates(font)
  if candidates.is_empty() {
    b""
  } else {
    @utf8.encode(candidates[0][:], bom=false)
  }
}

///|
fn skia_paragraph_line_metrics(
  text : String,
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
) -> Array[@core.TextParagraphLineMetrics] {
  let chars = text.to_array()
  let lines : Array[@core.TextParagraphLineMetrics] = []
  for metric in paragraph.line_metrics() {
    match
      (
        skia_char_index_for_utf8_offset(offsets, metric.start),
        skia_char_index_for_utf8_offset(offsets, metric.end),
      ) {
      (Some(start), Some(end)) => {
        let start = start.clamp(min=0, max=chars.length())
        let end = end.clamp(min=start, max=chars.length())
        let ascent = metric.ascent.to_double().abs()
        let descent = metric.descent.to_double().abs()
        let metric_height = metric.height
          .to_double()
          .max(ascent + descent)
          .max(1.0)
        let top = metric.baseline.to_double() - ascent
        lines.push({
          line_index: lines.length(),
          text_range: @core.TextRange::new(start~, end~),
          origin: @core.Point::new(x=metric.left.to_double(), y=top.max(0.0)),
          size: @core.Size::new(
            width=metric.width.to_double().max(0.0),
            height=metric_height,
          ),
          baseline: metric.baseline.to_double(),
        })
      }
      _ => ()
    }
  }
  lines
}

///|
fn skia_paragraph_caret_rects(
  text : String,
  paragraph : @skia_native.Paragraph,
  lines : Array[@core.TextParagraphLineMetrics],
  offsets : Array[Int],
) -> Array[@core.Rect] {
  let chars = text.to_array()
  let carets : Array[@core.Rect] = []
  for index in 0..<(chars.length() + 1) {
    carets.push(skia_paragraph_caret_rect_at(paragraph, lines, offsets, index))
  }
  carets
}

///|
fn skia_paragraph_caret_rect_at(
  paragraph : @skia_native.Paragraph,
  lines : Array[@core.TextParagraphLineMetrics],
  offsets : Array[Int],
  index : Int,
) -> @core.Rect {
  let line = skia_paragraph_line_for_char_index(lines, index)
  let start_byte = offsets[index.clamp(min=0, max=offsets.length() - 1)]
  let end_byte = if index + 1 < offsets.length() {
    offsets[index + 1]
  } else {
    start_byte
  }
  let boxes = if end_byte > start_byte {
    paragraph.text_boxes_utf8(start_byte, end_byte)
  } else if start_byte > 0 {
    paragraph.text_boxes_utf8(offsets[(index - 1).max(0)], start_byte)
  } else {
    []
  }
  let x = if boxes.is_empty() {
    line.origin.x
  } else if end_byte > start_byte {
    boxes[0].left.to_double()
  } else {
    boxes[boxes.length() - 1].right.to_double()
  }
  @core.Rect::new(
    x~,
    y=line.origin.y,
    width=1.0,
    height=line.size.height.max(1.0),
  )
}

///|
fn skia_paragraph_line_for_char_index(
  lines : Array[@core.TextParagraphLineMetrics],
  index : Int,
) -> @core.TextParagraphLineMetrics {
  if lines.is_empty() {
    return {
      line_index: 0,
      text_range: @core.TextRange::collapsed(0),
      origin: @core.Point::new(x=0.0, y=0.0),
      size: @core.Size::new(width=0.0, height=1.0),
      baseline: 0.0,
    }
  }
  for line in lines {
    if index >= line.text_range.start && index <= line.text_range.end {
      return line
    }
  }
  lines[lines.length() - 1]
}

///|
fn skia_paragraph_visual_order_metadata(
  text : String,
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
  bidi_ready~ : Bool,
) -> @core.TextParagraphVisualOrderMetadata {
  let logical_clusters = skia_grapheme_cluster_texts(text)
  let boxes = skia_paragraph_cluster_boxes(logical_clusters, paragraph, offsets)
  let paragraph_bidi_observed = skia_paragraph_has_bidi_observation(boxes)
  let visual_clusters = if paragraph_bidi_observed {
    skia_bidi_visual_cluster_texts(logical_clusters)
  } else {
    logical_clusters
  }
  let visual_order_differs = !skia_string_arrays_equal(
    logical_clusters, visual_clusters,
  )
  {
    logical_text: skia_join_clusters(logical_clusters),
    visual_text: skia_join_clusters(visual_clusters),
    logical_cluster_count: logical_clusters.length(),
    visual_cluster_count: visual_clusters.length(),
    segment_count: boxes.length().max(1),
    glyph_count: logical_clusters.length(),
    visual_order_differs,
    bidi_visual_order_ready: bidi_ready &&
    paragraph_bidi_observed &&
    visual_order_differs,
  }
}

///|
fn skia_paragraph_cluster_boxes(
  clusters : Array[String],
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
) -> Array[SkiaParagraphClusterBox] {
  let boxes : Array[SkiaParagraphClusterBox] = []
  let mut char_index = 0
  for cluster in clusters {
    let cluster_length = cluster.to_array().length()
    let end_index = (char_index + cluster_length).min(offsets.length() - 1)
    if end_index > char_index {
      let text_boxes = paragraph.text_boxes_utf8(
        offsets[char_index],
        offsets[end_index],
      )
      let has_rect = !text_boxes.is_empty()
      let native_rtl = if has_rect {
        let directions = paragraph.text_box_directions_utf8(
          offsets[char_index],
          offsets[end_index],
        )
        if directions.is_empty() {
          false
        } else {
          directions[0] == 0
        }
      } else {
        false
      }
      boxes.push({ has_rect, rtl: native_rtl || skia_cluster_is_rtl(cluster) })
    }
    char_index = end_index
  }
  boxes
}

///|
fn skia_paragraph_has_bidi_observation(
  boxes : Array[SkiaParagraphClusterBox],
) -> Bool {
  let mut rect_count = 0
  let mut rtl_count = 0
  for box in boxes {
    if box.has_rect {
      rect_count = rect_count + 1
    }
    if box.rtl {
      rtl_count = rtl_count + 1
    }
  }
  rect_count > 0 && rtl_count > 0
}

///|
fn skia_paragraph_bidi_probe_ready(font : @core.FontSpec) -> Bool {
  if !@skia_native.skia_paragraph_available() {
    return false
  }
  let text = "ABC \u{05D0}\u{05D1}\u{05D2} 123"
  let bytes = @utf8.encode(text[:], bom=false)
  match
    @skia_native.Paragraph::layout_utf8(
      bytes,
      family_name=skia_primary_paragraph_family(font),
      size=Float::from_double(font.size),
      weight=font.weight,
      width=5,
      slant=skia_font_slant(font.style),
      max_width=400.0,
      left_to_right=true,
    ) {
    Some(paragraph) => {
      let offsets = skia_utf8_char_offsets(text)
      let logical = skia_grapheme_cluster_texts(text)
      let visual = skia_paragraph_visual_order_metadata(
        text,
        paragraph,
        offsets,
        bidi_ready=true,
      )
      visual.visual_order_differs &&
      visual.bidi_visual_order_ready &&
      visual.logical_cluster_count == logical.length() &&
      visual.visual_cluster_count == logical.length()
    }
    None => false
  }
}

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
  let clusters = skia_grapheme_cluster_texts(text)
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
  let mut previous = 0.0
  for index in 0..<carets.length() {
    if carets[index] < 0.0 || carets[index] < previous {
      carets[index] = previous
    } else {
      previous = carets[index]
    }
  }
  carets[carets.length() - 1] = run.width.max(carets[carets.length() - 1])
  Some(skia_stabilize_grapheme_cluster_carets(text, carets))
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
fn skia_measure_text_width(font : @skia_native.Font, text : String) -> Double {
  font.measure_text_utf8(@utf8.encode(text[:], bom=false)).to_double()
}

///|
fn skia_glyph_run(font : @skia_native.Font, text : String) -> SkiaGlyphRun {
  skia_glyph_run_with_shaper(font, text, use_shaper=true)
}

///|
fn skia_glyph_run_for_resolution(
  font : @skia_native.Font,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaGlyphRun {
  match resolution {
    SkiaFontResolution::SystemFontMgr => skia_glyph_run(font, text)
    SkiaFontResolution::EmptyTypeface =>
      skia_glyph_run_with_shaper(font, text, use_shaper=false)
  }
}

///|
fn skia_glyph_run_with_shaper(
  font : @skia_native.Font,
  text : String,
  use_shaper~ : Bool,
) -> SkiaGlyphRun {
  let bytes = @utf8.encode(text[:], bom=false)
  if use_shaper && @skia_native.skia_shaper_available() {
    match font.shape_text_utf8(bytes) {
      Some(run) => {
        let glyphs = run.glyphs()
        let positions = run.positions()
        if !glyphs.is_empty() && glyphs.length() == positions.length() {
          let clusters = run.clusters()
          if clusters.length() == glyphs.length() {
            return {
              glyphs,
              positions,
              clusters,
              width: run.advance().x.to_double(),
            }
          }
        }
      }
      None => ()
    }
  }
  let glyphs = font.text_to_glyphs_utf8(bytes)
  {
    glyphs,
    positions: font.glyph_positions(glyphs),
    clusters: [],
    width: font.measure_text_utf8(bytes).to_double(),
  }
}

///|
fn skia_glyph_run_has_visible_glyphs(run : SkiaGlyphRun) -> Bool {
  if run.glyphs.is_empty() || run.width <= 0.0 {
    return false
  }
  run.glyphs.any(glyph => glyph.to_int() != 0)
}

///|
fn skia_glyph_run_missing_glyph_count(run : SkiaGlyphRun) -> Int {
  let mut count = 0
  for glyph in run.glyphs {
    if glyph.to_int() == 0 {
      count = count + 1
    }
  }
  count
}

///|
fn skia_glyph_run_can_draw_text(run : SkiaGlyphRun) -> Bool {
  skia_glyph_run_has_visible_glyphs(run) &&
  skia_glyph_run_missing_glyph_count(run) == 0
}

///|
fn skia_glyph_run_improves_missing_glyphs(
  primary_run : SkiaGlyphRun,
  fallback_run : SkiaGlyphRun,
) -> Bool {
  if !skia_glyph_run_has_visible_glyphs(fallback_run) {
    return false
  }
  if !skia_glyph_run_has_visible_glyphs(primary_run) {
    return true
  }
  skia_glyph_run_missing_glyph_count(fallback_run) <
  skia_glyph_run_missing_glyph_count(primary_run)
}

///|
fn skia_fallback_draw_payload(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
  primary_run : SkiaGlyphRun,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  match skia_emoji_fallback_draw_font(font, text, resolution) {
    Some(emoji_font) =>
      match skia_complete_fallback_payload(emoji_font, text) {
        Some(payload) => return Some(payload)
        None => ()
      }
    None => ()
  }
  match skia_default_fallback_draw_font(font) {
    Some(fallback_font) =>
      skia_recovering_fallback_payload(fallback_font, text, primary_run)
    None => None
  }
}

///|
fn skia_complete_fallback_payload(
  font : @skia_native.Font,
  text : String,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run(font, text)
  if skia_glyph_run_can_draw_text(fallback_run) {
    Some((font, fallback_run))
  } else {
    None
  }
}

///|
fn skia_recovering_fallback_payload(
  font : @skia_native.Font,
  text : String,
  primary_run : SkiaGlyphRun,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run(font, text)
  if skia_glyph_run_can_draw_text(fallback_run) ||
    skia_glyph_run_improves_missing_glyphs(primary_run, fallback_run) {
    Some((font, fallback_run))
  } else {
    None
  }
}

///|
fn skia_emoji_fallback_draw_font(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> @skia_native.Font? {
  match resolution {
    SkiaFontResolution::SystemFontMgr =>
      if skia_text_contains_emoji_hint(text) {
        skia_system_emoji_font(font)
      } else {
        None
      }
    SkiaFontResolution::EmptyTypeface => None
  }
}

///|
fn skia_system_emoji_font(font : @core.FontSpec) -> @skia_native.Font? {
  match @skia_native.FontMgr::default() {
    Some(font_mgr) => {
      let emoji_font = @core.FontSpec::new(
        families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
        size=font.size,
        weight=font.weight,
        style=font.style,
      )
      match skia_typeface_from_font_mgr(font_mgr, emoji_font) {
        Some(typeface) =>
          @skia_native.Font::from_typeface(
            typeface,
            size=Float::from_double(font.size),
          )
        None => None
      }
    }
    None => None
  }
}

///|
fn skia_default_fallback_draw_font(font : @core.FontSpec) -> @skia_native.Font? {
  @skia_native.Font::default(size=Float::from_double(font.size))
}

///|
fn skia_text_contains_emoji_hint(text : String) -> Bool {
  for ch in text {
    if skia_codepoint_is_emoji_hint(ch.to_int()) {
      return true
    }
  }
  false
}

///|
fn skia_codepoint_is_emoji_hint(codepoint : Int) -> Bool {
  codepoint == 0x200D ||
  codepoint == 0xFE0F ||
  (codepoint >= 0x2600 && codepoint <= 0x27BF) ||
  (codepoint >= 0x1F000 && codepoint <= 0x1FAFF)
}

///|
fn skia_codepoint_is_hangul_cluster_codepoint(codepoint : Int) -> Bool {
  skia_codepoint_is_hangul_l(codepoint) ||
  skia_codepoint_is_hangul_v(codepoint) ||
  skia_codepoint_is_hangul_t(codepoint) ||
  skia_codepoint_is_hangul_lv(codepoint) ||
  skia_codepoint_is_hangul_lvt(codepoint)
}

///|
fn skia_codepoint_is_hangul_l(codepoint : Int) -> Bool {
  (codepoint >= 0x1100 && codepoint <= 0x115F) ||
  (codepoint >= 0xA960 && codepoint <= 0xA97C)
}

///|
fn skia_codepoint_is_hangul_v(codepoint : Int) -> Bool {
  (codepoint >= 0x1160 && codepoint <= 0x11A7) ||
  (codepoint >= 0xD7B0 && codepoint <= 0xD7C6)
}

///|
fn skia_codepoint_is_hangul_t(codepoint : Int) -> Bool {
  (codepoint >= 0x11A8 && codepoint <= 0x11FF) ||
  (codepoint >= 0xD7CB && codepoint <= 0xD7FB)
}

///|
fn skia_codepoint_is_hangul_lv(codepoint : Int) -> Bool {
  skia_codepoint_is_hangul_syllable(codepoint) && (codepoint - 0xAC00) % 28 == 0
}

///|
fn skia_codepoint_is_hangul_lvt(codepoint : Int) -> Bool {
  skia_codepoint_is_hangul_syllable(codepoint) && (codepoint - 0xAC00) % 28 != 0
}

///|
fn skia_codepoint_is_hangul_syllable(codepoint : Int) -> Bool {
  codepoint >= 0xAC00 && codepoint <= 0xD7A3
}

///|
fn skia_codepoint_is_hangul_compatibility_jamo(codepoint : Int) -> Bool {
  codepoint >= 0x3130 && codepoint <= 0x318F
}

///|
fn skia_codepoint_is_hebrew_script(codepoint : Int) -> Bool {
  codepoint >= 0x0590 && codepoint <= 0x05FF
}

///|
fn skia_codepoint_is_arabic_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0600 && codepoint <= 0x08FF) ||
  (codepoint >= 0xFB50 && codepoint <= 0xFDFF) ||
  (codepoint >= 0xFE70 && codepoint <= 0xFEFF)
}

///|
fn skia_codepoint_is_devanagari_script(codepoint : Int) -> Bool {
  codepoint >= 0x0900 && codepoint <= 0x097F
}

///|
fn skia_codepoint_is_thai_script(codepoint : Int) -> Bool {
  codepoint >= 0x0E00 && codepoint <= 0x0E7F
}

///|
fn skia_codepoint_is_lao_script(codepoint : Int) -> Bool {
  codepoint >= 0x0E80 && codepoint <= 0x0EFF
}

///|
fn skia_codepoint_is_sinhala_script(codepoint : Int) -> Bool {
  codepoint >= 0x0D80 && codepoint <= 0x0DFF
}

///|
fn skia_codepoint_is_khmer_script(codepoint : Int) -> Bool {
  codepoint >= 0x1780 && codepoint <= 0x17FF
}

///|
fn skia_codepoint_is_myanmar_script(codepoint : Int) -> Bool {
  codepoint >= 0x1000 && codepoint <= 0x109F
}

///|
fn skia_codepoint_is_latin_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0041 && codepoint <= 0x005A) ||
  (codepoint >= 0x0061 && codepoint <= 0x007A) ||
  (codepoint >= 0x00C0 && codepoint <= 0x024F) ||
  (codepoint >= 0x1E00 && codepoint <= 0x1EFF)
}

///|
fn skia_font_with_resolution_for_text(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> @skia_native.Font? {
  match resolution {
    SkiaFontResolution::EmptyTypeface =>
      @skia_native.Font::empty(size=Float::from_double(font.size))
    SkiaFontResolution::SystemFontMgr =>
      match skia_typeface_for_text(font, text) {
        Some(typeface) =>
          @skia_native.Font::from_typeface(
            typeface,
            size=Float::from_double(font.size),
          )
        None => @skia_native.Font::default(size=Float::from_double(font.size))
      }
  }
}

///|
fn skia_typeface_for_text(
  font : @core.FontSpec,
  text : String,
) -> @skia_native.Typeface? {
  match @skia_native.FontMgr::default() {
    Some(font_mgr) => skia_typeface_from_font_mgr_for_text(font_mgr, font, text)
    None => None
  }
}

///|
fn skia_typeface_from_font_mgr_for_text(
  font_mgr : @skia_native.FontMgr,
  font : @core.FontSpec,
  text : String,
) -> @skia_native.Typeface? {
  let request = skia_font_fallback_request(font, text)
  if !request.is_empty() {
    match font_mgr.match_fallback_request(request) {
      Some(typeface) => return Some(typeface)
      None => ()
    }
  }
  skia_typeface_from_font_mgr(font_mgr, font)
}

///|
fn skia_typeface_from_font_mgr(
  font_mgr : @skia_native.FontMgr,
  font : @core.FontSpec,
) -> @skia_native.Typeface? {
  for family in font.families.families {
    for family_name in skia_font_family_candidates(family) {
      match
        font_mgr.match_family_style(
          @utf8.encode(family_name[:], bom=false),
          weight=font.weight,
          width=5,
          slant=skia_font_slant(font.style),
        ) {
        Some(typeface) => return Some(typeface)
        None => ()
      }
    }
  }
  None
}

///|
fn skia_font_fallback_request(
  font : @core.FontSpec,
  text : String,
) -> @moui_skia.FontFallbackRequest {
  @moui_skia.FontFallbackRequest::new(
    families=skia_font_fallback_chain(font),
    bcp47=skia_font_fallback_language_bytes(text),
    character=skia_representative_fallback_codepoint(text),
    style=skia_font_style_request(font),
  )
}

///|
fn skia_font_fallback_language_bytes(text : String) -> Array[Bytes] {
  let tags = skia_font_fallback_language_tags(text)
  let bytes : Array[Bytes] = []
  for tag in tags {
    bytes.push(@utf8.encode(tag[:], bom=false))
  }
  bytes
}

///|
fn skia_font_fallback_language_tags(text : String) -> Array[String] {
  let tags : Array[String] = []
  let representative = skia_representative_fallback_codepoint(text)
  match skia_script_language_tag_for_codepoint(representative) {
    Some(tag) => skia_push_language_tag(tags, tag)
    None => ()
  }
  if representative > 0 {
    skia_push_language_tag(tags, "en")
  }
  tags
}

///|
fn skia_push_language_tag(tags : Array[String], tag : String) -> Unit {
  if tag != "" && !tags.contains(tag) {
    tags.push(tag)
  }
}

///|
fn skia_script_language_tag_for_codepoint(codepoint : Int) -> String? {
  if codepoint <= 0 {
    None
  } else if skia_codepoint_is_emoji_hint(codepoint) {
    Some("und-Zsye")
  } else if skia_codepoint_is_kana(codepoint) {
    Some("ja")
  } else if skia_codepoint_is_cjk_ideograph(codepoint) {
    Some("zh-Hans")
  } else if skia_codepoint_is_hangul_cluster_codepoint(codepoint) ||
    skia_codepoint_is_hangul_compatibility_jamo(codepoint) {
    Some("ko")
  } else if skia_codepoint_is_hebrew_script(codepoint) {
    Some("he")
  } else if skia_codepoint_is_arabic_script(codepoint) {
    Some("ar")
  } else if skia_codepoint_is_devanagari_script(codepoint) {
    Some("hi")
  } else if skia_codepoint_is_thai_script(codepoint) {
    Some("th")
  } else if skia_codepoint_is_lao_script(codepoint) {
    Some("lo")
  } else if skia_codepoint_is_sinhala_script(codepoint) {
    Some("si")
  } else if skia_codepoint_is_khmer_script(codepoint) {
    Some("km")
  } else if skia_codepoint_is_myanmar_script(codepoint) {
    Some("my")
  } else if skia_codepoint_is_latin_script(codepoint) {
    Some("en")
  } else {
    None
  }
}

///|
fn skia_font_fallback_chain(
  font : @core.FontSpec,
) -> @moui_skia.FontFallbackChain {
  let families = skia_preflight_family_candidates(font)
  let primary_family = if families.is_empty() {
    b"system-ui"
  } else {
    @utf8.encode(families[0][:], bom=false)
  }
  let fallback_families : Array[Bytes] = []
  if families.length() > 1 {
    for index in 1..<families.length() {
      fallback_families.push(@utf8.encode(families[index][:], bom=false))
    }
  }
  @moui_skia.FontFallbackChain::new(primary_family~, fallback_families~)
}

///|
fn skia_font_style_request(
  font : @core.FontSpec,
) -> @moui_skia.FontStyleRequest {
  @moui_skia.FontStyleRequest::new(
    weight=font.weight,
    width=5,
    slant=skia_font_slant(font.style),
  )
}

///|
fn skia_font_family_candidates(family : @core.FontFamily) -> Array[String] {
  match family {
    Name(name) => [name]
    SystemUi | UiSansSerif | SansSerif => skia_system_sans_families()
    UiSerif | Serif => skia_serif_families()
    UiMonospace | Monospace => skia_monospace_families()
    Emoji => skia_emoji_families()
    Math => skia_serif_families()
    FangSong => skia_fangsong_families()
  }
}

///|
fn skia_system_sans_families() -> Array[String] {
  [
    "Helvetica Neue", "Segoe UI", "Arial", "DejaVu Sans", "Noto Sans", "Liberation Sans",
  ]
}

///|
fn skia_serif_families() -> Array[String] {
  [
    "Times New Roman", "Georgia", "DejaVu Serif", "Noto Serif", "Liberation Serif",
  ]
}

///|
fn skia_monospace_families() -> Array[String] {
  [
    "Menlo", "Consolas", "Courier New", "DejaVu Sans Mono", "Noto Sans Mono", "Liberation Mono",
  ]
}

///|
fn skia_emoji_families() -> Array[String] {
  ["Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"]
}

///|
fn skia_fangsong_families() -> Array[String] {
  ["STFangsong", "FangSong", "FangSong SC", "SimSun"]
}

///|
fn skia_font_slant(style : @core.FontStyle) -> Int {
  match style {
    Normal => 0
    Italic => 1
  }
}
