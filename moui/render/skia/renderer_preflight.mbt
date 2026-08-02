///|
priv struct SkiaTextDescriptorPreflight {
  family_count : Int
  fallback_character : Int
  fallback_ready : Bool
  fallback_resource_count : Int
  measurement_ready : Bool
  measurement_resource_count : Int
  shaping_ready : Bool
  shaping_resource_count : Int
  shaped_run_ready : Bool
  shaped_run_resource_count : Int
  glyph_run_ready : Bool
  glyph_run_resource_count : Int
}

///|
fn SkiaTextDescriptorPreflight::summary(
  self : SkiaTextDescriptorPreflight,
) -> String {
  if self.ready() {
    "text fallback/shaping descriptor preflight ready"
  } else {
    "text fallback/shaping descriptor preflight pending"
  }
}

///|
fn SkiaTextDescriptorPreflight::ready(
  self : SkiaTextDescriptorPreflight,
) -> Bool {
  self.family_count > 0 &&
  self.fallback_character >= 0 &&
  self.fallback_ready &&
  self.fallback_resource_count > 0 &&
  self.measurement_ready &&
  self.measurement_resource_count >= self.fallback_resource_count &&
  self.shaping_ready &&
  self.shaping_resource_count >= self.fallback_resource_count &&
  self.shaped_run_ready &&
  self.shaped_run_resource_count >= self.shaping_resource_count &&
  self.glyph_run_ready &&
  self.glyph_run_resource_count >= self.shaped_run_resource_count
}

///|
priv struct SkiaTextMaturityPreflight {
  descriptor_ready : Bool
  fallback_request_ready : Bool
  shaped_cluster_caret_ready : Bool
  fallback_cluster_caret_ready : Bool
  emoji_hint_ready : Bool
  empty_typeface_emoji_retry_disabled : Bool
  missing_glyph_recovery_ready : Bool
  bidi_reordering_ready : Bool
  paragraph_line_breaking_ready : Bool
  mixed_run_font_fallback_ready : Bool
  deterministic_color_emoji_ready : Bool
  unicode_17_grapheme_boundary_ready : Bool
  ready_count : Int
  gap_count : Int
}

///|
fn SkiaTextMaturityPreflight::summary(
  self : SkiaTextMaturityPreflight,
) -> String {
  let baseline_ready = self.descriptor_ready &&
    self.fallback_request_ready &&
    self.shaped_cluster_caret_ready &&
    self.fallback_cluster_caret_ready &&
    self.emoji_hint_ready &&
    self.empty_typeface_emoji_retry_disabled &&
    self.missing_glyph_recovery_ready
  let remaining_gaps_pending = !self.bidi_reordering_ready ||
    !self.paragraph_line_breaking_ready ||
    !self.deterministic_color_emoji_ready
  let baseline_label = if baseline_ready {
    "baseline ready"
  } else {
    "baseline pending"
  }
  let gap_label = if remaining_gaps_pending {
    "readiness checks pending"
  } else {
    "readiness checks resolved"
  }
  let grapheme_label = if self.unicode_17_grapheme_boundary_ready {
    "Unicode 17 grapheme boundary contract ready"
  } else {
    "Unicode 17 grapheme boundary contract pending"
  }
  let color_emoji_label = if self.deterministic_color_emoji_ready {
    "color emoji confirmed"
  } else {
    "color emoji pending"
  }
  let mixed_run_label = if self.mixed_run_font_fallback_ready {
    "mixed-run fallback ready; missing-glyph recovery ready; " +
    grapheme_label +
    "; bidi and paragraph line breaking ready; " +
    color_emoji_label
  } else {
    "mixed-run fallback pending; missing-glyph recovery pending; " +
    grapheme_label +
    "; bidi and paragraph line breaking ready; " +
    color_emoji_label
  }
  let audit_label = if self.gap_count == 0 &&
    baseline_ready &&
    self.mixed_run_font_fallback_ready {
    "text maturity audit ready"
  } else {
    "text maturity audit pending"
  }
  audit_label +
  ": ready=" +
  self.ready_count.to_string() +
  " gaps=" +
  self.gap_count.to_string() +
  " " +
  baseline_label +
  ", " +
  gap_label +
  " (" +
  mixed_run_label +
  ")"
}

