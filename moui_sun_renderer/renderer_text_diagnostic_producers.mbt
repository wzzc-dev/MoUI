///|
pub fn SunRasterRenderer::text_maturity_diagnostic(
  self : SunRasterRenderer,
  text? : String = "MoUI Sun text diagnostics",
  font? : @core.FontSpec = @core.FontSpec::new(size=14.0),
  max_width? : Double = 96.0,
) -> SunTextMaturityDiagnostic {
  let system = self.text_system()
  let layout = system.layout_paragraph(
    @core.TextLayoutInput::new(text~, font~, max_width~),
  )
  let selection = sun_text_diagnostic_selection_range(layout)
  let selection_rects = layout.selection_rects(selection)
  let hit = sun_text_diagnostic_hit_test(layout, max_width~)
  let metadata = layout.metadata
  let registered_font_count = self.text_system.font_count()
  let paragraph_layout_ready = metadata.paragraph_layout_available &&
    layout.line_count() > 0 &&
    layout.size.height > 0.0
  let line_metrics_ready = metadata.line_metrics_available &&
    layout.lines.length() == layout.line_count()
  let selection_rects_ready = metadata.selection_rects_available &&
    selection_rects.length() > 0
  let hit_test_ready = metadata.hit_test_available && hit.is_inside
  let color_emoji_ready = false
  let unicode_17_grapheme_boundary_ready = true
  let ready_count = sun_text_ready_count([
    registered_font_count > 0,
    paragraph_layout_ready,
    line_metrics_ready,
    selection_rects_ready,
    hit_test_ready,
    metadata.bidi_visual_order_ready,
    unicode_17_grapheme_boundary_ready,
  ])
  let gap_count = sun_text_gap_count([
    metadata.bidi_visual_order_ready,
    metadata.native_paragraph_ready,
    color_emoji_ready,
  ])
  {
    text_system_id: system.id(),
    registered_font_count,
    paragraph_line_count: layout.line_count(),
    selection_rect_count: selection_rects.length(),
    hit_test_inside: hit.is_inside,
    paragraph_layout_ready,
    line_metrics_ready,
    selection_rects_ready,
    hit_test_ready,
    bidi_visual_order_ready: metadata.bidi_visual_order_ready,
    native_paragraph_ready: metadata.native_paragraph_ready,
    color_emoji_ready,
    unicode_17_grapheme_boundary_ready,
    ready_count,
    gap_count,
  }
}

