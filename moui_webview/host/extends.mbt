// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend HostPatchBundle with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostPatchBundle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostPatchReport with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostPatchReport with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWebViewCapabilities with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWebViewCapabilities with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWebViewCapabilities with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostWebViewCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWebViewCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWebViewNativeConfig with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWebViewNativeConfig with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWebViewQueuedCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWebViewQueuedCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewBridgeEnvelope with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewBridgeEnvelope with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewBridgeKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewBridgeKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewBridgeMessage with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewBridgeMessage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewChannelDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewChannelDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewChannelDirection with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebViewChannelPolicy with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewChannelPolicy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewChannelPolicy with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebViewCommandId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#doc(hidden)
pub extend WebViewCommandId with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewCommandId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewCommandId with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend WebViewCommandReceipt with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewCommandReceipt with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewControllerConfig with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewControllerConfig with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebViewError with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewError with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebViewEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewNavigation with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewNavigation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewNavigationId with Compare::{
  op_lt,
  op_le,
  op_ge,
  compare,
  op_gt,
}

///|
#doc(hidden)
pub extend WebViewNavigationId with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewNavigationId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewNavigationId with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend WebViewNoDragRegion with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewNoDragRegion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewNoDragRegion with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebViewOrigin with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#doc(hidden)
pub extend WebViewOrigin with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewOrigin with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewOrigin with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend WebViewPageRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewPageRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewRequestId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#doc(hidden)
pub extend WebViewRequestId with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewRequestId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewRequestId with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend WebViewSecurityPolicy with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewSecurityPolicy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebViewTaskResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebViewTaskResult with Eq::{not_equal, equal}
