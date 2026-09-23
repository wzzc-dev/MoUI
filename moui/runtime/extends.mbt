// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AccessibilityAnnouncement with Debug::{to_repr}

///|
#doc(hidden)
pub extend AccessibilityAnnouncement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AccessibilityAnnouncement with ToJson::{to_json}

///|
#doc(hidden)
pub extend EffectPlanKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend EffectPlanKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EffectPlanKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend EffectPlanSummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend EffectPlanSummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EffectPlanSummary with ToJson::{to_json}

///|
#doc(hidden)
pub extend EffectTaskCancelReason with Debug::{to_repr}

///|
#doc(hidden)
pub extend EffectTaskCancelReason with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EffectTaskCancelReason with ToJson::{to_json}

///|
#doc(hidden)
pub extend EffectTaskLifecycleSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend EffectTaskLifecycleSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EffectTaskLifecycleSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend EffectTaskLifecycleStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend EffectTaskLifecycleStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EffectTaskLifecycleStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend ElementId with Debug::{to_repr}

///|
#doc(hidden)
pub extend ElementId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostPlatformEventPublishResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostPlatformEventPublishResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostPlatformEventPublishResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostWallClock with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWallClock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWallClock with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostWindowEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWindowEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWindowEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend InputDispatchResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend InputDispatchResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend InputDispatchResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend InspectorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend InspectorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend InspectorSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend LayoutBoundsInspectorEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutBoundsInspectorEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayoutBoundsInspectorEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend LayoutInspectorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutInspectorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayoutInspectorSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend PerformSemanticsActionRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend PerformSemanticsActionRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PerformSemanticsActionRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend ProgramRuntimeSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend ProgramRuntimeSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ProgramRuntimeSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend RedrawSchedulerState with Debug::{to_repr}

///|
#doc(hidden)
pub extend RedrawSchedulerState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RedrawSchedulerState with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderInspectorEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderInspectorEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderInspectorEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend RenderInspectorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderInspectorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RenderInspectorSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererRecoveryBudget with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererRecoveryBudget with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererRecoveryBudget with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererRecoverySnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererRecoverySnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererRecoverySnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend RendererRecoveryState with Debug::{to_repr}

///|
#doc(hidden)
pub extend RendererRecoveryState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RendererRecoveryState with ToJson::{to_json}

///|
#doc(hidden)
pub extend RuntimeDirtyStateSummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend RuntimeDirtyStateSummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RuntimeDirtyStateSummary with ToJson::{to_json}

///|
#doc(hidden)
pub extend RuntimeFrameTiming with Debug::{to_repr}

///|
#doc(hidden)
pub extend RuntimeFrameTiming with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RuntimeFrameTiming with ToJson::{to_json}

///|
#doc(hidden)
pub extend RuntimeInspectorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend RuntimeInspectorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RuntimeInspectorSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsActionDispatchError with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsActionDispatchError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsActionDispatchError with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsActionReceipt with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsActionReceipt with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsActionReceipt with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsDelta with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsDelta with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsGenerationPrecondition with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsGenerationPrecondition with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsGenerationPrecondition with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsInspectorEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsInspectorEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsInspectorEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsInspectorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsInspectorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsInspectorSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsIssue with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsIssue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsIssue with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsRead with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsRead with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsReadError with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsReadError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsReadError with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionCancelReason with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionCancelReason with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionCancelReason with ToJson::{to_json}

///|
#doc(hidden)
pub extend SubscriptionKindCount with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionKindCount with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionKindCount with ToJson::{to_json}

///|
#doc(hidden)
pub extend SubscriptionLifecycleSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionLifecycleSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionLifecycleSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend SubscriptionLifecycleStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionLifecycleStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionLifecycleStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend SubscriptionPlanKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionPlanKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionPlanKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend SubscriptionPlanSummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionPlanSummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionPlanSummary with ToJson::{to_json}

///|
#doc(hidden)
pub extend ViewInspectorSummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewInspectorSummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewInspectorSummary with ToJson::{to_json}

///|
#doc(hidden)
pub extend ViewTreeInspectorSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewTreeInspectorSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewTreeInspectorSnapshot with ToJson::{to_json}