///|
pub fn SunRasterRenderer::emoji_font_fallback_diagnostic(
  self : SunRasterRenderer,
  text? : String = "\u{1F600}",
  font? : @core.FontSpec = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
    size=32.0,
  ),
) -> SunEmojiFontFallbackDiagnostic {
  let system = self.text_system()
  let faces = self.resolved_faces(font)
  let plan = @sun_text.plan_font_fallback(faces, text)
  let spans = plan.get_spans()
  let mut fallback_span_count = 0
  for span in spans {
    if !span.is_missing() && span.get_face_index() > 0 {
      fallback_span_count += 1
    }
  }
  let missing_char_count = plan.get_missing_char_count()
  let covered_char_count = (plan.get_char_count() - missing_char_count).max(0)
  let emoji_hint = sun_text_contains_emoji_hint(text)
  let registered_font_fallback_ready = faces.length() > 1 &&
    fallback_span_count > 0 &&
    missing_char_count == 0
  let missing_glyph_recovery_ready = emoji_hint &&
    registered_font_fallback_ready &&
    covered_char_count == plan.get_char_count()
  let glyph_format = "coverage-mask"
  let font_source = "sun-registered-font-chain"
  let shaper = "font-fallback-plan"
  let fallback_character = @render_common.representative_fallback_codepoint(
    text,
    skip_joiners=true,
  )
  let resolved_fallback_face_index = @sun_text.select_font_face_index_for_char(
    faces, fallback_character,
  )
  let resolved_font_name = sun_resolved_face_label(resolved_fallback_face_index)
  let fallback_language_tags = sun_font_fallback_language_tags(text)
  let fallback_script_tag = sun_fallback_script_tag(fallback_language_tags)
  let fallback_request_language_count = fallback_language_tags.length()
  let glyph_count = covered_char_count
  let cluster_count = @core.TextGraphemeBoundaries::new(text~).cluster_count()
  let measured = system.measure_text(@core.TextLayoutInput::new(text~, font~))
  let emoji_fallback_attempted = emoji_hint && faces.length() > 0
  let fallback_request_ready = fallback_character > 0 &&
    faces.length() > 0 &&
    sun_first_font_family_label(font).length() > 0 &&
    fallback_request_language_count == fallback_language_tags.length()
  {
    text,
    text_system_id: system.id(),
    requested_font_family: sun_first_font_family_label(font),
    font_source,
    shaper,
    resolved_fallback_face_index,
    resolved_font_name,
    fallback_language_tags,
    fallback_script_tag,
    fallback_language_tag_count: fallback_language_tags.length(),
    fallback_request_language_count,
    registered_font_count: self.text_system.font_count(),
    resolved_face_count: faces.length(),
    span_count: plan.span_count(),
    fallback_span_count,
    missing_char_count,
    covered_char_count,
    emoji_hint,
    registered_font_fallback_ready,
    missing_glyph_recovery_ready,
    deterministic_color_emoji_ready: false,
    glyph_format,
    glyph_key: sun_emoji_glyph_key(
      font_source,
      system.id(),
      shaper,
      resolved_fallback_face_index,
      fallback_script_tag,
      fallback_language_tags,
      fallback_request_language_count,
      sun_first_font_family_label(font),
      self.text_system.font_count(),
      faces.length(),
      fallback_character,
      glyph_format,
    ),
    glyph_count,
    cluster_count,
    glyph_width: sun_positive_pixel_extent(measured.size.width),
    glyph_height: sun_positive_pixel_extent(measured.size.height),
    resolved_missing_glyph_count: missing_char_count,
    fallback_character,
    emoji_fallback_attempted,
    fallback_request_ready,
  }
}

///|
pub fn SunRasterRenderer::text_visual_order_diagnostic(
  self : SunRasterRenderer,
  text : String,
  font? : @core.FontSpec = @core.FontSpec::new(size=20.0, weight=500),
  max_width? : Double = 1000000000.0,
) -> SunTextVisualOrderDiagnostic? {
  if text == "" {
    return None
  }
  let layout = self
    .text_system()
    .layout_paragraph(@core.TextLayoutInput::new(text~, font~, max_width~))
  let visual = layout.visual_order
  Some({
    logical_text: visual.logical_text,
    visual_text: visual.visual_text,
    logical_cluster_count: visual.logical_cluster_count,
    visual_cluster_count: visual.visual_cluster_count,
    segment_count: visual.segment_count,
    glyph_count: visual.glyph_count,
    width: layout.size.width,
    visual_order_differs: visual.visual_order_differs,
    bidi_visual_order_ready: visual.bidi_visual_order_ready,
  })
}

///|
pub fn SunRasterRenderer::text_selection_geometry_diagnostic(
  self : SunRasterRenderer,
  text? : String = "MoUI Sun text diagnostics",
  selection? : @core.TextRange? = None,
  font? : @core.FontSpec = @core.FontSpec::new(size=14.0),
  max_width? : Double = 96.0,
) -> SunTextSelectionGeometryDiagnostic {
  let system = self.text_system()
  let layout = system.layout_paragraph(
    @core.TextLayoutInput::new(text~, font~, max_width~),
  )
  let range = match selection {
    Some(selection) => selection.normalized()
    None => sun_text_diagnostic_selection_range(layout)
  }
  let range = @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    range,
  )
  let selection_rects = layout.selection_rects(range)
  let hit = sun_text_diagnostic_hit_test(layout, max_width~)
  let bidi_ready = layout.metadata.bidi_visual_order_ready
  let visual_order = layout.visual_order
  {
    text,
    selection_range: range,
    selection_rect_count: selection_rects.length(),
    selected_line_count: sun_selected_line_count(layout, range),
    line_count: layout.line_count(),
    hit_test_offset: hit.offset,
    hit_test_line_index: hit.line_index,
    hit_test_inside: hit.is_inside,
    bidi_visual_order_ready: bidi_ready,
    visual_order_differs: visual_order.visual_order_differs,
    visual_segment_count: visual_order.segment_count,
    bidi_visual_order_observed: bidi_ready &&
    visual_order.bidi_visual_order_ready &&
    visual_order.visual_order_differs &&
    visual_order.logical_cluster_count == visual_order.visual_cluster_count &&
    visual_order.segment_count >= 3 &&
    visual_order.glyph_count >= 1,
  }
}

