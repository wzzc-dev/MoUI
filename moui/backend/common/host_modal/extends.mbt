// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend HostModalInputTransform with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalInputTransform with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalInputTransform with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalSessionState with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalSessionState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalSessionState with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalSurface with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalSurface with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalSurface with ToJson::{to_json}