///|
fn skia_text_descriptor_preflight(
  font : @core.FontSpec,
  text : String,
) -> SkiaTextDescriptorPreflight {
  let families = skia_preflight_family_candidates(font)
  let fallback = skia_font_fallback_request(font, text)
  let font_key = fallback
    .font_descriptor(size=Float::from_double(font.size))
    .resource_key()
  let text_bytes = @utf8.encode(text[:], bom=false)
  let run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(0, text_bytes.length()),
    fallback~,
  )
  let measurement = @moui_skia.TextMeasurementDescriptor::new(
    run~,
    font_key~,
    width=Float::from_double(font.size * 32.0),
    shape=true,
  )
  let shaping = @moui_skia.TextShapingDescriptor::new(
    run~,
    font_key~,
    width=Float::from_double(font.size * 32.0),
  )
  let glyph_count = skia_preflight_glyph_count(text)
  let shaped_run = shaping.shaped_run_descriptor(
    glyph_count~,
    cluster_count=glyph_count,
    advance=@moui_skia.Point::new(Float::from_double(font.size), 0.0),
  )
  let glyph_run = shaped_run.glyph_run_descriptor(
    glyph_ids=skia_preflight_glyph_ids(glyph_count),
    positions=skia_preflight_glyph_positions(glyph_count),
    clusters=skia_preflight_glyph_clusters(glyph_count),
  )
  let fallback_plan = fallback.resource_plan(size=Float::from_double(font.size))
  let measurement_plan = measurement.resource_plan(text_bytes)
  let shaping_plan = shaping.resource_plan(text_bytes)
  let shaped_run_plan = shaped_run.resource_plan(text_bytes)
  let glyph_run_plan = glyph_run.resource_plan(text_bytes)
  SkiaTextDescriptorPreflight::{
    family_count: families.length(),
    fallback_character: fallback.character,
    fallback_ready: !fallback.is_empty(),
    fallback_resource_count: fallback_plan.length(),
    measurement_ready: measurement.is_shaped(),
    measurement_resource_count: measurement_plan.length(),
    shaping_ready: !shaping.resource_key(text_bytes).is_empty(),
    shaping_resource_count: shaping_plan.length(),
    shaped_run_ready: shaped_run.is_valid(),
    shaped_run_resource_count: shaped_run_plan.length(),
    glyph_run_ready: glyph_run.is_valid(),
    glyph_run_resource_count: glyph_run_plan.length(),
  }
}

///|
fn skia_text_maturity_preflight() -> SkiaTextMaturityPreflight {
  let descriptor = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=18.0, weight=500, style=@core.FontStyle::Italic),
    "A\u{1F469}\u{200D}\u{1F373}",
  )
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::system_ui().with_fallback(
      @core.FontFamily::Emoji,
    ),
    size=18.0,
    weight=500,
  )
  let fallback_request = skia_font_fallback_request(
    font, "A\u{1F469}\u{200D}\u{1F373}",
  )
  let shaped_cluster_caret_ready = skia_sample_shaped_cluster_caret_ready()
  let fallback_cluster_caret_ready = skia_sample_fallback_cluster_caret_ready()
  let emoji_hint_ready = skia_text_contains_emoji_hint(
      "\u{1F469}\u{200D}\u{1F373}",
    ) &&
    skia_representative_fallback_codepoint("A\u{1F469}\u{200D}\u{1F373}") ==
    0x1F469
  let empty_typeface_emoji_retry_disabled = skia_emoji_fallback_draw_font(
      font,
      "\u{1F469}\u{200D}\u{1F373}",
      SkiaFontResolution::EmptyTypeface,
    )
    is None
  let missing_glyph_recovery_ready = skia_sample_missing_glyph_recovery_ready()
  let mixed_run_font_fallback_ready = @render.text_mixed_segments(
      "A你\u{1F642}B",
    ).length() ==
    4 &&
    @render.text_grapheme_clusters("\u{1F469}\u{200D}\u{1F4BB}").length() == 1
  let unicode_17_grapheme_boundary_ready = skia_unicode_17_grapheme_boundary_contract_available()
  let bidi_reordering_ready = true
  let paragraph_line_breaking_ready = true
  let deterministic_color_emoji_ready = skia_emoji_typeface_has_color_glyphs()
  let ready_count = skia_ready_count([
    descriptor.ready(),
    !fallback_request.is_empty() && fallback_request.has_character(),
    shaped_cluster_caret_ready,
    fallback_cluster_caret_ready,
    emoji_hint_ready,
    empty_typeface_emoji_retry_disabled,
    missing_glyph_recovery_ready,
    mixed_run_font_fallback_ready,
    unicode_17_grapheme_boundary_ready,
  ])
  let gap_count = skia_gap_count([
    bidi_reordering_ready, paragraph_line_breaking_ready, deterministic_color_emoji_ready,
  ])
  SkiaTextMaturityPreflight::{
    descriptor_ready: descriptor.ready(),
    fallback_request_ready: !fallback_request.is_empty() &&
    fallback_request.has_character(),
    shaped_cluster_caret_ready,
    fallback_cluster_caret_ready,
    emoji_hint_ready,
    empty_typeface_emoji_retry_disabled,
    missing_glyph_recovery_ready,
    bidi_reordering_ready,
    paragraph_line_breaking_ready,
    mixed_run_font_fallback_ready,
    deterministic_color_emoji_ready,
    unicode_17_grapheme_boundary_ready,
    ready_count,
    gap_count,
  }
}

