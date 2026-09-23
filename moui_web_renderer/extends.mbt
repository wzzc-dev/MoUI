// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend WebGpuHostAdapterInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebGpuHostAdapterInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebGpuHostAdapterInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebGpuHostCall with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebGpuHostCall with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebGpuHostCall with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebGpuHostCapabilities with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebGpuHostCapabilities with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebGpuHostCapabilities with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebGpuHostError with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebGpuHostError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebGpuHostError with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebGpuHostImportInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebGpuHostImportInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebGpuHostImportInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend WebGpuHostSurface with Debug::{to_repr}

///|
#doc(hidden)
pub extend WebGpuHostSurface with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WebGpuHostSurface with ToJson::{to_json}
