///|
pub struct SunTextMaturityDiagnostic {
  priv text_system_id : String
  priv registered_font_count : Int
  priv paragraph_line_count : Int
  priv selection_rect_count : Int
  priv hit_test_inside : Bool
  priv paragraph_layout_ready : Bool
  priv line_metrics_ready : Bool
  priv selection_rects_ready : Bool
  priv hit_test_ready : Bool
  priv bidi_visual_order_ready : Bool
  priv native_paragraph_ready : Bool
  priv color_emoji_ready : Bool
  priv unicode_17_grapheme_boundary_ready : Bool
  priv ready_count : Int
  priv gap_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct SunTextVisualOrderDiagnostic {
  priv logical_text : String
  priv visual_text : String
  priv logical_cluster_count : Int
  priv visual_cluster_count : Int
  priv segment_count : Int
  priv glyph_count : Int
  priv width : Double
  priv visual_order_differs : Bool
  priv bidi_visual_order_ready : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct SunTextSelectionGeometryDiagnostic {
  priv text : String
  priv selection_range : @core.TextRange
  priv selection_rect_count : Int
  priv selected_line_count : Int
  priv line_count : Int
  priv hit_test_offset : Int
  priv hit_test_line_index : Int
  priv hit_test_inside : Bool
  priv bidi_visual_order_ready : Bool
  priv visual_order_differs : Bool
  priv visual_segment_count : Int
  priv bidi_visual_order_observed : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct SunEmojiFontFallbackDiagnostic {
  priv text : String
  priv text_system_id : String
  priv requested_font_family : String
  priv font_source : String
  priv shaper : String
  priv resolved_fallback_face_index : Int
  priv resolved_font_name : String
  priv fallback_language_tags : Array[String]
  priv fallback_script_tag : String
  priv fallback_language_tag_count : Int
  priv fallback_request_language_count : Int
  priv registered_font_count : Int
  priv resolved_face_count : Int
  priv span_count : Int
  priv fallback_span_count : Int
  priv missing_char_count : Int
  priv covered_char_count : Int
  priv emoji_hint : Bool
  priv registered_font_fallback_ready : Bool
  priv missing_glyph_recovery_ready : Bool
  priv deterministic_color_emoji_ready : Bool
  priv glyph_format : String
  priv glyph_key : String
  priv glyph_count : Int
  priv cluster_count : Int
  priv glyph_width : Int
  priv glyph_height : Int
  priv resolved_missing_glyph_count : Int
  priv fallback_character : Int
  priv emoji_fallback_attempted : Bool
  priv fallback_request_ready : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn SunTextMaturityDiagnostic::text_system_id(
  self : SunTextMaturityDiagnostic,
) -> String {
  self.text_system_id
}

///|
pub fn SunTextMaturityDiagnostic::registered_font_count(
  self : SunTextMaturityDiagnostic,
) -> Int {
  self.registered_font_count
}

///|
pub fn SunTextMaturityDiagnostic::paragraph_line_count(
  self : SunTextMaturityDiagnostic,
) -> Int {
  self.paragraph_line_count
}

///|
pub fn SunTextMaturityDiagnostic::selection_rect_count(
  self : SunTextMaturityDiagnostic,
) -> Int {
  self.selection_rect_count
}

///|
pub fn SunTextMaturityDiagnostic::hit_test_inside(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.hit_test_inside
}

///|
pub fn SunTextMaturityDiagnostic::paragraph_layout_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.paragraph_layout_ready
}

///|
pub fn SunTextMaturityDiagnostic::line_metrics_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.line_metrics_ready
}

///|
pub fn SunTextMaturityDiagnostic::selection_rects_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.selection_rects_ready
}

///|
pub fn SunTextMaturityDiagnostic::hit_test_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.hit_test_ready
}

///|
pub fn SunTextMaturityDiagnostic::bidi_visual_order_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.bidi_visual_order_ready
}

///|
pub fn SunTextMaturityDiagnostic::native_paragraph_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.native_paragraph_ready
}

///|
pub fn SunTextMaturityDiagnostic::color_emoji_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.color_emoji_ready
}

///|
pub fn SunTextMaturityDiagnostic::unicode_17_grapheme_boundary_ready(
  self : SunTextMaturityDiagnostic,
) -> Bool {
  self.unicode_17_grapheme_boundary_ready
}

///|
pub fn SunTextMaturityDiagnostic::ready_count(
  self : SunTextMaturityDiagnostic,
) -> Int {
  self.ready_count
}

///|
pub fn SunTextMaturityDiagnostic::gap_count(
  self : SunTextMaturityDiagnostic,
) -> Int {
  self.gap_count
}

