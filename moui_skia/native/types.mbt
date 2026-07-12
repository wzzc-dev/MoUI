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
/// Native SkParagraph layout.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Paragraph {
  priv handle : ParagraphHandle
}

///|
/// SkParagraph line metrics exposed with UTF-8 byte ranges.
pub(all) struct ParagraphLineMetric {
  start : Int
  end : Int
  end_excluding_whitespace : Int
  end_including_newline : Int
  line_number : Int
  hard_break : Bool
  left : Float
  width : Float
  baseline : Float
  ascent : Float
  descent : Float
  height : Float
} derive(Debug, Eq)

///|
pub fn ParagraphLineMetric::right(self : ParagraphLineMetric) -> Float {
  self.left + self.width
}

///|
pub fn ParagraphLineMetric::is_valid(self : ParagraphLineMetric) -> Bool {
  self.start >= 0 &&
  self.end >= self.start &&
  self.line_number >= 0 &&
  self.width >= 0.0 &&
  self.height > 0.0
}

///|
/// SkParagraph hit-test result exposed as a UTF-8 byte offset.
pub(all) struct ParagraphHitTestResult {
  offset : Int
  downstream : Bool
} derive(Debug, Eq)

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
/// Native Skia GPU context. The handle owns a Ganesh direct context when a GPU
/// backend is linked.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct GpuContext {
  priv handle : GpuContextHandle
  descriptor : @skia.GpuContextDescriptor
}

///|
/// Native raster or GPU surface. The handle owns a Skia `SkSurface` when Skia is linked.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Surface {
  priv handle : SurfaceHandle
  descriptor : @skia.SurfaceDescriptor
}

///|
/// Native support decision for creating a surface from a value-layer target.
pub(all) enum SurfaceTargetSupportStatus {
  SurfaceTargetSupported
  SurfaceTargetEmpty
  SurfaceTargetSkiaUnavailable
  SurfaceTargetWindowUnsupported
  SurfaceTargetGpuUnsupported
  SurfaceTargetMissingGpuContext
  SurfaceTargetGpuContextMismatch
  SurfaceTargetGpuContextUnsupported
} derive(Debug, Eq)

///|
pub fn SurfaceTargetSupportStatus::is_supported(
  self : SurfaceTargetSupportStatus,
) -> Bool {
  self is SurfaceTargetSupported
}

///|
/// Native diagnostic status for a value-layer GPU context descriptor.
pub(all) enum SkiaGpuContextSupportStatus {
  SkiaGpuContextAvailable
  SkiaGpuContextSkiaUnavailable
  SkiaGpuContextAnonymous
  SkiaGpuContextMockUnsupported
  SkiaGpuContextBackendUnsupported
  SkiaGpuContextMetalOptInDisabled
  SkiaGpuContextMetalHeadersUnavailable
  SkiaGpuContextMetalRuntimeUnavailable
  SkiaGpuContextDirect3DOptInDisabled
  SkiaGpuContextDirect3DHeadersUnavailable
  SkiaGpuContextDirect3DRuntimeUnavailable
  SkiaGpuContextVulkanOptInDisabled
  SkiaGpuContextVulkanHeadersUnavailable
  SkiaGpuContextVulkanRuntimeUnavailable
} derive(Debug, Eq)

///|
pub fn SkiaGpuContextSupportStatus::is_available(
  self : SkiaGpuContextSupportStatus,
) -> Bool {
  self is SkiaGpuContextAvailable
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
  state_count : Int
  transform_count : Int
  clip_count : Int
  clear_count : Int
  text_count : Int
  present_count : Int
  resource_declaration_count : Int
  image_resource_count : Int
  shader_resource_count : Int
  filter_resource_count : Int
  path_resource_count : Int
  text_resource_count : Int
} derive(Debug, Eq)

///|
/// Coarse outcome for replaying commands into a native Canvas.
pub(all) enum CanvasReplayStatus {
  CanvasReplayComplete
  CanvasReplayDeferredPresent
  CanvasReplaySkippedCommands
} derive(Debug, Eq)

