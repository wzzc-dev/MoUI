///|
/// Replayable CPU render command.
pub enum RenderCommand {
  Clear(@graphics.Color)
  FillRect(Double, Double, Double, Double, @graphics.Paint)
  StrokeRect(Double, Double, Double, Double, @graphics.Paint)
  FillPath(@graphics.Path, @graphics.Paint)
  StrokePath(@graphics.Path, @graphics.Paint)
  DrawPixmap(@graphics.Pixmap, Int, Int, @graphics.Paint)
  DrawPixmapKeyed(String, @graphics.Pixmap, Int, Int, @graphics.Paint)
  DrawBmpBytesKeyed(String, Bytes, Int, Int, @graphics.Paint)
  DrawPngBytesKeyed(String, Bytes, Int, Int, @graphics.Paint)
  DrawRgbaBytesKeyed(String, Bytes, Int, Int, Int, Int, @graphics.Paint)
  DrawSampledBmpBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawSampledPngBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawSampledRgbaBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawQualityBmpBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawQualityBmpBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawQualityPngBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawQualityPngBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawQualityRgbaBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawQualityRgbaBytesRectKeyed(
    String,
    Bytes,
    Int,
    Int,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawTransformedSampledBmpBytesKeyed(
    String,
    Bytes,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawTransformedSampledBmpBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawTransformedQualityBmpBytesKeyed(
    String,
    Bytes,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawTransformedQualityBmpBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawTransformedSampledPngBytesKeyed(
    String,
    Bytes,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawTransformedSampledPngBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawTransformedQualityPngBytesKeyed(
    String,
    Bytes,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawTransformedQualityPngBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawTransformedSampledRgbaBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawTransformedSampledRgbaBytesRectKeyed(
    String,
    Bytes,
    Int,
    Int,
    @graphics.PixelRect,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawTransformedQualityRgbaBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawTransformedQualityRgbaBytesRectKeyed(
    String,
    Bytes,
    Int,
    Int,
    @graphics.PixelRect,
    Double,
    Double,
    Double,
    Double,
    @graphics.Paint,
    @graphics.ImageQuality
  )
  DrawSampledBmpBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawSampledPngBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawSampledRgbaBytesRectKeyed(
    String,
    Bytes,
    Int,
    Int,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawBmpBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    @graphics.Paint
  )
  DrawPngBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    @graphics.Paint
  )
  DrawRgbaBytesRectKeyed(
    String,
    Bytes,
    Int,
    Int,
    @graphics.PixelRect,
    Int,
    Int,
    @graphics.Paint
  )
  DrawTiledBmpBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint
  )
  DrawTiledPngBytesRectKeyed(
    String,
    Bytes,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint
  )
  DrawTiledRgbaBytesRectKeyed(
    String,
    Bytes,
    Int,
    Int,
    @graphics.PixelRect,
    Int,
    Int,
    Int,
    Int,
    @graphics.Paint
  )
  DrawNinePatchBmpBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    @graphics.NinePatchInsets,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawNinePatchPngBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    @graphics.NinePatchInsets,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawNinePatchRgbaBytesKeyed(
    String,
    Bytes,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    @graphics.NinePatchInsets,
    @graphics.Paint,
    @graphics.ImageSampling
  )
  DrawPixmapRect(
    @graphics.Pixmap,
    @graphics.PixelRect,
    Int,
    Int,
    @graphics.Paint
  )
  DrawPixmapRectKeyed(
    String,
    @graphics.Pixmap,
    @graphics.PixelRect,
    Int,
    Int,
    @graphics.Paint
  )
  DrawTextFace(
    @text.FontFace,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawTextFaceKeyed(
    String,
    @text.FontFace,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawFontBytesKeyed(
    String,
    Bytes,
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawFontBytesAtlasKeyed(
    String,
    Bytes,
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawFontBytesFallbackKeyed(
    Array[FontBytesFallbackSource],
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawFontBytesFallbackAtlasKeyed(
    Array[FontBytesFallbackSource],
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawLoadedFontKeyed(
    String,
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawLoadedFontFallbackKeyed(
    Array[String],
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawLoadedFontFallbackAtlasKeyed(
    Array[String],
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
  DrawLoadedFontAtlasKeyed(
    String,
    String,
    String,
    Double,
    Double,
    @text.LayoutConfig,
    @graphics.Paint
  )
} derive(Debug)

///|
pub extend RenderCommand with Debug::{to_repr}

///|
/// Ordered list of CPU render commands.
pub struct RenderPipeline {
  commands : Array[RenderCommand]
} derive(Debug)

///|
pub extend RenderPipeline with Debug::{to_repr}

///|
/// Telemetry returned after replaying a render pipeline.
pub struct RenderPipelineReplayResult {
  command_count : Int
  clear_count : Int
  fill_count : Int
  stroke_count : Int
  image_count : Int
  text_count : Int
} derive(Eq, Debug)

///|
pub extend RenderPipelineReplayResult with Debug::{to_repr}

///|
pub extend RenderPipelineReplayResult with Eq::{not_equal, equal}

///|
/// Error returned by checked plain render-pipeline replay.
pub(all) enum RenderPipelineReplayError {
  ImageDecodeFailed(String, @graphics.PixmapDecodeError)
  FontParseFailed(String, @text.FontParseError)
  FontLoaderRequired(String)
} derive(Eq, Debug)

///|
pub extend RenderPipelineReplayError with Debug::{to_repr}

///|
pub extend RenderPipelineReplayError with Eq::{not_equal, equal}

///|
/// Telemetry returned after replaying a pipeline through RendererResources.
pub struct RenderPipelineResourceReplayResult {
  replay_result : RenderPipelineReplayResult
  keyed_font_count : Int
  font_cache_hit_count : Int
  font_parse_count : Int
  keyed_image_count : Int
  image_cache_hit_count : Int
  image_cache_insert_count : Int
  keyed_text_count : Int
  text_cache_hit_count : Int
  text_mask_render_count : Int
  keyed_atlas_text_count : Int
  glyph_cache_hit_count : Int
  glyph_mask_render_count : Int
  atlas_cache_hit_count : Int
  atlas_insert_count : Int
  atlas_clear_count : Int
} derive(Eq, Debug)

///|
pub extend RenderPipelineResourceReplayResult with Debug::{to_repr}

///|
pub extend RenderPipelineResourceReplayResult with Eq::{not_equal, equal}

///|
/// Error returned by checked RendererResources pipeline replay.
pub(all) enum RenderPipelineResourceReplayError {
  ImageDecodeFailed(String, @graphics.PixmapDecodeError)
  FontDataMissing(String)
  FontFileReadFailed(String, String)
  FontParseFailed(String, @text.FontParseError)
  FontLoaderRequired(String)
} derive(Eq, Debug)

///|
pub extend RenderPipelineResourceReplayError with Debug::{to_repr}

///|
pub extend RenderPipelineResourceReplayError with Eq::{not_equal, equal}

///|
/// Conservative CPU-side analysis of a render pipeline before replay.
pub struct RenderPipelineAnalysis {
  command_count : Int
  clear_count : Int
  fill_count : Int
  stroke_count : Int
  image_count : Int
  text_count : Int
  dirty_region : @graphics.DirtyRegion
} derive(Debug)

///|
pub extend RenderPipelineAnalysis with Debug::{to_repr}

///|
/// Conservative diff between two retained render pipelines.
pub struct RenderPipelineDiffResult {
  previous_command_count : Int
  next_command_count : Int
  retained_command_count : Int
  changed_command_count : Int
  inserted_command_count : Int
  removed_command_count : Int
  dirty_region : @graphics.DirtyRegion
} derive(Debug)

///|
pub extend RenderPipelineDiffResult with Debug::{to_repr}

///|
/// Coarse command category used by CPU batch scheduling.
pub(all) enum RenderPipelineBatchKind {
  Clear
  Fill
  Stroke
  Image
  Text
} derive(Eq, Debug)

///|
pub extend RenderPipelineBatchKind with Debug::{to_repr}

///|
pub extend RenderPipelineBatchKind with Eq::{not_equal, equal}

///|
/// One contiguous run of commands with the same scheduling category.
pub struct RenderPipelineBatch {
  kind : RenderPipelineBatchKind
  start_index : Int
  command_count : Int
  dirty_region : @graphics.DirtyRegion
} derive(Debug)

///|
pub extend RenderPipelineBatch with Debug::{to_repr}

///|
/// Scheduler-facing grouping of a render pipeline into contiguous CPU batches.
pub struct RenderPipelineBatchPlan {
  command_count : Int
  batches : Array[RenderPipelineBatch]
  dirty_region : @graphics.DirtyRegion
} derive(Debug)

///|
pub extend RenderPipelineBatchPlan with Debug::{to_repr}

///|
/// One image resource use discovered before replaying a render pipeline.
pub struct RenderPipelineImageDependency {
  command_index : Int
  resource_key : String?
  source_width : Int
  source_height : Int
  source_pixel_count : Int
} derive(Debug)

///|
pub extend RenderPipelineImageDependency with Debug::{to_repr}

///|
/// One parsed-font text resource use discovered before replaying a pipeline.
pub struct RenderPipelineTextDependency {
  command_index : Int
  resource_key : String?
  text_byte_count : Int
  run_count : Int
  glyph_count : Int
  layout_width : Double
  layout_height : Double
} derive(Debug)

///|
pub extend RenderPipelineTextDependency with Debug::{to_repr}

///|
/// One keyed font resource use discovered before replaying a pipeline.
pub struct RenderPipelineFontDependency {
  command_index : Int
  font_key : String
  font_byte_count : Int
} derive(Debug)

///|
pub extend RenderPipelineFontDependency with Debug::{to_repr}

///|
/// Resource dependencies that can be pre-resolved from existing commands.
pub struct RenderPipelineResourcePlan {
  command_count : Int
  font_dependencies : Array[RenderPipelineFontDependency]
  image_dependencies : Array[RenderPipelineImageDependency]
  text_dependencies : Array[RenderPipelineTextDependency]
} derive(Debug)

///|
pub extend RenderPipelineResourcePlan with Debug::{to_repr}
