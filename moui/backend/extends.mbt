// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend Event with Debug::{to_repr}

///|
#doc(hidden)
pub extend Event with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Event with ToJson::{to_json}

///|
#doc(hidden)
pub extend EventResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend EventResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EventResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostAppInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostAppInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostAppInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostApplicationMenu with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostApplicationMenu with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostApplicationMenu with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostApplicationMenuItem with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostApplicationMenuItem with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostApplicationMenuItem with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostApplicationMenuPlacement with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostApplicationMenuPlacement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostApplicationMenuPlacement with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostBackendKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostBackendKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostBackendKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostBinaryFileDiagnostic with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostBinaryFileDiagnostic with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostBinaryFileDiagnostic with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostBinaryFileRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostBinaryFileRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostBinaryFileRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostCapabilitySummary with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostCapabilitySummary with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostCapabilitySummary with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostClipboardRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostClipboardRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostClipboardRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostCompletedServiceResponse with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostCompletedServiceResponse with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostCompletedServiceResponse with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostCoordinatePolicy with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostCoordinatePolicy with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostCoordinatePolicy with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostCoordinateSpace with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostCoordinateSpace with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostCoordinateSpace with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostDirectoryEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostDirectoryEntry with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostDirectoryEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostFileDialogKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostFileDialogKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostFileDialogKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostFileDialogOptions with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostFileDialogOptions with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostFileDialogOptions with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostFocusEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostFocusEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostFocusEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostInputCapabilities with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostInputCapabilities with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostInputCapabilities with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostInputContract with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostInputContract with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostInputContract with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalCapabilities with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalCapabilities with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalCapabilities with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalModality with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalModality with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalModality with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostModalResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostModalResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostModalResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostPendingServiceRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostPendingServiceRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostPendingServiceRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostScrollDelta with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostScrollDelta with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostScrollDelta with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostScrollEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostScrollEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostScrollEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostScrollPhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostScrollPhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostScrollPhase with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostServiceCapabilities with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostServiceCapabilities with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostServiceCapabilities with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostServiceKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostServiceKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostServiceKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostServiceRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostServiceRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostServiceRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostServiceRequestId with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostServiceRequestId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostServiceRequestId with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostServiceResponse with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostServiceResponse with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostServiceResponse with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostSettingsRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostSettingsRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostSettingsRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend HostTextFileRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend HostTextFileRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend HostTextFileRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlatformChannelRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlatformChannelRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlatformChannelRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlatformChannelResponse with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlatformChannelResponse with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlatformChannelResponse with ToJson::{to_json}

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
pub extend WindowLifecyclePhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowLifecyclePhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowLifecyclePhase with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowOpenRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowOpenRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowOpenRequest with ToJson::{to_json}

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
pub extend WindowRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowRequestCompletion with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowRequestCompletion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowRequestCompletion with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowRequestResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowRequestResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowRequestResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend WindowScene with Debug::{to_repr}

///|
#doc(hidden)
pub extend WindowScene with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend WindowScene with ToJson::{to_json}