///|
pub fn CanvasReplayStatus::is_complete(self : CanvasReplayStatus) -> Bool {
  self is (CanvasReplayComplete | CanvasReplayDeferredPresent)
}

///|
pub fn CanvasReplayStats::empty() -> CanvasReplayStats {
  {
    command_count: 0,
    replayed_count: 0,
    skipped_count: 0,
    draw_count: 0,
    state_count: 0,
    transform_count: 0,
    clip_count: 0,
    clear_count: 0,
    text_count: 0,
    present_count: 0,
    resource_declaration_count: 0,
    image_resource_count: 0,
    shader_resource_count: 0,
    filter_resource_count: 0,
    path_resource_count: 0,
    text_resource_count: 0,
  }
}

///|
pub fn CanvasReplayStats::is_complete(self : CanvasReplayStats) -> Bool {
  self.status().is_complete()
}

///|
pub fn CanvasReplayStats::status(
  self : CanvasReplayStats,
) -> CanvasReplayStatus {
  if self.skipped_count > 0 {
    CanvasReplaySkippedCommands
  } else if self.present_count > 0 {
    CanvasReplayDeferredPresent
  } else {
    CanvasReplayComplete
  }
}

///|
priv struct CanvasReplayCommandResourceCounts {
  image_resource_count : Int
  shader_resource_count : Int
  filter_resource_count : Int
  path_resource_count : Int
  text_resource_count : Int
}

///|
fn canvas_replay_command_resource_counts(
  command : @skia.RenderCommand,
) -> CanvasReplayCommandResourceCounts {
  let mut image_resource_count = 0
  let mut shader_resource_count = 0
  let mut filter_resource_count = 0
  let mut path_resource_count = 0
  let mut text_resource_count = 0
  for descriptor in command.resource_descriptors() {
    match descriptor.key.kind {
      ImageResource => image_resource_count += 1
      ShaderResource => shader_resource_count += 1
      PathResource => path_resource_count += 1
      ColorFilterResource | ImageFilterResource | MaskFilterResource =>
        filter_resource_count += 1
      TypefaceResource | FontResource | TextRunResource =>
        text_resource_count += 1
      _ => ()
    }
  }
  {
    image_resource_count,
    shader_resource_count,
    filter_resource_count,
    path_resource_count,
    text_resource_count,
  }
}

///|
fn canvas_replay_skipped_stats(
  commands : @skia.RenderCommandList,
) -> CanvasReplayStats {
  let mut command_count = 0
  let mut skipped_count = 0
  let mut draw_count = 0
  let mut state_count = 0
  let mut transform_count = 0
  let mut clip_count = 0
  let mut clear_count = 0
  let mut text_count = 0
  let mut present_count = 0
  let mut resource_declaration_count = 0
  let mut image_resource_count = 0
  let mut shader_resource_count = 0
  let mut filter_resource_count = 0
  let mut path_resource_count = 0
  let mut text_resource_count = 0
  for command in commands.commands {
    command_count += 1
    if command.is_draw() {
      draw_count += 1
    }
    if command.is_state() {
      state_count += 1
    }
    if command.is_transform() {
      transform_count += 1
    }
    if command.is_clip() {
      clip_count += 1
    }
    if command.is_clear() {
      clear_count += 1
    }
    if command.is_text() {
      text_count += 1
    }
    if command.is_resource_declaration() {
      resource_declaration_count += 1
    }
    let resource_counts = canvas_replay_command_resource_counts(command)
    image_resource_count += resource_counts.image_resource_count
    shader_resource_count += resource_counts.shader_resource_count
    filter_resource_count += resource_counts.filter_resource_count
    path_resource_count += resource_counts.path_resource_count
    text_resource_count += resource_counts.text_resource_count
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
    state_count,
    transform_count,
    clip_count,
    clear_count,
    text_count,
    present_count,
    resource_declaration_count,
    image_resource_count,
    shader_resource_count,
    filter_resource_count,
    path_resource_count,
    text_resource_count,
  }
}

