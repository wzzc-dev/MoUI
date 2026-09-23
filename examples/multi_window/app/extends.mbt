// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend Scene with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowId with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowId with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowOpenRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowOpenRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowOpenRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowScene with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowScene with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowScene with ToJson::{to_json}
