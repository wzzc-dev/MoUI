// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend DataGridCell with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridCell with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridCell with ToJson::{to_json}

///|
#doc(hidden)
pub extend DataGridEditCommit with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridEditCommit with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridEditCommit with ToJson::{to_json}

///|
#doc(hidden)
pub extend DataGridEditState with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridEditState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridEditState with ToJson::{to_json}

///|
#doc(hidden)
pub extend DataGridFreezePanes with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridFreezePanes with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridFreezePanes with ToJson::{to_json}

///|
#doc(hidden)
pub extend DataGridSelectionRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridSelectionRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridSelectionRange with ToJson::{to_json}

///|
#doc(hidden)
pub extend DataGridSelectionState with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridSelectionState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridSelectionState with ToJson::{to_json}

///|
#doc(hidden)
pub extend DataGridViewport with Debug::{to_repr}

///|
#doc(hidden)
pub extend DataGridViewport with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DataGridViewport with ToJson::{to_json}
