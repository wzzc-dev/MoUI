///|
// The renderer-neutral native text model (engine, provider callbacks, glyph
// key/placement/layout/raster values, and the memoizing cache) lives in
// `wzzc-dev/moui/render/native_text`. The types this package's own API names
// are re-exported here so host entrypoints keep reaching them through the
// renderer they compose with; platform text providers import the neutral
// package directly instead of this one.
pub using @native_text {
  type NativeGlyphKey,
  type NativeGlyphPlacement,
  type NativePlatformTextProvider,
  type NativeRasterGlyph,
  type NativeRasterGlyphFormat,
  type NativeTextEngine,
  type NativeTextLayout,
  native_platform_glyph_key,
  native_platform_text_engine,
  native_platform_text_engine_with_fallback,
  native_text_system,
  native_text_system_with_engine,
}

///|
using @native_text {
  type NativeTextCache,
  native_noop_text_engine,
  native_text_system_with_cache,
}

///|
let atlas_width : Int32 = 1024

///|
let atlas_height : Int32 = 1024

///|
let atlas_padding : Int32 = 1

///|
pub(all) enum NativeTextEngineSetting {
  MoonCosmic
  PlatformDefault
} derive(Eq, Debug, ToJson)

///|
pub extend NativeTextEngineSetting with Debug::{to_repr}

///|
pub extend NativeTextEngineSetting with Eq::{not_equal, equal}

///|
pub extend NativeTextEngineSetting with ToJson::{to_json}

///|
priv struct GlyphAtlasEntry {
  x : Int32
  y : Int32
  width : Int32
  height : Int32
  bearing_x : Int32
  bearing_y : Int32
  format : NativeRasterGlyphFormat
}

///|
priv enum GlyphLookup {
  GlyphReady(GlyphAtlasEntry)
  GlyphMissing
  GlyphAtlasFull
}

///|
priv struct GlyphAtlas {
  width : Int32
  height : Int32
  padding : Int32
  mut next_x : Int32
  mut next_y : Int32
  mut shelf_height : Int32
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
