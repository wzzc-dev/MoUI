// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend HostChannel with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostChannel with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostFrameScheduler with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostFrameScheduler with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostRequestId with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostRequestId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostRequestId with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostSession with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostSession with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostSessionState with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostSessionState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostSessionState with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostWireEnvelope with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWireEnvelope with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWireEnvelope with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostWireUpdate with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostWireUpdate with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostWireUpdate with ToJson::{to_json}
