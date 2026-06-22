///|
/// Result of drawing text through glyph-mask cache and atlas resources.
pub struct TextAtlasDrawResult {
  glyph_count : Int
  drawn_glyph_count : Int
  skipped_glyph_count : Int
  cache_hit_count : Int
  rasterized_glyph_count : Int
  atlas_hit_count : Int
  atlas_inserted_count : Int
  did_clear_atlas : Bool
} derive(Debug)

///|
/// Result of drawing one fallback line through glyph-mask cache and atlas
/// resources.
pub struct TextFallbackAtlasDrawResult {
  plan : @text.FontFallbackPlan
  drawn_span_count : Int
  skipped_span_count : Int
  advance_width : Double
  atlas_result : TextAtlasDrawResult
} derive(Debug)

///|
/// Result of drawing text through a caller-owned rendered text-mask cache.
pub struct TextMaskDrawResult {
  did_render_mask : Bool
} derive(Debug)

///|
/// Result of drawing a single line through an ordered font fallback stack.
pub struct TextFallbackDrawResult {
  plan : @text.FontFallbackPlan
  drawn_span_count : Int
  skipped_span_count : Int
  rendered_mask_count : Int
  cache_hit_count : Int
  advance_width : Double
} derive(Debug)

///|
/// Result of parsing font bytes through renderer resources and drawing text.
pub struct CachedFontTextDrawResult {
  did_parse_font : Bool
  text_result : TextMaskDrawResult
} derive(Debug)

///|
/// Result of parsing font bytes through renderer resources and drawing atlas
/// text.
pub struct CachedFontAtlasDrawResult {
  did_parse_font : Bool
  atlas_result : TextAtlasDrawResult
} derive(Debug)

///|
/// Result of parsing a font-byte fallback stack and drawing cached fallback
/// text.
pub struct CachedFontFallbackDrawResult {
  parsed_font_count : Int
  font_cache_hit_count : Int
  fallback_result : TextFallbackDrawResult
} derive(Debug)

///|
/// Result of parsing a font-byte fallback stack and drawing atlas fallback
/// text.
pub struct CachedFontFallbackAtlasDrawResult {
  parsed_font_count : Int
  font_cache_hit_count : Int
  fallback_result : TextFallbackAtlasDrawResult
} derive(Debug)

///|
/// Result of drawing through a caller-owned pixmap cache.
pub struct CachedPixmapDrawResult {
  did_insert_pixmap : Bool
} derive(Debug)

///|
/// Result of decoding BMP bytes through a pixmap cache and drawing them.
pub struct CachedBmpPixmapDrawResult {
  did_decode_pixmap : Bool
} derive(Debug)

///|
/// Result of decoding PNG bytes through a pixmap cache and drawing them.
pub struct CachedPngPixmapDrawResult {
  did_decode_pixmap : Bool
} derive(Debug)

///|
/// Result of decoding raw RGBA bytes through a pixmap cache and drawing them.
pub struct CachedRgbaPixmapDrawResult {
  did_decode_pixmap : Bool
} derive(Debug)

///|
/// Return the number of layout glyphs visited by an atlas text draw.
pub fn TextAtlasDrawResult::get_glyph_count(self : TextAtlasDrawResult) -> Int {
  self.glyph_count
}

///|
/// Return the number of glyphs composited from the atlas.
pub fn TextAtlasDrawResult::get_drawn_glyph_count(
  self : TextAtlasDrawResult,
) -> Int {
  self.drawn_glyph_count
}

///|
/// Return the number of layout glyphs that could not be drawn through the atlas.
pub fn TextAtlasDrawResult::get_skipped_glyph_count(
  self : TextAtlasDrawResult,
) -> Int {
  self.skipped_glyph_count
}

///|
/// Return the number of drawable glyphs reused from the glyph mask cache.
pub fn TextAtlasDrawResult::get_cache_hit_count(
  self : TextAtlasDrawResult,
) -> Int {
  self.cache_hit_count
}

///|
/// Return the number of glyph masks rasterized on cache miss.
pub fn TextAtlasDrawResult::get_rasterized_glyph_count(
  self : TextAtlasDrawResult,
) -> Int {
  self.rasterized_glyph_count
}

///|
/// Return the number of glyph placements reused from the atlas.
pub fn TextAtlasDrawResult::get_atlas_hit_count(
  self : TextAtlasDrawResult,
) -> Int {
  self.atlas_hit_count
}

