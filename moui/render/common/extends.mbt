// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend DrawPlanDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawPlanDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderWorkerDiagnostics with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderWorkerDiagnostics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderWorkerDiagnostics with ToJson::{to_json}

///|
#doc(hidden)
pub extend GpuRenderWorkerFrame with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderWorkerState with Debug::{to_repr}

///|
#doc(hidden)
pub extend GpuRenderWorkerState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GpuRenderWorkerState with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageResourceLifecycle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageResourceLifecycle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathMesh with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathMesh with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathMesh with ToJson::{to_json}

///|
#doc(hidden)
pub extend PathVertex with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathVertex with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathVertex with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlanOp with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlanOp with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlanOp with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlanScopeKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameMailboxDiagnostics with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFrameMailboxDiagnostics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFrameMailboxDiagnostics with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderFramePacket with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderFramePacket with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderFramePacket with ToJson::{to_json}

///|
#doc(hidden)
pub extend ShaderRegistryResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderRegistryResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShaderRegistryResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend ShaderRegistryStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderRegistryStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShaderRegistryStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend SvgImportResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend SvgImportResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SvgImportResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend SvgTextAnchor with Debug::{to_repr}

///|
#doc(hidden)
pub extend SvgTextAnchor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SvgTextRun with Debug::{to_repr}

///|
#doc(hidden)
pub extend SvgTextRunOutline with Debug::{to_repr}
