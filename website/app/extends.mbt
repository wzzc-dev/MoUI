// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend WebsiteDocEntry with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WebsiteDocEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebsiteDocEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebsiteDocEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebsiteDocGroup with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WebsiteDocGroup with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebsiteDocGroup with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebsiteDocGroup with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebsiteDocsCatalog with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WebsiteDocsCatalog with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebsiteDocsCatalog with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebsiteDocsCatalog with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebsitePage with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebsitePage with Eq::{not_equal, equal}
