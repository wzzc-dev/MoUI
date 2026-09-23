// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend RouteDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteDescriptor with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteHistoryEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteHistoryEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteHistoryEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteHistoryState with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteHistoryState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteHistoryState with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteLocation with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteLocation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteLocation with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteParam with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteParam with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteParam with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteQueryParam with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteQueryParam with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteQueryParam with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouterSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouterSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouterSnapshot with ToJson::{to_json}
