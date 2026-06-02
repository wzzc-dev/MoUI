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
/// Native typeface plus the value-layer fallback metadata that resolved it.
pub(all) struct ResolvedTypeface {
  typeface : Typeface
  resolution : @skia.FontFallbackResolutionDescriptor
}

///|
pub fn ResolvedTypeface::is_available(self : ResolvedTypeface) -> Bool {
  self.typeface.is_available() && self.resolution.is_valid()
}

///|
pub fn ResolvedTypeface::font_descriptor(
  self : ResolvedTypeface,
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
) -> @skia.FontDescriptor {
  self.resolution.font_descriptor(size~, scale_x~, skew_x~)
}

///|
pub fn ResolvedTypeface::resource_plan(
  self : ResolvedTypeface,
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
  request_byte_size? : Int64 = -1L,
  resolution_byte_size? : Int64 = -1L,
  match_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = -1L,
) -> @skia.RendererResourcePlan {
  self.resolution.resource_plan(
    size~,
    scale_x~,
    skew_x~,
    request_byte_size~,
    resolution_byte_size~,
    match_byte_size~,
    font_byte_size~,
  )
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
/// Native support decision for creating a surface from a value-layer target.
pub(all) enum SurfaceTargetSupportStatus {
  SurfaceTargetSupported
  SurfaceTargetEmpty
  SurfaceTargetSkiaUnavailable
  SurfaceTargetWindowUnsupported
  SurfaceTargetGpuUnsupported
} derive(Debug, Eq)

///|
pub fn SurfaceTargetSupportStatus::is_supported(
  self : SurfaceTargetSupportStatus,
) -> Bool {
  self is SurfaceTargetSupported
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

///|
fn canvas_replay_skipped_stats(
  commands : @skia.RenderCommandList,
) -> CanvasReplayStats {
  let mut command_count = 0
  let mut skipped_count = 0
  let mut draw_count = 0
  let mut text_count = 0
  let mut present_count = 0
  for command in commands.commands {
    command_count += 1
    if command.is_draw() {
      draw_count += 1
    }
    if command.is_text() {
      text_count += 1
    }
    if command.is_present() {
      present_count += 1
    } else if !command.is_resource_declaration() {
      skipped_count += 1
    }
  }
  {
    command_count,
    replayed_count: 0,
    skipped_count,
    draw_count,
    text_count,
    present_count,
  }
}

///|
/// Summary of rendering a value-layer frame through a native surface boundary.
pub(all) struct SurfaceFrameReplayStats {
  replay : CanvasReplayStats
  validation_status : @skia.RenderFrameValidationStatus
  surface_matches : Bool
  finalized : Bool
} derive(Debug, Eq)

///|
pub fn SurfaceFrameReplayStats::is_complete(
  self : SurfaceFrameReplayStats,
) -> Bool {
  self.validation_status.is_ready() &&
  self.surface_matches &&
  self.replay.is_complete() &&
  self.finalized
}

///|
/// Native resource caches shared across one or more Canvas replay calls.
pub(all) struct NativeReplayResources {
  image_cache : @skia.ResourceCache[@skia.RendererResourceKey, Image]
  shader_cache : @skia.ResourceCache[@skia.RendererResourceKey, Shader]
  path_cache : @skia.ResourceCache[@skia.RendererResourceKey, Path]
  text_run_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    NativeReplayTextRun,
  ]
  font_cache : @skia.ResourceCache[@skia.RendererResourceKey, Font]
  typeface_cache : @skia.ResourceCache[@skia.RendererResourceKey, Typeface]
  color_filter_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    ColorFilter,
  ]
  image_filter_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    ImageFilter,
  ]
  mask_filter_cache : @skia.ResourceCache[@skia.RendererResourceKey, MaskFilter]
}

///|
pub(all) enum NativeReplayTextRun {
  DirectTextRun(@skia.TextRunDescriptor)
  ShapedTextRun(@skia.ShapedGlyphRunDescriptor)
}

///|
pub fn NativeReplayResources::new(
  image_max_bytes? : Int64 = 0L,
  shader_max_bytes? : Int64 = 0L,
  path_max_bytes? : Int64 = 0L,
  text_run_max_bytes? : Int64 = 0L,
  font_max_bytes? : Int64 = 0L,
  typeface_max_bytes? : Int64 = 0L,
  color_filter_max_bytes? : Int64 = 0L,
  image_filter_max_bytes? : Int64 = 0L,
  mask_filter_max_bytes? : Int64 = 0L,
) -> NativeReplayResources {
  {
    image_cache: @skia.ResourceCache::new(max_bytes=image_max_bytes),
    shader_cache: @skia.ResourceCache::new(max_bytes=shader_max_bytes),
    path_cache: @skia.ResourceCache::new(max_bytes=path_max_bytes),
    text_run_cache: @skia.ResourceCache::new(max_bytes=text_run_max_bytes),
    font_cache: @skia.ResourceCache::new(max_bytes=font_max_bytes),
    typeface_cache: @skia.ResourceCache::new(max_bytes=typeface_max_bytes),
    color_filter_cache: @skia.ResourceCache::new(
      max_bytes=color_filter_max_bytes,
    ),
    image_filter_cache: @skia.ResourceCache::new(
      max_bytes=image_filter_max_bytes,
    ),
    mask_filter_cache: @skia.ResourceCache::new(max_bytes=mask_filter_max_bytes),
  }
}
