// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend AppLifecycleEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppLifecycleEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AppLifecycleEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend ApplicationMenuPlacement with Debug::{to_repr}

///|
#doc(hidden)
pub extend ApplicationMenuPlacement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ClipboardImage with Debug::{to_repr}

///|
#doc(hidden)
pub extend ClipboardImage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DirectoryEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend DirectoryEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DirectoryEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend FileAssociation with Debug::{to_repr}

///|
#doc(hidden)
pub extend FileAssociation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FileAssociation with ToJson::{to_json}

///|
#doc(hidden)
pub extend NotificationRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend NotificationRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend NotificationRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend PermissionKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend PermissionKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PermissionKind with Hash::{hash, hash_combine}

///|
#doc(hidden)
pub extend PermissionKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend PermissionStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend PermissionStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PermissionStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend PrintRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend PrintRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PrintRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend ProtocolRegistration with Debug::{to_repr}

///|
#doc(hidden)
pub extend ProtocolRegistration with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ProtocolRegistration with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteLocation with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteLocation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteLocation with ToJson::{to_json}

///|
#doc(hidden)
pub extend RouteQueryParam with Debug::{to_repr}

///|
#doc(hidden)
pub extend RouteQueryParam with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RouteQueryParam with ToJson::{to_json}

///|
#doc(hidden)
pub extend ServiceError with Debug::{to_repr}

///|
#doc(hidden)
pub extend ServiceError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ServiceError with ToJson::{to_json}

///|
#doc(hidden)
pub extend ServiceTaskResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend ServiceTaskResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShareRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShareRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShareRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend TrayItem with Debug::{to_repr}

///|
#doc(hidden)
pub extend TrayItem with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TrayItem with ToJson::{to_json}
