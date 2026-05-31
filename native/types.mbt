///|
/// Native Skia image.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Image {
  priv handle : ImageHandle
}

///|
/// Immutable encoded or raw byte data owned by Skia.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Data {
  priv handle : DataHandle
}

///|
/// Native Skia codec for encoded image data.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Codec {
  priv handle : CodecHandle
}

///|
/// Native Skia path.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Path {
  priv handle : PathHandle
}

///|
/// Native Skia font.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Font {
  priv handle : FontHandle
}

///|
/// Native Skia shaped text run.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct ShapedTextRun {
  priv handle : ShapedTextRunHandle
}

///|
/// Native Skia glyph identifier.
pub(all) struct GlyphId(UInt16) derive(Debug, Eq)

///|
pub fn GlyphId::new(value : UInt16) -> GlyphId {
  GlyphId(value)
}

///|
pub fn GlyphId::to_uint16(self : GlyphId) -> UInt16 {
  let GlyphId(value) = self
  value
}

///|
pub fn GlyphId::to_int(self : GlyphId) -> Int {
  self.to_uint16().to_int()
}

///|
/// Native Skia font metrics in y-down coordinates.
pub(all) struct FontMetrics {
  top : Float
  ascent : Float
  descent : Float
  bottom : Float
  leading : Float
  average_char_width : Float
  max_char_width : Float
  x_min : Float
  x_max : Float
  x_height : Float
  cap_height : Float
  underline_thickness : Float?
  underline_position : Float?
  strikeout_thickness : Float?
  strikeout_position : Float?
  has_bounds : Bool
} derive(Debug, Eq)

///|
/// Native Skia typeface.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Typeface {
  priv handle : TypefaceHandle
}

///|
/// Native Skia font manager.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct FontMgr {
  priv handle : FontMgrHandle
}

///|
/// Native Skia shader.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Shader {
  priv handle : ShaderHandle
}

///|
/// Native Skia color filter.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct ColorFilter {
  priv handle : ColorFilterHandle
}

///|
/// Native Skia image filter.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct ImageFilter {
  priv handle : ImageFilterHandle
}

///|
/// Native Skia mask filter.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct MaskFilter {
  priv handle : MaskFilterHandle
}

///|
/// Native Skia bitmap with owned pixel storage.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Bitmap {
  priv handle : BitmapHandle
}

///|
/// Native raster surface. The handle owns a Skia `SkSurface` when Skia is linked.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Surface {
  priv handle : SurfaceHandle
}

///|
/// Canvas borrowed from a native surface.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Canvas {
  priv handle : CanvasHandle
  priv owner : Surface?
}

///|
/// Summary of replaying a value-layer render command list into a native Canvas.
pub(all) struct CanvasReplayStats {
  command_count : Int
  replayed_count : Int
  skipped_count : Int
  draw_count : Int
  text_count : Int
  present_count : Int
} derive(Debug, Eq)

///|
pub fn CanvasReplayStats::empty() -> CanvasReplayStats {
  {
    command_count: 0,
    replayed_count: 0,
    skipped_count: 0,
    draw_count: 0,
    text_count: 0,
    present_count: 0,
  }
}

///|
pub fn CanvasReplayStats::is_complete(self : CanvasReplayStats) -> Bool {
  self.skipped_count == 0
}
