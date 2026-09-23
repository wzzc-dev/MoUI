// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend NativeGpuPlatform with Debug::{to_repr}

///|
#doc(hidden)
pub extend NativeGpuPlatform with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NativeGpuPlatform with NativePlatformSurface::{
  gpu_promoted,
  platform_label,
  surface_route,
}

///|
#doc(hidden)
pub extend NativeGpuPlatform with ToJson::{to_json}

///|
#doc(hidden)
pub extend NativeRendererMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend NativeRendererMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NativeRendererMode with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaEmojiFontFallbackDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaEmojiFontFallbackDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaEmojiFontFallbackDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaFontResolution with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaFontResolution with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaFontResolution with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaPixelFrame with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaPixelFrame with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaPresentKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaPresentKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaPresentKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaRendererError with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaRendererError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaRendererError with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaSurfaceRoute with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaSurfaceRoute with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaSurfaceRoute with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaTextSelectionGeometryDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaTextSelectionGeometryDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaTextSelectionGeometryDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaTextVisualOrderDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaTextVisualOrderDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaTextVisualOrderDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend SkiaUnsupportedCommandDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend SkiaUnsupportedCommandDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SkiaUnsupportedCommandDiagnostic with ToJson::{to_json}
