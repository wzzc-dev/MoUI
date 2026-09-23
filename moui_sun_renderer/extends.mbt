// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend SunCachedLayerAdmissionDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunCachedLayerAdmissionDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunCachedLayerAdmissionDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunCachedLayerDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunCachedLayerDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunCachedLayerDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunEmojiFontFallbackDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunEmojiFontFallbackDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunEmojiFontFallbackDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunPixelFrame with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunRendererError with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunRendererError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunRendererError with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunTextMaturityDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunTextMaturityDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunTextMaturityDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunTextSelectionGeometryDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunTextSelectionGeometryDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunTextSelectionGeometryDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunTextVisualOrderDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunTextVisualOrderDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunTextVisualOrderDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SunUnsupportedCommandDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SunUnsupportedCommandDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SunUnsupportedCommandDiagnostic with ToJson::{to_json}