///|
/// Return the number of glyph placements newly inserted into the atlas.
pub fn TextAtlasDrawResult::get_atlas_inserted_count(
  self : TextAtlasDrawResult,
) -> Int {
  self.atlas_inserted_count
}

///|
/// Return whether the atlas was cleared while drawing this text.
pub fn TextAtlasDrawResult::did_clear_atlas(self : TextAtlasDrawResult) -> Bool {
  self.did_clear_atlas
}

///|
/// Return whether this draw rendered a new text mask instead of hitting cache.
pub fn TextMaskDrawResult::did_render_mask(self : TextMaskDrawResult) -> Bool {
  self.did_render_mask
}

///|
/// Return whether this draw reused a rendered text mask from cache.
pub fn TextMaskDrawResult::did_hit_cache(self : TextMaskDrawResult) -> Bool {
  !self.did_render_mask
}

///|
/// Get the fallback plan used by this draw.
pub fn TextFallbackDrawResult::get_plan(
  self : TextFallbackDrawResult,
) -> @text.FontFallbackPlan {
  self.plan
}

///|
/// Return the number of fallback spans visited by this draw.
pub fn TextFallbackDrawResult::get_span_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.plan.span_count()
}

///|
/// Return the number of fallback spans drawn with a covering face.
pub fn TextFallbackDrawResult::get_drawn_span_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.drawn_span_count
}

///|
/// Return the number of missing-glyph spans skipped by this draw.
pub fn TextFallbackDrawResult::get_skipped_span_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.skipped_span_count
}

///|
/// Return the number of missing-glyph spans skipped by this draw.
pub fn TextFallbackDrawResult::get_missing_span_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.skipped_span_count
}

///|
/// Return the number of text scalars not covered by any fallback face.
pub fn TextFallbackDrawResult::get_missing_char_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.plan.get_missing_char_count()
}

///|
/// Return the number of fallback spans that rendered a fresh mask.
pub fn TextFallbackDrawResult::get_rendered_mask_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.rendered_mask_count
}

///|
/// Return the number of fallback spans reused from a text-mask cache.
pub fn TextFallbackDrawResult::get_cache_hit_count(
  self : TextFallbackDrawResult,
) -> Int {
  self.cache_hit_count
}

///|
/// Return whether this draw skipped at least one missing glyph span.
pub fn TextFallbackDrawResult::has_missing_glyphs(
  self : TextFallbackDrawResult,
) -> Bool {
  self.plan.has_missing_glyphs()
}

///|
/// Return the horizontal advance consumed by the fallback line draw.
pub fn TextFallbackDrawResult::get_advance_width(
  self : TextFallbackDrawResult,
) -> Double {
  self.advance_width
}

///|
/// Get the fallback plan used by this atlas draw.
pub fn TextFallbackAtlasDrawResult::get_plan(
  self : TextFallbackAtlasDrawResult,
) -> @text.FontFallbackPlan {
  self.plan
}

///|
/// Return the number of fallback spans visited by this atlas draw.
pub fn TextFallbackAtlasDrawResult::get_span_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.plan.span_count()
}

///|
/// Return the number of fallback spans drawn with a covering face.
pub fn TextFallbackAtlasDrawResult::get_drawn_span_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.drawn_span_count
}

///|
/// Return the number of missing-glyph spans skipped by this atlas draw.
pub fn TextFallbackAtlasDrawResult::get_skipped_span_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.skipped_span_count
}

///|
/// Return the number of missing-glyph spans skipped by this atlas draw.
pub fn TextFallbackAtlasDrawResult::get_missing_span_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.skipped_span_count
}

///|
/// Return the number of text scalars not covered by any fallback face.
pub fn TextFallbackAtlasDrawResult::get_missing_char_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.plan.get_missing_char_count()
}

///|
/// Return whether this atlas draw skipped at least one missing glyph span.
pub fn TextFallbackAtlasDrawResult::has_missing_glyphs(
  self : TextFallbackAtlasDrawResult,
) -> Bool {
  self.plan.has_missing_glyphs()
}

///|
/// Return the horizontal advance consumed by the fallback atlas draw.
pub fn TextFallbackAtlasDrawResult::get_advance_width(
  self : TextFallbackAtlasDrawResult,
) -> Double {
  self.advance_width
}

///|
/// Return the underlying glyph-atlas draw result.
pub fn TextFallbackAtlasDrawResult::get_atlas_result(
  self : TextFallbackAtlasDrawResult,
) -> TextAtlasDrawResult {
  self.atlas_result
}