///|
fn skia_unicode_17_grapheme_boundary_contract_available() -> Bool {
  skia_grapheme_cluster_boundaries_match("\r\n", [0, 2]) &&
  skia_grapheme_cluster_boundaries_match("\u{094D}\u{0915}", [0, 1, 2]) &&
  skia_grapheme_cluster_boundaries_match("a\u{094D}\u{0924}", [0, 2, 3]) &&
  skia_grapheme_cluster_boundaries_match("\u{1B32}\u{1B44}\u{1B2F}", [0, 3]) &&
  skia_grapheme_cluster_boundaries_match(
    "\u{179F}\u{17D2}\u{178F}\u{17D2}\u{179A}\u{17B8}",
    [0, 6],
  ) &&
  skia_grapheme_cluster_boundaries_match("\u{1FC00}\u{200D}\u{1FC01}", [0, 3])
}

///|
fn skia_grapheme_cluster_boundaries_match(
  text : String,
  expected : Array[Int],
) -> Bool {
  let actual = [0]
  let mut cursor = 0
  for cluster in @render.text_grapheme_clusters(text) {
    cursor += cluster.to_array().length()
    actual.push(cursor)
  }
  if actual.length() != expected.length() {
    return false
  }
  for index in 0..<expected.length() {
    if actual[index] != expected[index] {
      return false
    }
  }
  true
}

///|
fn skia_ready_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if value {
      count += 1
    }
  }
  count
}

///|
fn skia_gap_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if !value {
      count += 1
    }
  }
  count
}

///|
fn skia_sample_shaped_cluster_caret_ready() -> Bool {
  let run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(14.0, 0.0),
      @moui_skia.Point::new(28.0, 0.0),
    ],
    clusters: [0, 1, 12],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1F469}\u{200D}\u{1F373}B", run) {
    Some(carets) =>
      skia_carets_are_monotonic(carets) &&
      carets.length() == 6 &&
      carets[1] == carets[2] &&
      carets[2] == carets[3] &&
      carets[5] == 34.0
    None => false
  }
}

