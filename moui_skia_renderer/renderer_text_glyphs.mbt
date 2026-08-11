///|
priv struct SkiaGlyphRun {
  glyphs : Array[@skia_native.GlyphId]
  positions : Array[@moui_skia.Point]
  clusters : Array[Int]
  width : Double
}

///|
fn skia_measure_text_width(font : @skia_native.Font, text : String) -> Double {
  font.measure_text_utf8(@utf8.encode(text[:], bom=false)).to_double()
}

///|
fn skia_draw_text_glyph_run(
  font : @skia_native.Font,
  text : String,
) -> SkiaGlyphRun {
  skia_glyph_run_with_shaper(font, text, use_shaper=false)
}

///|
fn skia_glyph_run_for_resolution(
  font : @skia_native.Font,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaGlyphRun {
  match resolution {
    SkiaFontResolution::SystemFontMgr =>
      skia_glyph_run_with_shaper(font, text, use_shaper=true)
    SkiaFontResolution::EmptyTypeface => skia_draw_text_glyph_run(font, text)
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
      match skia_complete_fallback_payload(emoji_font, text, resolution) {
        Some(payload) => return Some(payload)
        None => ()
      }
    None => ()
  }
  match skia_default_fallback_draw_font(font) {
    Some(fallback_font) =>
      skia_recovering_fallback_payload(
        fallback_font, text, resolution, primary_run,
      )
    None => None
  }
}

///|
fn skia_complete_fallback_payload(
  font : @skia_native.Font,
  text : String,
  resolution : SkiaFontResolution,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run_for_resolution(font, text, resolution)
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
  resolution : SkiaFontResolution,
  primary_run : SkiaGlyphRun,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run_for_resolution(font, text, resolution)
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
    if @render_common.codepoint_is_emoji_hint(ch.to_int()) {
      return true
    }
  }
  false
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
        Some(typeface) => {
          let typeface = match typeface.with_variations(skia_variation_pairs(font)) {
            Some(varied) => varied
            None => typeface
          }
          @skia_native.Font::from_typeface(
            typeface,
            size=Float::from_double(font.size),
          )
        }
        None => @skia_native.Font::default(size=Float::from_double(font.size))
      }
  }
}

///|
fn skia_typeface_for_text(
  font : @core.FontSpec,
  text : String,
) -> @skia_native.Typeface? {
  match skia_typeface_from_embedded(font) {
    Some(typeface) => return Some(typeface)
    None => ()
  }
  match skia_typeface_from_font_files(font) {
    Some(typeface) => return Some(typeface)
    None => ()
  }
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
  } else if @render_common.codepoint_is_emoji_hint(codepoint) {
    Some("und-Zsye")
  } else if @render_common.codepoint_is_kana(codepoint) {
    Some("ja")
  } else if @render_common.codepoint_is_cjk_ideograph(codepoint) {
    Some("zh-Hans")
  } else if @render_common.codepoint_is_hangul_cluster_codepoint(codepoint) ||
    @render_common.codepoint_is_hangul_compatibility_jamo(codepoint) {
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
    "Helvetica Neue", "Segoe UI", "Arial", "HarmonyOS Sans", "HarmonyOS Sans SC",
    "DejaVu Sans", "Noto Sans", "Noto Sans CJK SC", "Liberation Sans",
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
  [
    "Apple Color Emoji", "Segoe UI Emoji", "HMOS Color Emoji", "HarmonyOS Color Emoji",
    "Noto Color Emoji",
  ]
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