///|
/// Return the number of layout glyphs visited by covered fallback spans.
pub fn TextFallbackAtlasDrawResult::get_glyph_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_glyph_count()
}

///|
/// Return the number of glyphs composited from the atlas.
pub fn TextFallbackAtlasDrawResult::get_drawn_glyph_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_drawn_glyph_count()
}

///|
/// Return the number of layout glyphs that could not be drawn through the atlas.
pub fn TextFallbackAtlasDrawResult::get_skipped_glyph_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_skipped_glyph_count()
}

///|
/// Return the number of drawable glyphs reused from the glyph mask cache.
pub fn TextFallbackAtlasDrawResult::get_cache_hit_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_cache_hit_count()
}

///|
/// Return the number of glyph masks rasterized on cache miss.
pub fn TextFallbackAtlasDrawResult::get_rasterized_glyph_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_rasterized_glyph_count()
}

///|
/// Return the number of glyph placements reused from the atlas.
pub fn TextFallbackAtlasDrawResult::get_atlas_hit_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_atlas_hit_count()
}

///|
/// Return the number of glyph placements newly inserted into the atlas.
pub fn TextFallbackAtlasDrawResult::get_atlas_inserted_count(
  self : TextFallbackAtlasDrawResult,
) -> Int {
  self.atlas_result.get_atlas_inserted_count()
}

///|
/// Return whether the atlas was cleared while drawing this fallback line.
pub fn TextFallbackAtlasDrawResult::did_clear_atlas(
  self : TextFallbackAtlasDrawResult,
) -> Bool {
  self.atlas_result.did_clear_atlas()
}

///|
/// Return whether this draw parsed font bytes instead of hitting cache.
pub fn CachedFontTextDrawResult::did_parse_font(
  self : CachedFontTextDrawResult,
) -> Bool {
  self.did_parse_font
}

///|
/// Return whether this draw reused a checked font face from cache.
pub fn CachedFontTextDrawResult::did_hit_font_cache(
  self : CachedFontTextDrawResult,
) -> Bool {
  !self.did_parse_font
}

///|
/// Return whether this draw rendered a new text mask instead of hitting cache.
pub fn CachedFontTextDrawResult::did_render_mask(
  self : CachedFontTextDrawResult,
) -> Bool {
  self.text_result.did_render_mask()
}

///|
/// Return whether this draw reused a rendered text mask from cache.
pub fn CachedFontTextDrawResult::did_hit_text_cache(
  self : CachedFontTextDrawResult,
) -> Bool {
  self.text_result.did_hit_cache()
}

///|
/// Return the underlying rendered text-mask draw result.
pub fn CachedFontTextDrawResult::get_text_result(
  self : CachedFontTextDrawResult,
) -> TextMaskDrawResult {
  self.text_result
}

///|
/// Return whether this draw parsed font bytes instead of hitting cache.
pub fn CachedFontAtlasDrawResult::did_parse_font(
  self : CachedFontAtlasDrawResult,
) -> Bool {
  self.did_parse_font
}

///|
/// Return whether this draw reused a checked font face from cache.
pub fn CachedFontAtlasDrawResult::did_hit_font_cache(
  self : CachedFontAtlasDrawResult,
) -> Bool {
  !self.did_parse_font
}

///|
/// Return the underlying glyph-atlas draw result.
pub fn CachedFontAtlasDrawResult::get_atlas_result(
  self : CachedFontAtlasDrawResult,
) -> TextAtlasDrawResult {
  self.atlas_result
}

///|
/// Return the number of layout glyphs visited by the atlas draw.
pub fn CachedFontAtlasDrawResult::get_glyph_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_glyph_count()
}

///|
/// Return the number of glyphs composited from the atlas.
pub fn CachedFontAtlasDrawResult::get_drawn_glyph_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_drawn_glyph_count()
}

///|
/// Return the number of layout glyphs that could not be drawn through the atlas.
pub fn CachedFontAtlasDrawResult::get_skipped_glyph_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_skipped_glyph_count()
}

///|
/// Return the number of drawable glyphs reused from the glyph mask cache.
pub fn CachedFontAtlasDrawResult::get_cache_hit_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_cache_hit_count()
}

///|
/// Return the number of glyph masks rasterized on cache miss.
pub fn CachedFontAtlasDrawResult::get_rasterized_glyph_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_rasterized_glyph_count()
}

///|
/// Return the number of glyph placements reused from the atlas.
pub fn CachedFontAtlasDrawResult::get_atlas_hit_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_atlas_hit_count()
}

