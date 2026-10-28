///|
// Opaque native text engine selected by platform hosts. Platform packages
// construct one with `native_platform_text_engine`; optional fallback behavior
// is explicit so a renderer stays independent from concrete text engines.
pub struct NativeTextEngine {
  priv provider : NativePlatformTextProvider
  priv fallback : NativePlatformTextProvider?
}

///|
// Callback bundle implemented by a platform text engine such as CoreText,
// DirectWrite, or fontconfig/HarfBuzz/FreeType.
pub struct NativePlatformTextProvider {
  priv id : String
  priv measure : (@core.TextLayoutInput) -> NativeTextLayout?
  priv layout_run : (@core.TextRun, Double) -> NativeTextLayout?
  priv raster_glyph : (String, Bytes) -> NativeRasterGlyph?
  priv register_font_data : (@core.FontFamily, Bytes) -> Unit
}

///|
// Renderer-neutral glyph key. Platform providers own the payload encoding;
// `cache_key` must be stable across frames and include all raster-affecting
// fields such as glyph identity, size, style, and scale.
pub struct NativeGlyphKey {
  priv cache_key : String
  priv payload : Bytes
}

///|
pub(all) enum NativeRasterGlyphFormat {
  AlphaMask
  ColorRgba
} derive(Eq, Debug, ToJson)

///|
pub extend NativeRasterGlyphFormat with Debug::{to_repr}

///|
pub extend NativeRasterGlyphFormat with Eq::{not_equal, equal}

///|
pub extend NativeRasterGlyphFormat with ToJson::{to_json}

///|
// Positioned glyph produced by platform text layout. Coordinates are logical
// pixels relative to the text run before frame alignment is applied.
pub struct NativeGlyphPlacement {
  priv key : NativeGlyphKey
  priv x : Double
  priv y : Double
}

///|
// Text layout returned by platform providers. Measurement must provide a
// monotonic caret array covering the input text; render layout may omit carets
// but must provide valid metrics and glyph placements.
pub struct NativeTextLayout {
  priv size : @core.Size
  priv baseline : Double
  priv caret_positions : Array[Double]
  priv glyphs : Array[NativeGlyphPlacement]
}

///|
// Glyph bitmap returned by a native text provider. Alpha glyphs are tinted by
// the text run color; color glyphs carry RGBA pixel payloads and preserve
// native emoji/color-font raster output while still applying run opacity.
pub struct NativeRasterGlyph {
  priv width : Int32
  priv height : Int32
  priv bearing_x : Int32
  priv bearing_y : Int32
  priv format : NativeRasterGlyphFormat
  priv pixels : Bytes
}

///|
fn NativeTextEngine::id(self : NativeTextEngine) -> String {
  self.provider.id
}

///|
pub fn NativeTextEngine::provider_id(self : NativeTextEngine) -> String {
  self.provider.id
}

///|
pub fn NativeTextEngine::fallback_provider_id(
  self : NativeTextEngine,
) -> String {
  match self.fallback {
    Some(provider) => provider.id
    None => ""
  }
}

///|
pub fn NativePlatformTextProvider::new(
  id~ : String,
  measure~ : (@core.TextLayoutInput) -> NativeTextLayout?,
  layout_run~ : (@core.TextRun, Double) -> NativeTextLayout?,
  raster_glyph~ : (String, Bytes) -> NativeRasterGlyph?,
  register_font_data~ : (@core.FontFamily, Bytes) -> Unit = (_family, _data) => {
    ()
  },
) -> NativePlatformTextProvider {
  { id, measure, layout_run, raster_glyph, register_font_data, }
}

///|
pub fn native_platform_text_engine(
  provider : NativePlatformTextProvider,
) -> NativeTextEngine {
  { provider, fallback: None, }
}

///|
pub fn native_platform_text_engine_with_fallback(
  provider : NativePlatformTextProvider,
  fallback~ : NativeTextEngine,
) -> NativeTextEngine {
  { provider, fallback: Some(fallback.provider), }
}

///|
pub fn native_noop_text_engine() -> NativeTextEngine {
  native_platform_text_engine(
    NativePlatformTextProvider::new(
      id="native-noop-text",
      measure=_input => None,
      layout_run=(_run, _scale_factor) => None,
      raster_glyph=(_cache_key, _payload) => None,
    ),
  )
}

///|
// Create a platform glyph key. A renderer treats payload as opaque data and
// passes it back to the provider's raster callback.
pub fn native_platform_glyph_key(
  cache_key~ : String,
  payload~ : Bytes,
) -> NativeGlyphKey {
  { cache_key, payload, }
}

///|
pub fn NativeGlyphKey::cache_key(self : NativeGlyphKey) -> String {
  self.cache_key
}

///|
// Create a positioned platform glyph in logical run coordinates.
pub fn NativeGlyphPlacement::new(
  key~ : NativeGlyphKey,
  x~ : Double,
  y~ : Double = 0.0,
) -> NativeGlyphPlacement {
  { key, x, y, }
}

///|
pub fn NativeGlyphPlacement::key(self : NativeGlyphPlacement) -> NativeGlyphKey {
  self.key
}

///|
pub fn NativeGlyphPlacement::x(self : NativeGlyphPlacement) -> Double {
  self.x
}

///|
pub fn NativeGlyphPlacement::y(self : NativeGlyphPlacement) -> Double {
  self.y
}

///|
// Create a provider layout value. Invalid metrics or non-monotonic carets are
// filtered by the cache and trigger fallback.
pub fn NativeTextLayout::new(
  size~ : @core.Size,
  baseline~ : Double,
  caret_positions~ : Array[Double] = [],
  glyphs~ : Array[NativeGlyphPlacement] = [],
) -> NativeTextLayout {
  { size, baseline, caret_positions, glyphs, }
}

///|
pub fn NativeTextLayout::size(self : NativeTextLayout) -> @core.Size {
  self.size
}

///|
pub fn NativeTextLayout::baseline(self : NativeTextLayout) -> Double {
  self.baseline
}

///|
pub fn NativeTextLayout::caret_positions(
  self : NativeTextLayout,
) -> Array[Double] {
  self.caret_positions
}

///|
pub fn NativeTextLayout::glyphs(
  self : NativeTextLayout,
) -> Array[NativeGlyphPlacement] {
  self.glyphs
}

///|
// Create a provider raster glyph. The cache validates dimensions against the
// pixel buffer before a renderer uploads it to a glyph atlas.
pub fn NativeRasterGlyph::new(
  width~ : Int32,
  height~ : Int32,
  bearing_x~ : Int32,
  bearing_y~ : Int32,
  format~ : NativeRasterGlyphFormat = AlphaMask,
  pixels~ : Bytes,
) -> NativeRasterGlyph {
  { width, height, bearing_x, bearing_y, format, pixels, }
}

///|
pub fn NativeRasterGlyph::width(self : NativeRasterGlyph) -> Int32 {
  self.width
}

///|
pub fn NativeRasterGlyph::height(self : NativeRasterGlyph) -> Int32 {
  self.height
}

///|
pub fn NativeRasterGlyph::bearing_x(self : NativeRasterGlyph) -> Int32 {
  self.bearing_x
}

///|
pub fn NativeRasterGlyph::bearing_y(self : NativeRasterGlyph) -> Int32 {
  self.bearing_y
}

///|
pub fn NativeRasterGlyph::format(
  self : NativeRasterGlyph,
) -> NativeRasterGlyphFormat {
  self.format
}

///|
pub fn NativeRasterGlyph::pixels(self : NativeRasterGlyph) -> Bytes {
  self.pixels
}
