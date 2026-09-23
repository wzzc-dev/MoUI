// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AriaNode with Debug::{to_repr}

///|
#doc(hidden)
pub extend AriaNode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AriaNode with ToJson::{to_json}

///|
#doc(hidden)
pub extend AriaSemanticsUpdate with Debug::{to_repr}

///|
#doc(hidden)
pub extend AriaSemanticsUpdate with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AriaSemanticsUpdate with ToJson::{to_json}

///|
#doc(hidden)
pub extend CanvasHostConstraints with Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasHostConstraints with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CanvasHostConstraints with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebApp with @wzzc-dev/window/web.ApplicationHandler::{
  standard_key_binding,
  suspended,
  new_events,
  memory_warning,
  device_event,
  destroy_surfaces,
  can_create_surfaces,
  resumed,
  window_event,
  about_to_wait,
  proxy_wake_up,
}

///|
#doc(hidden)
pub extend WebAsyncHostServiceKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebAsyncHostServiceKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebAsyncHostServiceKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebAsyncHostServiceRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebAsyncHostServiceRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebAsyncHostServiceRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebBackendInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebBackendInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebBackendInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebDocumentMetadata with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebDocumentMetadata with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebDocumentMetadata with ToJson::{to_json}