///|
/// Return the number of glyph placements newly inserted into the atlas.
pub fn CachedFontAtlasDrawResult::get_atlas_inserted_count(
  self : CachedFontAtlasDrawResult,
) -> Int {
  self.atlas_result.get_atlas_inserted_count()
}

///|
/// Return whether the atlas was cleared while drawing this text.
pub fn CachedFontAtlasDrawResult::did_clear_atlas(
  self : CachedFontAtlasDrawResult,
) -> Bool {
  self.atlas_result.did_clear_atlas()
}

///|
/// Return the number of fallback font sources parsed on this draw.
pub fn CachedFontFallbackDrawResult::get_parsed_font_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.parsed_font_count
}

///|
/// Return the number of fallback font sources reused from the font cache.
pub fn CachedFontFallbackDrawResult::get_font_cache_hit_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.font_cache_hit_count
}

///|
/// Return the underlying fallback line draw result.
pub fn CachedFontFallbackDrawResult::get_fallback_result(
  self : CachedFontFallbackDrawResult,
) -> TextFallbackDrawResult {
  self.fallback_result
}

///|
/// Return the number of fallback spans visited by this draw.
pub fn CachedFontFallbackDrawResult::get_span_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_span_count()
}

///|
/// Return the number of fallback spans drawn with a covering face.
pub fn CachedFontFallbackDrawResult::get_drawn_span_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_drawn_span_count()
}

///|
/// Return the number of missing-glyph spans skipped by this draw.
pub fn CachedFontFallbackDrawResult::get_skipped_span_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_skipped_span_count()
}

///|
/// Return the number of missing-glyph spans skipped by this draw.
pub fn CachedFontFallbackDrawResult::get_missing_span_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_missing_span_count()
}

///|
/// Return the number of text scalars not covered by any fallback face.
pub fn CachedFontFallbackDrawResult::get_missing_char_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_missing_char_count()
}

///|
/// Return whether this draw skipped at least one missing glyph span.
pub fn CachedFontFallbackDrawResult::has_missing_glyphs(
  self : CachedFontFallbackDrawResult,
) -> Bool {
  self.fallback_result.has_missing_glyphs()
}

///|
/// Return the horizontal advance consumed by the fallback line draw.
pub fn CachedFontFallbackDrawResult::get_advance_width(
  self : CachedFontFallbackDrawResult,
) -> Double {
  self.fallback_result.get_advance_width()
}

///|
/// Return the number of fallback spans that rendered a fresh mask.
pub fn CachedFontFallbackDrawResult::get_rendered_mask_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_rendered_mask_count()
}

///|
/// Return the number of fallback spans reused from the text-mask cache.
pub fn CachedFontFallbackDrawResult::get_text_cache_hit_count(
  self : CachedFontFallbackDrawResult,
) -> Int {
  self.fallback_result.get_cache_hit_count()
}

///|
/// Return the number of fallback font sources parsed on this atlas draw.
pub fn CachedFontFallbackAtlasDrawResult::get_parsed_font_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.parsed_font_count
}

///|
/// Return the number of fallback font sources reused from the font cache.
pub fn CachedFontFallbackAtlasDrawResult::get_font_cache_hit_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.font_cache_hit_count
}

///|
/// Return the underlying fallback atlas draw result.
pub fn CachedFontFallbackAtlasDrawResult::get_fallback_result(
  self : CachedFontFallbackAtlasDrawResult,
) -> TextFallbackAtlasDrawResult {
  self.fallback_result
}

///|
/// Return the number of fallback spans visited by this atlas draw.
pub fn CachedFontFallbackAtlasDrawResult::get_span_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_span_count()
}

///|
/// Return the number of fallback spans drawn with a covering face.
pub fn CachedFontFallbackAtlasDrawResult::get_drawn_span_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_drawn_span_count()
}

///|
/// Return the number of missing-glyph spans skipped by this atlas draw.
pub fn CachedFontFallbackAtlasDrawResult::get_skipped_span_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_skipped_span_count()
}

///|
/// Return the number of missing-glyph spans skipped by this atlas draw.
pub fn CachedFontFallbackAtlasDrawResult::get_missing_span_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_missing_span_count()
}

///|
/// Return the number of text scalars not covered by any fallback face.
pub fn CachedFontFallbackAtlasDrawResult::get_missing_char_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_missing_char_count()
}