///|
/// Summary of rendering a value-layer frame through a native surface boundary.
pub(all) struct SurfaceFrameReplayStats {
  replay : CanvasReplayStats
  validation_status : @skia.RenderFrameValidationStatus
  surface_matches : Bool
  finalization : @skia.RenderFrameFinalizationDescriptor
  finalized : Bool
} derive(Debug, Eq)

///|
/// Coarse outcome for rendering a value-layer frame through a native surface.
pub(all) enum SurfaceFrameReplayStatus {
  SurfaceFrameReplayComplete
  SurfaceFrameReplayValidationFailed(@skia.RenderFrameValidationStatus)
  SurfaceFrameReplaySurfaceMismatch
  SurfaceFrameReplaySkippedCommands
  SurfaceFrameReplayFinalizationFailed
} derive(Debug, Eq)

///|
pub fn SurfaceFrameReplayStatus::is_complete(
  self : SurfaceFrameReplayStatus,
) -> Bool {
  self is SurfaceFrameReplayComplete
}

///|
pub fn SurfaceFrameReplayStats::status(
  self : SurfaceFrameReplayStats,
) -> SurfaceFrameReplayStatus {
  if !self.validation_status.is_ready() {
    SurfaceFrameReplayValidationFailed(self.validation_status)
  } else if !self.surface_matches {
    SurfaceFrameReplaySurfaceMismatch
  } else if !self.replay.is_complete() {
    SurfaceFrameReplaySkippedCommands
  } else if !self.finalized {
    SurfaceFrameReplayFinalizationFailed
  } else {
    SurfaceFrameReplayComplete
  }
}

///|
pub fn SurfaceFrameReplayStats::is_complete(
  self : SurfaceFrameReplayStats,
) -> Bool {
  self.status().is_complete()
}

///|
pub fn SurfaceFrameReplayStats::finalization_is_ready(
  self : SurfaceFrameReplayStats,
) -> Bool {
  self.finalization.is_ready()
}

///|
pub fn SurfaceFrameReplayStats::finalization_resource_plan(
  self : SurfaceFrameReplayStats,
) -> @skia.RendererResourcePlan {
  self.finalization.resource_plan
}

///|
/// Aggregate counters across the native replay resource caches.
pub(all) struct NativeReplayResourceStats {
  cache_count : Int
  resource_count : Int
  byte_size : Int64
  max_bytes : Int64
  hits : Int
  misses : Int
  evictions : Int
} derive(Debug, Eq)

///|
fn native_replay_resource_stats_empty() -> NativeReplayResourceStats {
  {
    cache_count: 0,
    resource_count: 0,
    byte_size: 0L,
    max_bytes: 0L,
    hits: 0,
    misses: 0,
    evictions: 0,
  }
}

///|
fn native_replay_resource_stats_add_cache(
  total : NativeReplayResourceStats,
  stats : @skia.ResourceCacheStats,
) -> NativeReplayResourceStats {
  {
    cache_count: total.cache_count + 1,
    resource_count: total.resource_count + stats.count,
    byte_size: total.byte_size + stats.byte_size,
    max_bytes: total.max_bytes + stats.max_bytes,
    hits: total.hits + stats.hits,
    misses: total.misses + stats.misses,
    evictions: total.evictions + stats.evictions,
  }
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

///|
pub fn NativeReplayResources::stats(
  self : NativeReplayResources,
) -> NativeReplayResourceStats {
  let stats = native_replay_resource_stats_empty()
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.image_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.shader_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.path_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.text_run_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.font_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.typeface_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.color_filter_cache.stats(),
  )
  let stats = native_replay_resource_stats_add_cache(
    stats,
    self.image_filter_cache.stats(),
  )
  native_replay_resource_stats_add_cache(stats, self.mask_filter_cache.stats())
}
