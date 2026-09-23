// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend BlendMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BmpInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend Canvas with Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasEdge with Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasState with Debug::{to_repr}

///|
#doc(hidden)
pub extend Color with Debug::{to_repr}

///|
#doc(hidden)
pub extend Color with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Color with Show::{to_string, output}

///|
#doc(hidden)
pub extend DashCursor with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtyPresentPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtyPresentPlanMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtyPresentPlanMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DirtyPresentStrategy with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtyPresentStrategy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DirtyRegion with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtySubmitPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtySubmitResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtySubmitState with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirtySubmitState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FillRule with Debug::{to_repr}

///|
#doc(hidden)
pub extend FillRule with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageQuality with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageQuality with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageSampling with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageSampling with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Layer with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayerCompositeResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayerTree with Debug::{to_repr}

///|
#doc(hidden)
pub extend MemoryPresentRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend MemoryPresentRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MemorySurface with Debug::{to_repr}

///|
#doc(hidden)
pub extend NinePatchInsets with Debug::{to_repr}

///|
#doc(hidden)
pub extend NinePatchInsets with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NinePatchSlices with Debug::{to_repr}

///|
#doc(hidden)
pub extend Paint with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintFilter with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintFilter with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintFilterType with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintFilterType with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintGradientStop with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintGradientStop with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintShader with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintShader with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintShaderSpread with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintShaderSpread with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintShaderType with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintShaderType with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Path with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathBooleanOp with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathBooleanOp with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathSegment with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathSegment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PixelRect with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixelRect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Pixmap with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixmapCache with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixmapCacheDecodeResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixmapCacheInsertResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixmapDecodeError with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixmapDecodeError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PixmapEncodeError with Debug::{to_repr}

///|
#doc(hidden)
pub extend PixmapEncodeError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PngDeflateBitReader with Debug::{to_repr}

///|
#doc(hidden)
pub extend PngDeflateHuffman with Debug::{to_repr}

///|
#doc(hidden)
pub extend PngDeflateHuffmanEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend PngDeflateTables with Debug::{to_repr}

///|
#doc(hidden)
pub extend PngHeader with Debug::{to_repr}

///|
#doc(hidden)
pub extend PngInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend Point with Debug::{to_repr}

///|
#doc(hidden)
pub extend Point with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentBatch with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentBatchSubmitPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentBatchSubmitResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentError with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentRectInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentRectInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentRectPayload with Debug::{to_repr}

///|
#doc(hidden)
pub extend Rect with Debug::{to_repr}

///|
#doc(hidden)
pub extend Rect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrame with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameLayerClearRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameLayerClearRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameLayerReplacementRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameSchedule with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameScheduleAction with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameScheduleAction with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameSubmitPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameSubmitPolicy with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameSubmitPolicy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameSubmitRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameSubmitResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend Size with Debug::{to_repr}

///|
#doc(hidden)
pub extend Size with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend StrokeCap with Debug::{to_repr}

///|
#doc(hidden)
pub extend StrokeCap with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend StrokeEndpoint with Debug::{to_repr}

///|
#doc(hidden)
pub extend StrokeJoin with Debug::{to_repr}

///|
#doc(hidden)
pub extend StrokeJoin with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend StrokeJoinPoint with Debug::{to_repr}

///|
#doc(hidden)
pub extend StrokePathData with Debug::{to_repr}

///|
#doc(hidden)
pub extend Transform with Debug::{to_repr}

///|
#doc(hidden)
pub extend Transform with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Vec2 with Debug::{to_repr}

///|
#doc(hidden)
pub extend Vec2 with Eq::{not_equal, equal}