///|
pub fn SunTextVisualOrderDiagnostic::logical_text(
  self : SunTextVisualOrderDiagnostic,
) -> String {
  self.logical_text
}

///|
pub fn SunTextVisualOrderDiagnostic::visual_text(
  self : SunTextVisualOrderDiagnostic,
) -> String {
  self.visual_text
}

///|
pub fn SunTextVisualOrderDiagnostic::logical_cluster_count(
  self : SunTextVisualOrderDiagnostic,
) -> Int {
  self.logical_cluster_count
}

///|
pub fn SunTextVisualOrderDiagnostic::visual_cluster_count(
  self : SunTextVisualOrderDiagnostic,
) -> Int {
  self.visual_cluster_count
}

///|
pub fn SunTextVisualOrderDiagnostic::segment_count(
  self : SunTextVisualOrderDiagnostic,
) -> Int {
  self.segment_count
}

///|
pub fn SunTextVisualOrderDiagnostic::glyph_count(
  self : SunTextVisualOrderDiagnostic,
) -> Int {
  self.glyph_count
}

///|
pub fn SunTextVisualOrderDiagnostic::width(
  self : SunTextVisualOrderDiagnostic,
) -> Double {
  self.width
}

///|
pub fn SunTextVisualOrderDiagnostic::visual_order_differs(
  self : SunTextVisualOrderDiagnostic,
) -> Bool {
  self.visual_order_differs
}

///|
pub fn SunTextVisualOrderDiagnostic::bidi_visual_order_ready(
  self : SunTextVisualOrderDiagnostic,
) -> Bool {
  self.bidi_visual_order_ready
}

///|
pub fn SunTextSelectionGeometryDiagnostic::text(
  self : SunTextSelectionGeometryDiagnostic,
) -> String {
  self.text
}

///|
pub fn SunTextSelectionGeometryDiagnostic::selection_range(
  self : SunTextSelectionGeometryDiagnostic,
) -> @core.TextRange {
  self.selection_range
}

///|
pub fn SunTextSelectionGeometryDiagnostic::selection_rect_count(
  self : SunTextSelectionGeometryDiagnostic,
) -> Int {
  self.selection_rect_count
}

///|
pub fn SunTextSelectionGeometryDiagnostic::selected_line_count(
  self : SunTextSelectionGeometryDiagnostic,
) -> Int {
  self.selected_line_count
}

///|
pub fn SunTextSelectionGeometryDiagnostic::line_count(
  self : SunTextSelectionGeometryDiagnostic,
) -> Int {
  self.line_count
}

///|
pub fn SunTextSelectionGeometryDiagnostic::hit_test_offset(
  self : SunTextSelectionGeometryDiagnostic,
) -> Int {
  self.hit_test_offset
}

///|
pub fn SunTextSelectionGeometryDiagnostic::hit_test_line_index(
  self : SunTextSelectionGeometryDiagnostic,
) -> Int {
  self.hit_test_line_index
}

///|
pub fn SunTextSelectionGeometryDiagnostic::hit_test_inside(
  self : SunTextSelectionGeometryDiagnostic,
) -> Bool {
  self.hit_test_inside
}

///|
pub fn SunTextSelectionGeometryDiagnostic::bidi_visual_order_ready(
  self : SunTextSelectionGeometryDiagnostic,
) -> Bool {
  self.bidi_visual_order_ready
}

///|
pub fn SunTextSelectionGeometryDiagnostic::visual_order_differs(
  self : SunTextSelectionGeometryDiagnostic,
) -> Bool {
  self.visual_order_differs
}

///|
pub fn SunTextSelectionGeometryDiagnostic::visual_segment_count(
  self : SunTextSelectionGeometryDiagnostic,
) -> Int {
  self.visual_segment_count
}

///|
pub fn SunTextSelectionGeometryDiagnostic::bidi_visual_order_observed(
  self : SunTextSelectionGeometryDiagnostic,
) -> Bool {
  self.bidi_visual_order_observed
}

///|
pub fn SunEmojiFontFallbackDiagnostic::text(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.text
}

///|
pub fn SunEmojiFontFallbackDiagnostic::text_system_id(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.text_system_id
}

///|
pub fn SunEmojiFontFallbackDiagnostic::requested_font_family(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.requested_font_family
}

///|
pub fn SunEmojiFontFallbackDiagnostic::font_source(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.font_source
}

///|
pub fn SunEmojiFontFallbackDiagnostic::shaper(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.shaper
}

///|
pub fn SunEmojiFontFallbackDiagnostic::resolved_fallback_face_index(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.resolved_fallback_face_index
}

