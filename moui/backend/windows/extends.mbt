// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend WindowsAccessibilityBridgeInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowsAccessibilityBridgeInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowsAccessibilityBridgeInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowsNativeHostBackend with @wzzc-dev/window/windows.ApplicationHandler::{
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
