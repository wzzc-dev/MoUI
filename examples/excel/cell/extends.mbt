// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend Cell with Debug::{to_repr}

///|
#doc(hidden)
pub extend Cell with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CellAddress with Debug::{to_repr}

///|
#doc(hidden)
pub extend CellAddress with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CellAlign with Debug::{to_repr}

///|
#doc(hidden)
pub extend CellAlign with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CellFormat with Debug::{to_repr}

///|
#doc(hidden)
pub extend CellFormat with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CellRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend CellRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CellValue with Debug::{to_repr}

///|
#doc(hidden)
pub extend CellValue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NumFormat with Debug::{to_repr}

///|
#doc(hidden)
pub extend NumFormat with Eq::{not_equal, equal}
