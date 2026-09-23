// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AddPathMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend AddPathMode with Default::{default}

///|
#doc(hidden)
pub extend AddPathMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AlphaType with Debug::{to_repr}

///|
#doc(hidden)
pub extend AlphaType with Default::{default}

///|
#doc(hidden)
pub extend AlphaType with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BlendMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendMode with Default::{default}

///|
#doc(hidden)
pub extend BlendMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ClipOp with Debug::{to_repr}

///|
#doc(hidden)
pub extend ClipOp with Default::{default}

///|
#doc(hidden)
pub extend ClipOp with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Color with Debug::{to_repr}

///|
#doc(hidden)
pub extend Color with Default::{default}

///|
#doc(hidden)
pub extend Color with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Color4f with Debug::{to_repr}

///|
#doc(hidden)
pub extend Color4f with Default::{default}

///|
#doc(hidden)
pub extend Color4f with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColorFilterDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorFilterDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColorInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorInfo with Default::{default}

///|
#doc(hidden)
pub extend ColorInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColorType with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorType with Default::{default}

///|
#doc(hidden)
pub extend ColorType with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CubicResampler with Debug::{to_repr}

///|
#doc(hidden)
pub extend CubicResampler with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EncodedImageFormat with Debug::{to_repr}

///|
#doc(hidden)
pub extend EncodedImageFormat with Default::{default}

///|
#doc(hidden)
pub extend EncodedImageFormat with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FilterMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend FilterMode with Default::{default}

///|
#doc(hidden)
pub extend FilterMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontFallbackChain with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFallbackChain with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontFallbackMatchDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFallbackMatchDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontFallbackRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFallbackRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontFallbackResolutionDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFallbackResolutionDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontStyleRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontStyleRequest with Default::{default}

///|
#doc(hidden)
pub extend FontStyleRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuContextBackend with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuContextBackend with Default::{default}

///|
#doc(hidden)
pub extend GpuContextBackend with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuContextDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuContextDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend IPoint with Debug::{to_repr}

///|
#doc(hidden)
pub extend IPoint with Default::{default}

///|
#doc(hidden)
pub extend IPoint with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend IRect with Debug::{to_repr}

///|
#doc(hidden)
pub extend IRect with Default::{default}

///|
#doc(hidden)
pub extend IRect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ISize with Debug::{to_repr}

///|
#doc(hidden)
pub extend ISize with Default::{default}

///|
#doc(hidden)
pub extend ISize with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageFilterDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageFilterDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageInfo with Default::{default}

///|
#doc(hidden)
pub extend ImageInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MaskFilterDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend MaskFilterDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Matrix with Debug::{to_repr}

///|
#doc(hidden)
pub extend Matrix with Default::{default}

///|
#doc(hidden)
pub extend Matrix with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MatrixMember with Debug::{to_repr}

///|
#doc(hidden)
pub extend MatrixMember with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MeasuredTextRunDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend MeasuredTextRunDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MipmapMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend MipmapMode with Default::{default}

///|
#doc(hidden)
pub extend MipmapMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Paint with Debug::{to_repr}

///|
#doc(hidden)
pub extend Paint with Default::{default}

///|
#doc(hidden)
pub extend Paint with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintStyle with Default::{default}

///|
#doc(hidden)
pub extend PaintStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Path with Debug::{to_repr}

///|
#doc(hidden)
pub extend Path with Default::{default}

///|
#doc(hidden)
pub extend Path with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathDirection with Default::{default}

///|
#doc(hidden)
pub extend PathDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathFillType with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathFillType with Default::{default}

///|
#doc(hidden)
pub extend PathFillType with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathLine with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathLine with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathRect with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathRect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathSegmentMask with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathSegmentMask with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathVerb with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathVerb with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Pixmap with Debug::{to_repr}

///|
#doc(hidden)
pub extend Pixmap with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Point with Debug::{to_repr}

///|
#doc(hidden)
pub extend Point with Default::{default}

///|
#doc(hidden)
pub extend Point with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PointMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend PointMode with Default::{default}

///|
#doc(hidden)
pub extend PointMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RRect with Debug::{to_repr}

///|
#doc(hidden)
pub extend RRect with Default::{default}

///|
#doc(hidden)
pub extend RRect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Rect with Debug::{to_repr}

///|
#doc(hidden)
pub extend Rect with Default::{default}

///|
#doc(hidden)
pub extend Rect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderCommandList with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderCommandList with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderCommandStats with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderCommandStats with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameFinalizationDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameFinalizationDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameSubmissionDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameSubmissionDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameValidationStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameValidationStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPassDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPassDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPassLoadOp with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPassLoadOp with Default::{default}

///|
#doc(hidden)
pub extend RenderPassLoadOp with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPassStoreOp with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPassStoreOp with Default::{default}

///|
#doc(hidden)
pub extend RenderPassStoreOp with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererResourceDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererResourceDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererResourceKey with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererResourceKey with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererResourceKey with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend RendererResourceKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererResourceKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererResourceKind with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend RendererResourcePlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererResourcePlan with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ResourceCacheStats with Debug::{to_repr}

///|
#doc(hidden)
pub extend ResourceCacheStats with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SamplingOptions with Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplingOptions with Default::{default}

///|
#doc(hidden)
pub extend SamplingOptions with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShaderDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShapedGlyphRunDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShapedGlyphRunDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShapedTextRunDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShapedTextRunDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Size with Debug::{to_repr}

///|
#doc(hidden)
pub extend Size with Default::{default}

///|
#doc(hidden)
pub extend Size with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend StrokeCap with Debug::{to_repr}

///|
#doc(hidden)
pub extend StrokeCap with Default::{default}

///|
#doc(hidden)
pub extend StrokeCap with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend StrokeJoin with Debug::{to_repr}

///|
#doc(hidden)
pub extend StrokeJoin with Default::{default}

///|
#doc(hidden)
pub extend StrokeJoin with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceBackend with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceBackend with Default::{default}

///|
#doc(hidden)
pub extend SurfaceBackend with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceBudget with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceBudget with Default::{default}

///|
#doc(hidden)
pub extend SurfaceBudget with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceFinalizationDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceFinalizationDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceOrigin with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceOrigin with Default::{default}

///|
#doc(hidden)
pub extend SurfaceOrigin with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfacePresentDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfacePresentDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfacePresentMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfacePresentMode with Default::{default}

///|
#doc(hidden)
pub extend SurfacePresentMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceTargetDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceTargetDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextDirection with Default::{default}

///|
#doc(hidden)
pub extend TextDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextMeasurementDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextMeasurementDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextRunDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextRunDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextShapingDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextShapingDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TileMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend TileMode with Default::{default}

///|
#doc(hidden)
pub extend TileMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowSurfaceDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowSurfaceDescriptor with Eq::{not_equal, equal}
