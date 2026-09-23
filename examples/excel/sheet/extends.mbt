// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend CellChange with Debug::{to_repr}

///|
#doc(hidden)
pub extend CellChange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Clipboard with Debug::{to_repr}

///|
#doc(hidden)
pub extend Clipboard with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend IndexedCell with Debug::{to_repr}

///|
#doc(hidden)
pub extend IndexedCell with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Selection with Debug::{to_repr}

///|
#doc(hidden)
pub extend Selection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Sheet with Debug::{to_repr}

///|
#doc(hidden)
pub extend UndoOp with Debug::{to_repr}

///|
#doc(hidden)
pub extend UndoOp with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Workbook with Debug::{to_repr}