///|
/// Return whether this atlas draw skipped at least one missing glyph span.
pub fn CachedFontFallbackAtlasDrawResult::has_missing_glyphs(
  self : CachedFontFallbackAtlasDrawResult,
) -> Bool {
  self.fallback_result.has_missing_glyphs()
}

///|
/// Return the horizontal advance consumed by the fallback atlas draw.
pub fn CachedFontFallbackAtlasDrawResult::get_advance_width(
  self : CachedFontFallbackAtlasDrawResult,
) -> Double {
  self.fallback_result.get_advance_width()
}

///|
/// Return the underlying glyph-atlas draw result.
pub fn CachedFontFallbackAtlasDrawResult::get_atlas_result(
  self : CachedFontFallbackAtlasDrawResult,
) -> TextAtlasDrawResult {
  self.fallback_result.get_atlas_result()
}

///|
/// Return the number of layout glyphs visited by covered fallback spans.
pub fn CachedFontFallbackAtlasDrawResult::get_glyph_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_glyph_count()
}

///|
/// Return the number of glyphs composited from the atlas.
pub fn CachedFontFallbackAtlasDrawResult::get_drawn_glyph_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_drawn_glyph_count()
}

///|
/// Return the number of layout glyphs that could not be drawn through the atlas.
pub fn CachedFontFallbackAtlasDrawResult::get_skipped_glyph_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_skipped_glyph_count()
}

///|
/// Return the number of drawable glyphs reused from the glyph mask cache.
pub fn CachedFontFallbackAtlasDrawResult::get_cache_hit_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_cache_hit_count()
}

///|
/// Return the number of glyph masks rasterized on cache miss.
pub fn CachedFontFallbackAtlasDrawResult::get_rasterized_glyph_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_rasterized_glyph_count()
}

///|
/// Return the number of glyph placements reused from the atlas.
pub fn CachedFontFallbackAtlasDrawResult::get_atlas_hit_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_atlas_hit_count()
}

///|
/// Return the number of glyph placements newly inserted into the atlas.
pub fn CachedFontFallbackAtlasDrawResult::get_atlas_inserted_count(
  self : CachedFontFallbackAtlasDrawResult,
) -> Int {
  self.fallback_result.get_atlas_inserted_count()
}

///|
/// Return whether the atlas was cleared while drawing this fallback line.
pub fn CachedFontFallbackAtlasDrawResult::did_clear_atlas(
  self : CachedFontFallbackAtlasDrawResult,
) -> Bool {
  self.fallback_result.did_clear_atlas()
}

///|
/// Return whether this draw inserted a pixmap into the image cache.
pub fn CachedPixmapDrawResult::did_insert_pixmap(
  self : CachedPixmapDrawResult,
) -> Bool {
  self.did_insert_pixmap
}

///|
/// Return whether this draw reused a pixmap from the image cache.
pub fn CachedPixmapDrawResult::did_hit_cache(
  self : CachedPixmapDrawResult,
) -> Bool {
  !self.did_insert_pixmap
}

///|
/// Return whether this draw decoded BMP bytes into the image cache.
pub fn CachedBmpPixmapDrawResult::did_decode_pixmap(
  self : CachedBmpPixmapDrawResult,
) -> Bool {
  self.did_decode_pixmap
}

///|
/// Return whether this draw reused a cached decoded pixmap.
pub fn CachedBmpPixmapDrawResult::did_hit_cache(
  self : CachedBmpPixmapDrawResult,
) -> Bool {
  !self.did_decode_pixmap
}

///|
/// Return whether this draw decoded PNG bytes into the image cache.
pub fn CachedPngPixmapDrawResult::did_decode_pixmap(
  self : CachedPngPixmapDrawResult,
) -> Bool {
  self.did_decode_pixmap
}

///|
/// Return whether this draw reused a cached decoded pixmap.
pub fn CachedPngPixmapDrawResult::did_hit_cache(
  self : CachedPngPixmapDrawResult,
) -> Bool {
  !self.did_decode_pixmap
}

///|
/// Return whether this draw decoded RGBA bytes into the image cache.
pub fn CachedRgbaPixmapDrawResult::did_decode_pixmap(
  self : CachedRgbaPixmapDrawResult,
) -> Bool {
  self.did_decode_pixmap
}

///|
/// Return whether this draw reused a cached decoded pixmap.
pub fn CachedRgbaPixmapDrawResult::did_hit_cache(
  self : CachedRgbaPixmapDrawResult,
) -> Bool {
  !self.did_decode_pixmap
}
