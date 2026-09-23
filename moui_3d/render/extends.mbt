// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend ThreeDFrame with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRenderItem with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRenderPacket with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRenderResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRenderResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDRenderResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDRendererBackend with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRendererBackend with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDRendererBackend with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDRendererDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRendererDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDRendererDescriptor with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDRendererStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDRendererStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDRendererStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDResourceChange with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDResourceChange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDResourceChange with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDResourceDiff with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDResourceKey with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDResourceKey with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDResourceKey with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDResourceKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDResourceKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDResourceKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThreeDViewportSize with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThreeDViewportSize with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThreeDViewportSize with ToJson::{to_json}
