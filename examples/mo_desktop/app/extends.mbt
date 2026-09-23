// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AppDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AppKind with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend AppKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AppKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend AppLanguage with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppLanguage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AppearanceMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppearanceMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BrowserPage with Debug::{to_repr}

///|
#doc(hidden)
pub extend BrowserPage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopClock with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopClock with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopIconPlacement with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
#doc(hidden)
pub extend DesktopIconPlacement with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopIconPlacement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopIconPlacement with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesktopMenu with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopMenu with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopOverlay with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopOverlay with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopService with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopService with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopSnapshot with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend DesktopSnapshot with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopSnapshot with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesktopSnapshot with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesktopSnapshotV1 with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend DesktopSnapshotV2 with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend DesktopSnapshotV3 with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend DesktopTask with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesktopTask with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FinderLocation with Debug::{to_repr}

///|
#doc(hidden)
pub extend FinderLocation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FinderViewMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend FinderViewMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LauncherTab with Debug::{to_repr}

///|
#doc(hidden)
pub extend LauncherTab with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MenuCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend MenuCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SessionPhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend SessionPhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowBounds with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WindowBounds with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowBounds with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowBounds with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowId with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WindowId with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowId with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowRecord with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WindowRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowState with @moonbitlang/core/json.FromJson::{from_json}

///|
#doc(hidden)
pub extend WindowState with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowState with ToJson::{to_json}