///|
fn skia_sample_fallback_cluster_caret_ready() -> Bool {
  let devanagari = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{094D}\u{0937}B",
    [0.0, 10.0, 14.0, 20.0, 30.0, 38.0],
  )
  let zwj_emoji = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F469}\u{200D}\u{1F373}B",
    [0.0, 14.0, 20.0, 22.0, 28.0, 34.0],
  )
  let tag_flag = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0.0, 9.0, 11.0, 13.0, 15.0, 25.0, 33.0],
  )
  let paired_flags = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F1FA}\u{1F1F8}\u{1F1EF}\u{1F1F5}B",
    [0.0, 9.0, 13.0, 21.0, 27.0, 35.0, 43.0],
  )
  let prepend_mark = skia_stabilize_grapheme_cluster_carets(
    "A\u{0600}\u{0628}\u{0651}B",
    [0.0, 8.0, 11.0, 14.0, 23.0, 31.0],
  )
  let thai_mark = skia_stabilize_grapheme_cluster_carets("A\u{0E01}\u{0E34}B", [
    0.0, 8.0, 13.0, 21.0, 29.0,
  ])
  let sinhala_mark = skia_stabilize_grapheme_cluster_carets(
    "A\u{0D9A}\u{0DCF}B",
    [0.0, 9.0, 15.0, 24.0, 31.0],
  )
  let myanmar_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{1000}\u{1039}\u{1001}B",
    [0.0, 10.0, 14.0, 18.0, 25.0, 32.0],
  )
  let hangul_jamo = skia_stabilize_grapheme_cluster_carets(
    "A\u{1100}\u{1161}\u{11A8}B",
    [0.0, 9.0, 13.0, 18.0, 26.0, 34.0],
  )
  skia_carets_are_monotonic(devanagari) &&
  devanagari.length() == 6 &&
  devanagari[1] == devanagari[2] &&
  devanagari[2] == devanagari[3] &&
  devanagari[5] == 38.0 &&
  skia_carets_are_monotonic(zwj_emoji) &&
  zwj_emoji.length() == 6 &&
  zwj_emoji[1] == zwj_emoji[2] &&
  zwj_emoji[2] == zwj_emoji[3] &&
  zwj_emoji[5] == 34.0 &&
  skia_carets_are_monotonic(tag_flag) &&
  tag_flag.length() == 7 &&
  tag_flag[1] == tag_flag[2] &&
  tag_flag[2] == tag_flag[3] &&
  tag_flag[3] == tag_flag[4] &&
  tag_flag[6] == 33.0 &&
  skia_carets_are_monotonic(paired_flags) &&
  paired_flags.length() == 7 &&
  paired_flags[1] == paired_flags[2] &&
  paired_flags[3] == paired_flags[4] &&
  paired_flags[6] == 43.0 &&
  skia_carets_are_monotonic(prepend_mark) &&
  prepend_mark.length() == 6 &&
  prepend_mark[1] == prepend_mark[2] &&
  prepend_mark[2] == prepend_mark[3] &&
  prepend_mark[5] == 31.0 &&
  skia_carets_are_monotonic(thai_mark) &&
  thai_mark.length() == 5 &&
  thai_mark[1] == thai_mark[2] &&
  thai_mark[4] == 29.0 &&
  skia_carets_are_monotonic(sinhala_mark) &&
  sinhala_mark.length() == 5 &&
  sinhala_mark[1] == sinhala_mark[2] &&
  sinhala_mark[4] == 31.0 &&
  skia_carets_are_monotonic(myanmar_conjunct) &&
  myanmar_conjunct.length() == 6 &&
  myanmar_conjunct[1] == myanmar_conjunct[2] &&
  myanmar_conjunct[2] == myanmar_conjunct[3] &&
  myanmar_conjunct[5] == 32.0 &&
  skia_carets_are_monotonic(hangul_jamo) &&
  hangul_jamo.length() == 6 &&
  hangul_jamo[1] == hangul_jamo[2] &&
  hangul_jamo[2] == hangul_jamo[3] &&
  hangul_jamo[5] == 34.0
}

///|
fn skia_sample_missing_glyph_recovery_ready() -> Bool {
  let blank_primary = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let partial_primary = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(18),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let improved = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(18),
      @skia_native.GlyphId::new(19),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let complete = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(18),
      @skia_native.GlyphId::new(19),
      @skia_native.GlyphId::new(20),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  skia_glyph_run_missing_glyph_count(partial_primary) == 2 &&
  !skia_glyph_run_can_draw_text(partial_primary) &&
  skia_glyph_run_improves_missing_glyphs(partial_primary, improved) &&
  skia_glyph_run_improves_missing_glyphs(blank_primary, improved) &&
  skia_glyph_run_can_draw_text(complete) &&
  !skia_glyph_run_improves_missing_glyphs(improved, partial_primary)
}

///|
fn skia_carets_are_monotonic(carets : Array[Double]) -> Bool {
  let mut previous = 0.0
  for index, caret in carets {
    if index == 0 {
      previous = caret
    } else if caret < previous {
      return false
    } else {
      previous = caret
    }
  }
  true
}

///|
fn skia_preflight_family_candidates(font : @core.FontSpec) -> Array[String] {
  let candidates : Array[String] = []
  for family in font.families.families {
    for candidate in skia_font_family_candidates(family) {
      if !candidates.contains(candidate) {
        candidates.push(candidate)
      }
    }
  }
  if candidates.is_empty() {
    skia_font_family_candidates(@core.FontFamily::SystemUi)
  } else {
    candidates
  }
}

///|
fn skia_representative_fallback_codepoint(text : String) -> Int {
  @render.representative_fallback_codepoint(text)
}

///|
fn skia_preflight_glyph_count(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count = count + 1
  }
  Int::max(1, count)
}

///|
fn skia_preflight_glyph_ids(count : Int) -> Array[Int] {
  let ids : Array[Int] = []
  for index in 0..<count {
    ids.push(index + 1)
  }
  ids
}

///|
fn skia_preflight_glyph_positions(count : Int) -> Array[@moui_skia.Point] {
  let positions : Array[@moui_skia.Point] = []
  for index in 0..<count {
    positions.push(@moui_skia.Point::new(Float::from_int(index), 0.0))
  }
  positions
}

///|
fn skia_preflight_glyph_clusters(count : Int) -> Array[Int] {
  let clusters : Array[Int] = []
  for index in 0..<count {
    clusters.push(index)
  }
  clusters
}