///|
fn sun_backend_text_maturity_summary() -> String {
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
    SunPresentTarget::new(description="sun-backend-info-text-maturity", present=_ => {
      true
    }),
  ) catch {
    err => return "Sun text maturity audit pending: \{err.message()}"
  }
  renderer.text_maturity_diagnostic(text="A A", max_width=12.0).summary()
}

///|
fn sun_backend_info_description(surface_summary : String) -> String {
  "Sun CPU raster over moui_sun graphics/text, " +
  surface_summary +
  ", " +
  sun_backend_text_maturity_summary() +
  ", cached-layer diagnostics, async image lifecycle, structured unsupported-command diagnostics, and platform pixel presenters."
}

///|
fn sun_text_diagnostic_selection_range(
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
fn sun_text_diagnostic_hit_test(
  layout : @core.TextParagraphLayoutResult,
  max_width~ : Double,
) -> @core.TextParagraphHitTestResult {
  if layout.lines.is_empty() {
    layout.hit_test(@core.Point::new(x=0.0, y=0.0))
  } else {
    let line = if layout.lines.length() > 1 {
      layout.lines[1]
    } else {
      layout.lines[0]
    }
    layout.hit_test(
      @core.Point::new(
        x=(line.origin.x + line.size.width * 0.5).min(max_width),
        y=line.origin.y + line.size.height * 0.5,
      ),
    )
  }
}

///|
fn sun_selected_line_count(
  layout : @core.TextParagraphLayoutResult,
  range : @core.TextRange,
) -> Int {
  let normalized = range.normalized()
  let mut count = 0
  for line in layout.lines {
    let line_range = line.text_range.normalized()
    let overlaps = normalized.start < line_range.end &&
      normalized.end > line_range.start
    if overlaps ||
      (
        normalized.is_collapsed() &&
        normalized.start >= line_range.start &&
        normalized.start <= line_range.end
      ) {
      count += 1
    }
  }
  count
}

///|
fn sun_first_font_family_label(font : @core.FontSpec) -> String {
  if font.families.families.length() == 0 {
    return "system-ui"
  }
  sun_font_family_label(font.families.families[0])
}

///|
fn sun_font_family_label(family : @core.FontFamily) -> String {
  match family {
    @core.FontFamily::Name(name) => name
    _ => family.css_name()
  }
}

///|
fn sun_text_contains_emoji_hint(text : String) -> Bool {
  for ch in text {
    if @render_common.codepoint_is_emoji_hint(ch.to_int()) {
      return true
    }
  }
  false
}

///|
fn sun_emoji_glyph_key(
  font_source : String,
  text_system_id : String,
  shaper : String,
  resolved_fallback_face_index : Int,
  fallback_script_tag : String,
  fallback_language_tags : Array[String],
  fallback_request_language_count : Int,
  requested_font_family : String,
  registered_font_count : Int,
  resolved_face_count : Int,
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
  "\{font_source}|\{text_system_id}|\{shaper}|resolved-face=\{resolved_fallback_face_index}|\{script_key}|langs=\{fallback_request_language_count}|\{language_key}|family=\{requested_font_family}|registered=\{registered_font_count}|resolved=\{resolved_face_count}|emoji-u+\{fallback_character}|format=\{glyph_format}"
}

///|
fn sun_resolved_face_label(face_index : Int) -> String {
  if face_index < 0 {
    "missing"
  } else {
    "sun-registered-face-\{face_index}"
  }
}

///|
fn sun_positive_pixel_extent(value : Double) -> Int {
  value.ceil().to_int().max(1)
}

///|
fn sun_font_fallback_language_tags(text : String) -> Array[String] {
  let tags : Array[String] = []
  let representative = @render_common.representative_fallback_codepoint(
    text,
    skip_joiners=true,
  )
  match sun_script_language_tag_for_codepoint(representative) {
    Some(tag) => sun_push_language_tag(tags, tag)
    None => ()
  }
  if representative > 0 {
    sun_push_language_tag(tags, "en")
  }
  tags
}

///|
fn sun_fallback_script_tag(tags : Array[String]) -> String {
  if tags.is_empty() {
    ""
  } else {
    tags[0]
  }
}

///|
fn sun_script_language_tag_for_codepoint(codepoint : Int) -> String? {
  if codepoint <= 0 {
    None
  } else if @render_common.codepoint_is_emoji_hint(codepoint) {
    Some("und-Zsye")
  } else if @render_common.codepoint_is_kana(codepoint) {
    Some("ja")
  } else if @render_common.codepoint_is_cjk_ideograph(codepoint) {
    Some("zh-Hans")
  } else if @render_common.codepoint_is_hangul_cluster_codepoint(codepoint) ||
    @render_common.codepoint_is_hangul_compatibility_jamo(codepoint) {
    Some("ko")
  } else if sun_codepoint_is_hebrew_script(codepoint) {
    Some("he")
  } else if sun_codepoint_is_arabic_script(codepoint) {
    Some("ar")
  } else if sun_codepoint_is_devanagari_script(codepoint) {
    Some("hi")
  } else if sun_codepoint_is_thai_script(codepoint) {
    Some("th")
  } else if sun_codepoint_is_lao_script(codepoint) {
    Some("lo")
  } else if sun_codepoint_is_sinhala_script(codepoint) {
    Some("si")
  } else if sun_codepoint_is_khmer_script(codepoint) {
    Some("km")
  } else if sun_codepoint_is_myanmar_script(codepoint) {
    Some("my")
  } else if sun_codepoint_is_latin_script(codepoint) {
    Some("en")
  } else {
    None
  }
}

///|
fn sun_push_language_tag(tags : Array[String], tag : String) -> Unit {
  if tag != "" && !tags.contains(tag) {
    tags.push(tag)
  }
}

///|
fn sun_codepoint_is_hebrew_script(codepoint : Int) -> Bool {
  codepoint >= 0x0590 && codepoint <= 0x05FF
}

///|
fn sun_codepoint_is_arabic_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0600 && codepoint <= 0x08FF) ||
  (codepoint >= 0xFB50 && codepoint <= 0xFDFF) ||
  (codepoint >= 0xFE70 && codepoint <= 0xFEFF)
}

