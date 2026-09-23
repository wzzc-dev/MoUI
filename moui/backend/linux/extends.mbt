// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend LinuxATSPIBindingDiagnostics with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinuxATSPIBindingDiagnostics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinuxATSPIBindingDiagnostics with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinuxAccessibilityBridgeInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinuxAccessibilityBridgeInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinuxAccessibilityBridgeInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinuxBackendCapabilities with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinuxBackendCapabilities with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinuxBackendCapabilities with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinuxBackendInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinuxBackendInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinuxBackendInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinuxBackendReadiness with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinuxBackendReadiness with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinuxBackendReadiness with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinuxClientDecorationState with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinuxClientDecorationState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinuxClientDecorationState with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinuxNativeHostBackend with @wzzc-dev/window/linux.ApplicationHandler::{
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
