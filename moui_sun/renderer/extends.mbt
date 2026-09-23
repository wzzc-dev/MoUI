// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend CachedBmpPixmapDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedFontAtlasDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedFontFallbackAtlasDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedFontFallbackDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedFontTextDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedPixmapDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedPngPixmapDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend CachedRgbaPixmapDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontBytesFallbackSource with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipeline with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineAnalysis with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineBatch with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineBatchKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineBatchKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPipelineBatchPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineDiffResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineFontDependency with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineImageDependency with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineReplayError with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineReplayError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPipelineReplayResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineReplayResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPipelineResourcePlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineResourceReplayError with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineResourceReplayError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPipelineResourceReplayResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineResourceReplayResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPipelineTextDependency with Debug::{to_repr}

///|
#doc(hidden)
pub extend Renderer with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererResources with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererResourcesSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererTextResources with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererTextResourcesSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextAtlasDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextFallbackAtlasDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextFallbackDrawResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextMaskDrawResult with Debug::{to_repr}
