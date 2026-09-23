// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend EmbeddedHostLifecyclePhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedHostLifecyclePhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedHostSurface with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedHostSurface with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedWindowHostAction with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedWindowHostAction with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlatformWindowBinding with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlatformWindowBinding with Eq::{not_equal, equal}