///|
pub fn SunEmojiFontFallbackDiagnostic::resolved_font_name(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.resolved_font_name
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_language_tags(
  self : SunEmojiFontFallbackDiagnostic,
) -> Array[String] {
  self.fallback_language_tags
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_script_tag(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.fallback_script_tag
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_language_tag_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_language_tag_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_request_language_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_request_language_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::registered_font_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.registered_font_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::resolved_face_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.resolved_face_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::span_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.span_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_span_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_span_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::missing_char_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.missing_char_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::covered_char_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.covered_char_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::emoji_hint(
  self : SunEmojiFontFallbackDiagnostic,
) -> Bool {
  self.emoji_hint
}

///|
pub fn SunEmojiFontFallbackDiagnostic::registered_font_fallback_ready(
  self : SunEmojiFontFallbackDiagnostic,
) -> Bool {
  self.registered_font_fallback_ready
}

///|
pub fn SunEmojiFontFallbackDiagnostic::missing_glyph_recovery_ready(
  self : SunEmojiFontFallbackDiagnostic,
) -> Bool {
  self.missing_glyph_recovery_ready
}

///|
pub fn SunEmojiFontFallbackDiagnostic::deterministic_color_emoji_ready(
  self : SunEmojiFontFallbackDiagnostic,
) -> Bool {
  self.deterministic_color_emoji_ready
}

///|
pub fn SunEmojiFontFallbackDiagnostic::glyph_format(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.glyph_format
}

///|
pub fn SunEmojiFontFallbackDiagnostic::glyph_key(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  self.glyph_key
}

///|
pub fn SunEmojiFontFallbackDiagnostic::glyph_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.glyph_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::cluster_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.cluster_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::glyph_width(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.glyph_width
}

///|
pub fn SunEmojiFontFallbackDiagnostic::glyph_height(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.glyph_height
}

///|
pub fn SunEmojiFontFallbackDiagnostic::resolved_missing_glyph_count(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.resolved_missing_glyph_count
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_character(
  self : SunEmojiFontFallbackDiagnostic,
) -> Int {
  self.fallback_character
}

///|
pub fn SunEmojiFontFallbackDiagnostic::emoji_fallback_attempted(
  self : SunEmojiFontFallbackDiagnostic,
) -> Bool {
  self.emoji_fallback_attempted
}

///|
pub fn SunEmojiFontFallbackDiagnostic::fallback_request_ready(
  self : SunEmojiFontFallbackDiagnostic,
) -> Bool {
  self.fallback_request_ready
}

///|
pub fn SunTextMaturityDiagnostic::summary(
  self : SunTextMaturityDiagnostic,
) -> String {
  let geometry_label = if self.paragraph_layout_ready &&
    self.line_metrics_ready &&
    self.selection_rects_ready &&
    self.hit_test_ready {
    "paragraph geometry ready"
  } else {
    "paragraph geometry pending"
  }
  let gap_label = if self.bidi_visual_order_ready &&
    self.native_paragraph_ready &&
    self.color_emoji_ready {
    "bidi/native paragraph/color emoji ready"
  } else if self.bidi_visual_order_ready {
    "bidi ready; native paragraph/color emoji pending"
  } else {
    "bidi/native paragraph/color emoji pending"
  }
  let grapheme_label = if self.unicode_17_grapheme_boundary_ready {
    "Unicode 17 grapheme boundary contract ready"
  } else {
    "Unicode 17 grapheme boundary contract pending"
  }
  "Sun text maturity audit partial: ready=\{self.ready_count} gaps=\{self.gap_count} registered_fonts=\{self.registered_font_count} lines=\{self.paragraph_line_count} selection_rects=\{self.selection_rect_count}; \{geometry_label}; \{grapheme_label}; \{gap_label}"
}

///|
pub fn SunEmojiFontFallbackDiagnostic::summary(
  self : SunEmojiFontFallbackDiagnostic,
) -> String {
  let fallback_label = if self.registered_font_fallback_ready {
    "registered-font fallback ready"
  } else {
    "registered-font fallback pending"
  }
  let missing_label = if self.missing_glyph_recovery_ready {
    "missing glyph recovery ready"
  } else {
    "missing glyph recovery pending"
  }
  let color_label = if self.deterministic_color_emoji_ready {
    "color emoji ready"
  } else {
    "color emoji pending"
  }
  "Sun emoji fallback audit partial: source=\{self.font_source} shaper=\{self.shaper} script=\{self.fallback_script_tag} langs=\{self.fallback_request_language_count} spans=\{self.span_count} fallback_spans=\{self.fallback_span_count} missing_chars=\{self.missing_char_count} covered_chars=\{self.covered_char_count} registered_fonts=\{self.registered_font_count} resolved_faces=\{self.resolved_face_count}; \{fallback_label}; \{missing_label}; \{color_label}; glyph_format=\{self.glyph_format}; glyph_key=\{self.glyph_key}"
}