///|
fn sun_codepoint_is_devanagari_script(codepoint : Int) -> Bool {
  codepoint >= 0x0900 && codepoint <= 0x097F
}

///|
fn sun_codepoint_is_thai_script(codepoint : Int) -> Bool {
  codepoint >= 0x0E00 && codepoint <= 0x0E7F
}

///|
fn sun_codepoint_is_lao_script(codepoint : Int) -> Bool {
  codepoint >= 0x0E80 && codepoint <= 0x0EFF
}

///|
fn sun_codepoint_is_sinhala_script(codepoint : Int) -> Bool {
  codepoint >= 0x0D80 && codepoint <= 0x0DFF
}

///|
fn sun_codepoint_is_khmer_script(codepoint : Int) -> Bool {
  codepoint >= 0x1780 && codepoint <= 0x17FF
}

///|
fn sun_codepoint_is_myanmar_script(codepoint : Int) -> Bool {
  codepoint >= 0x1000 && codepoint <= 0x109F
}

///|
fn sun_codepoint_is_latin_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0041 && codepoint <= 0x005A) ||
  (codepoint >= 0x0061 && codepoint <= 0x007A) ||
  (codepoint >= 0x00C0 && codepoint <= 0x024F) ||
  (codepoint >= 0x1E00 && codepoint <= 0x1EFF)
}

///|
fn sun_text_ready_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if value {
      count += 1
    }
  }
  count
}

///|
fn sun_text_gap_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if !value {
      count += 1
    }
  }
  count
}
