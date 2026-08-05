///|
pub struct SkiaTextVisualOrderDiagnostic {
  priv logical_text : String
  priv visual_text : String
  priv logical_cluster_count : Int
  priv visual_cluster_count : Int
  priv segment_count : Int
  priv glyph_count : Int
  priv width : Double
  priv visual_order_differs : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct SkiaTextSelectionGeometryDiagnostic {
  priv text : String
  priv selection_range : @core.TextRange
  priv selection_rect_count : Int
  priv selected_line_count : Int
  priv line_count : Int
  priv hit_test_offset : Int
  priv hit_test_line_index : Int
  priv hit_test_inside : Bool
  priv visual_order_differs : Bool
  priv visual_segment_count : Int
  priv bidi_visual_order_observed : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct SkiaEmojiFontFallbackDiagnostic {
  priv text : String
  priv text_system_id : String
  priv font_family : String
  priv font_source : String
  priv resolved_font_name : String
  priv fallback_language_tags : Array[String]
  priv fallback_script_tag : String
  priv fallback_language_tag_count : Int
  priv fallback_request_language_count : Int
  priv shaper : String
  priv glyph_format : String
  priv glyph_key : String
  priv glyph_count : Int
  priv cluster_count : Int
  priv glyph_width : Int
  priv glyph_height : Int
  priv resolved_missing_glyph_count : Int
  priv fallback_character : Int
  priv emoji_hint : Bool
  priv emoji_fallback_attempted : Bool
  priv fallback_request_ready : Bool
  priv missing_glyph_recovery_ready : Bool
  priv deterministic_color_emoji_ready : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaTextVisualOrderDiagnostic::logical_text(
  self : SkiaTextVisualOrderDiagnostic,
) -> String {
  self.logical_text
}

///|
pub fn SkiaTextVisualOrderDiagnostic::visual_text(
  self : SkiaTextVisualOrderDiagnostic,
) -> String {
  self.visual_text
}

///|
pub fn SkiaTextVisualOrderDiagnostic::logical_cluster_count(
  self : SkiaTextVisualOrderDiagnostic,
) -> Int {
  self.logical_cluster_count
}

///|
pub fn SkiaTextVisualOrderDiagnostic::visual_cluster_count(
  self : SkiaTextVisualOrderDiagnostic,
) -> Int {
  self.visual_cluster_count
}

///|
pub fn SkiaTextVisualOrderDiagnostic::segment_count(
  self : SkiaTextVisualOrderDiagnostic,
) -> Int {
  self.segment_count
}

///|
pub fn SkiaTextVisualOrderDiagnostic::glyph_count(
  self : SkiaTextVisualOrderDiagnostic,
) -> Int {
  self.glyph_count
}

///|
pub fn SkiaTextVisualOrderDiagnostic::width(
  self : SkiaTextVisualOrderDiagnostic,
) -> Double {
  self.width
}

///|
pub fn SkiaTextVisualOrderDiagnostic::visual_order_differs(
  self : SkiaTextVisualOrderDiagnostic,
) -> Bool {
  self.visual_order_differs
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::text(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> String {
  self.text
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::selection_range(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> @core.TextRange {
  self.selection_range
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::selection_rect_count(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Int {
  self.selection_rect_count
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::selected_line_count(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Int {
  self.selected_line_count
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::line_count(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Int {
  self.line_count
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::hit_test_offset(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Int {
  self.hit_test_offset
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::hit_test_line_index(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Int {
  self.hit_test_line_index
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::hit_test_inside(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Bool {
  self.hit_test_inside
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::visual_order_differs(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Bool {
  self.visual_order_differs
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::visual_segment_count(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Int {
  self.visual_segment_count
}

///|
pub fn SkiaTextSelectionGeometryDiagnostic::bidi_visual_order_observed(
  self : SkiaTextSelectionGeometryDiagnostic,
) -> Bool {
  self.bidi_visual_order_observed
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::text(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.text
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::text_system_id(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.text_system_id
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::font_family(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.font_family
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::font_source(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.font_source
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::resolved_font_name(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.resolved_font_name
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::fallback_language_tags(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Array[String] {
  self.fallback_language_tags
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::fallback_script_tag(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.fallback_script_tag
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::fallback_language_tag_count(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_language_tag_count
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::fallback_request_language_count(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_request_language_count
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::shaper(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.shaper
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::glyph_format(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.glyph_format
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::glyph_key(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> String {
  self.glyph_key
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::glyph_count(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.glyph_count
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::cluster_count(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.cluster_count
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::glyph_width(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.glyph_width
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::glyph_height(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.glyph_height
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::resolved_missing_glyph_count(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.resolved_missing_glyph_count
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::fallback_character(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_character
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::emoji_hint(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  self.emoji_hint
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::emoji_fallback_attempted(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  self.emoji_fallback_attempted
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::fallback_request_ready(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  self.fallback_request_ready
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::missing_glyph_recovery_ready(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  self.missing_glyph_recovery_ready
}

///|
pub fn SkiaEmojiFontFallbackDiagnostic::deterministic_color_emoji_ready(
  self : SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  self.deterministic_color_emoji_ready
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
  let logical_clusters = @render_common.text_grapheme_clusters(text)
  let visual_clusters = @render_common.text_bidi_visual_clusters(text)
  match skia_resolved_text_layout_for_resolution(font, text, font_resolution) {
    Some(layout) => {
      let mut glyph_count = 0
      for segment in layout.segments {
        glyph_count += segment.glyph_run.glyphs.length()
      }
      Some({
        logical_text: @render_common.text_join_clusters(logical_clusters),
        visual_text: @render_common.text_join_clusters(visual_clusters),
        logical_cluster_count: logical_clusters.length(),
        visual_cluster_count: visual_clusters.length(),
        segment_count: layout.segments.length(),
        glyph_count,
        width: layout.width,
        visual_order_differs: !@render_common.text_string_arrays_equal(
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
  let normalized = @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
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
        resolved_font_name: skia_emoji_resolved_font_name(),
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
        cluster_count: @render_common.text_grapheme_clusters(text).length(),
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
        deterministic_color_emoji_ready: skia_emoji_typeface_has_color_glyphs(),
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
fn skia_emoji_typeface_has_color_glyphs() -> Bool {
  match @skia_native.FontMgr::default() {
    None => false
    Some(mgr) =>
      match mgr.match_family_style_character(b"", [], 0x1F469) {
        None => false
        Some(typeface) => typeface.has_color_glyphs()
      }
  }
}

///|
fn skia_emoji_glyph_format_label() -> String {
  if skia_emoji_typeface_has_color_glyphs() {
    "rgba"
  } else {
    "alpha"
  }
}

///|
fn skia_emoji_resolved_font_name() -> String {
  match @skia_native.FontMgr::default() {
    None => "no-fontmgr"
    Some(mgr) =>
      match mgr.match_family_style_character(b"", [], 0x1F469) {
        None => "no-match"
        Some(typeface) =>
          match typeface.family_name() {
            None => "unnamed"
            Some(name) => name.to_string()
          }
      }
  }
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
