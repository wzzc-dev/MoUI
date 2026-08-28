///|
let atlas_width : Int = 1024

///|
let atlas_height : Int = 1024

///|
let atlas_padding : Int = 1

///|
priv struct NativeFontCache {
  text_engine : NativeTextEngine
  measure_cache : Map[String, @core.TextLayoutResult]
  layout_cache : Map[String, NativeTextLayout]
}

///|
// Opaque native text engine selected by platform hosts. Platform packages
// construct one with `native_platform_text_engine`; optional fallback behavior
// is explicit so renderer/wgpu stays independent from concrete text engines.
pub struct NativeTextEngine {
  priv provider : NativePlatformTextProvider
  priv fallback : NativePlatformTextProvider?
}

///|
pub(all) enum NativeTextEngineSetting {
  MoonCosmic
  PlatformDefault
} derive(Eq, Debug, ToJson)

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
priv struct GlyphAtlasEntry {
  x : Int
  y : Int
  width : Int
  height : Int
  bearing_x : Int
  bearing_y : Int
  format : NativeRasterGlyphFormat
}

///|
// Renderer-private glyph key. Platform providers own the payload encoding;
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
  priv width : Int
  priv height : Int
  priv bearing_x : Int
  priv bearing_y : Int
  priv format : NativeRasterGlyphFormat
  priv pixels : Bytes
}

///|
priv enum GlyphLookup {
  GlyphReady(GlyphAtlasEntry)
  GlyphMissing
  GlyphAtlasFull
}

///|
priv struct GlyphAtlas {
  width : Int
  height : Int
  padding : Int
  mut next_x : Int
  mut next_y : Int
  mut shelf_height : Int
  mut entries : Map[String, GlyphAtlasEntry]
  mut pixels : Array[Byte]
  mut dirty : Bool
}

///|
priv struct TextVertex {
  x : Double
  y : Double
  u : Double
  v : Double
  r : Double
  g : Double
  b : Double
  a : Double
  color_glyph : Double
}

///|
let text_vertex_stride : UInt64 = 36UL

///|
priv struct TextRunBuildResult {
  vertices : Array[TextVertex]
  atlas_full : Bool
}

///|
priv enum TextRunAppendResult {
  TextRunAppendComplete(Bool)
  TextRunAppendNeedsFallback
}

///|
fn NativeFontCache::new() -> NativeFontCache {
  NativeFontCache::new_with_engine(native_noop_text_engine())
}

///|
fn NativeFontCache::new_with_engine(
  text_engine : NativeTextEngine,
) -> NativeFontCache {
  { text_engine, measure_cache: Map([]), layout_cache: Map([]) }
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
  register_font_data? : (@core.FontFamily, Bytes) -> Unit = (_family, _data) => {
    ()
  },
) -> NativePlatformTextProvider {
  { id, measure, layout_run, raster_glyph, register_font_data }
}

///|
pub fn native_platform_text_engine(
  provider : NativePlatformTextProvider,
) -> NativeTextEngine {
  { provider, fallback: None }
}

///|
pub fn native_platform_text_engine_with_fallback(
  provider : NativePlatformTextProvider,
  fallback~ : NativeTextEngine,
) -> NativeTextEngine {
  { provider, fallback: Some(fallback.provider) }
}

///|
fn native_noop_text_engine() -> NativeTextEngine {
  native_platform_text_engine(
    NativePlatformTextProvider::new(
      id="native-wgpu-noop-text",
      measure=_input => None,
      layout_run=(_run, _scale_factor) => None,
      raster_glyph=(_cache_key, _payload) => None,
    ),
  )
}

///|
// Create a platform glyph key. The renderer treats payload as opaque data and
// passes it back to the provider's raster callback.
pub fn native_platform_glyph_key(
  cache_key~ : String,
  payload~ : Bytes,
) -> NativeGlyphKey {
  { cache_key, payload }
}

///|
// Create a positioned platform glyph in logical run coordinates.
pub fn NativeGlyphPlacement::new(
  key~ : NativeGlyphKey,
  x~ : Double,
  y? : Double = 0.0,
) -> NativeGlyphPlacement {
  { key, x, y }
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
// filtered by the renderer and trigger fallback.
pub fn NativeTextLayout::new(
  size~ : @core.Size,
  baseline~ : Double,
  caret_positions? : Array[Double] = [],
  glyphs? : Array[NativeGlyphPlacement] = [],
) -> NativeTextLayout {
  { size, baseline, caret_positions, glyphs }
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
// Create a provider raster glyph. The renderer validates dimensions against the
// pixel buffer before uploading it to the atlas.
pub fn NativeRasterGlyph::new(
  width~ : Int,
  height~ : Int,
  bearing_x~ : Int,
  bearing_y~ : Int,
  format? : NativeRasterGlyphFormat = NativeRasterGlyphFormat::AlphaMask,
  pixels~ : Bytes,
) -> NativeRasterGlyph {
  { width, height, bearing_x, bearing_y, format, pixels }
}

///|
pub fn NativeRasterGlyph::width(self : NativeRasterGlyph) -> Int {
  self.width
}

///|
pub fn NativeRasterGlyph::height(self : NativeRasterGlyph) -> Int {
  self.height
}

///|
pub fn NativeRasterGlyph::bearing_x(self : NativeRasterGlyph) -> Int {
  self.bearing_x
}

///|
pub fn NativeRasterGlyph::bearing_y(self : NativeRasterGlyph) -> Int {
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
