// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend PresentationAnchor with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationAnchor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentationHostPolicy with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationHostPolicy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentationKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentationModality with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationModality with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentationPlacement with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationPlacement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentationPlacementCandidate with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationPlacementCandidate with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PresentationTransition with Debug::{to_repr}

///|
#doc(hidden)
pub extend PresentationTransition with Eq::{not_equal, equal}
