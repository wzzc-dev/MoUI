// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend EmbeddedHostResponse with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedHostResponse with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedHostResponse with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedHostResponseEnvelope with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedHostResponseEnvelope with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedHostResponseEnvelope with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedHostUpdate with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedHostUpdate with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedHostUpdate with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedHostUpdateEnvelope with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedHostUpdateEnvelope with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedHostUpdateEnvelope with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedImeRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedImeRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedImeRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedPlatformViewSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedPlatformViewSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedPlatformViewSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedSemanticsNode with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedSemanticsNode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedSemanticsNode with ToJson::{to_json}

///|
#doc(hidden)
pub extend EmbeddedSemanticsUpdate with Debug::{to_repr}

///|
#doc(hidden)
pub extend EmbeddedSemanticsUpdate with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EmbeddedSemanticsUpdate with ToJson::{to_json}
