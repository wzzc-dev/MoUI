// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AgentAccessibilityAnnouncement with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentAccessibilityAnnouncement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentAccessibilityAnnouncement with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentActionError with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentActionError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentActionError with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentActionReceipt with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentActionReceipt with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentActionReceipt with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentActionRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentActionRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentActionRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentDiagnosticsError with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentDiagnosticsError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentDiagnosticsError with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentGenerationPrecondition with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentGenerationPrecondition with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentGenerationPrecondition with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentReadError with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentReadError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentReadError with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentSemanticsDelta with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSemanticsDelta with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSemanticsDelta with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentSemanticsIssue with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSemanticsIssue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSemanticsIssue with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentSemanticsRead with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSemanticsRead with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSemanticsRead with ToJson::{to_json}

///|
#doc(hidden)
pub extend AgentSemanticsSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend AgentSemanticsSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AgentSemanticsSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend DiagnosticsDispatchResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend DiagnosticsDispatchResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DiagnosticsDispatchResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend PaintSummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend PaintSummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PaintSummary with ToJson::{to_json}

///|
#doc(hidden)
pub extend RuntimeAgentHost with AgentDiagnosticsHost::{
  dispatch_event,
  runtime_state,
  dispatch_command,
  paint_summary,
}

///|
#doc(hidden)
pub extend RuntimeAgentHost with AgentHost::{read_semantics, perform_action}

///|
#doc(hidden)
pub extend RuntimeStateSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend RuntimeStateSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RuntimeStateSnapshot with ToJson::{to_json}
