// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend FrameToken with Debug::{to_repr}

///|
#doc(hidden)
pub extend FrameToken with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FrameToken with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageResourceLoadCompletion with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageResourceLoadCompletion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageResourceLoadCompletion with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageResourceLoadCompletionStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageResourceLoadCompletionStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageResourceLoadCompletionStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageResourceRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageResourceRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageResourceRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageResourceStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageResourceStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageResourceStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend RectBatch with Debug::{to_repr}

///|
#doc(hidden)
pub extend RectBatch with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RectBatch with ToJson::{to_json}

///|
#doc(hidden)
pub extend RectVertex with Debug::{to_repr}

///|
#doc(hidden)
pub extend RectVertex with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RectVertex with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderFrameInput with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameInput with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameInput with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderFrameResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderPresentCompletion with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPresentCompletion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPresentCompletion with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderPresentStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPresentStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderPresentStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderWindowId with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderWindowId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderWindowId with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererBackendFeatureCapability with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererBackendFeatureCapability with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererBackendFeatureCapability with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererBackendInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererBackendInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererBackendInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererBackendKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererBackendKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererBackendKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererCapabilityStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererCapabilityStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererCapabilityStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererCommandFallback with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererCommandFallback with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererCommandFallback with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererCommandFallbackKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererCommandFallbackKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererCommandFallbackKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererCommandPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererCommandPlan with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererCommandPlan with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererControlMessage with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererControlMessage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererControlMessage with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererDescriptor with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererFamily with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererFamily with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererFamily with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererFeature with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererFeature with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererFeature with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererFeatureCapability with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererFeatureCapability with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererFeatureCapability with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererFeatureStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererFeatureStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererFeatureStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererImageCompletionResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererImageCompletionResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererImageCompletionResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererImageLoadToken with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererImageLoadToken with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererImageLoadToken with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererPresentationModel with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererPresentationModel with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererPresentationModel with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererSelection with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererSelection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererSelection with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererTarget with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererTarget with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererTarget with ToJson::{to_json}

///|
#doc(hidden)
pub extend WgpuSurfaceContract with Debug::{to_repr}

///|
#doc(hidden)
pub extend WgpuSurfaceContract with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WgpuSurfaceContract with ToJson::{to_json}

///|
#doc(hidden)
pub extend WgpuSurfaceSourceKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend WgpuSurfaceSourceKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WgpuSurfaceSourceKind with ToJson::{to_json}
