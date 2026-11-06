///|
#derive(Eq, Debug, ToJson)
pub(all) struct LinuxBackendInfo {
  host_info : @host.HostAppInfo
  window_backend_available : Bool
  renderer_available : Bool
  capabilities : LinuxBackendCapabilities
  accessibility : LinuxAccessibilityBridgeInfo
  services : @host.HostServiceCapabilities
  readiness : LinuxBackendReadiness
  description : String
}

///|
pub extend LinuxBackendInfo with Debug::{to_repr}

///|
pub extend LinuxBackendInfo with Eq::{not_equal, equal}

///|
pub extend LinuxBackendInfo with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct LinuxBackendCapabilities {
  window : Bool
  renderer : Bool
  titlebar : Bool
  pointer : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  drag_drop : Bool
  accessibility : Bool
  scale_factor : Bool
}

///|
pub extend LinuxBackendCapabilities with Debug::{to_repr}

///|
pub extend LinuxBackendCapabilities with Eq::{not_equal, equal}

///|
pub extend LinuxBackendCapabilities with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct LinuxBackendReadiness {
  ready : Bool
  blocked_by : Array[String]
  next_steps : Array[String]
}

///|
pub extend LinuxBackendReadiness with Debug::{to_repr}

///|
pub extend LinuxBackendReadiness with Eq::{not_equal, equal}

///|
pub extend LinuxBackendReadiness with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct LinuxAccessibilityBridgeInfo {
  kind : String
  semantics_bridge_available : Bool
  native_accessibility_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
}

///|
pub extend LinuxAccessibilityBridgeInfo with Debug::{to_repr}

///|
pub extend LinuxAccessibilityBridgeInfo with Eq::{not_equal, equal}

///|
pub extend LinuxAccessibilityBridgeInfo with ToJson::{to_json}

///|
pub struct LinuxHostAppOptions {
  priv scene_resolver : @window_lifecycle.WindowSceneResolver
  priv event_sources : @apphost.HostPlatformEventSources?
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv platform_attributes : @window_core.PlatformWindowAttributes
}

///|
pub struct LinuxHostSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
/// The Linux surface binding is the shared desktop binding specialized to
/// the Linux window type; see `@window_host.DesktopSurfaceBinding`.
type LinuxSurfaceBinding = @window_host.DesktopSurfaceBinding[
  @window_linux.Window,
]

///|
#derive(Eq, Debug, ToJson)
pub(all) struct LinuxClientDecorationState {
  active : Bool
  titlebar_height : Double
}

///|
pub extend LinuxClientDecorationState with Debug::{to_repr}

///|
pub extend LinuxClientDecorationState with Eq::{not_equal, equal}

///|
pub extend LinuxClientDecorationState with ToJson::{to_json}

///|
/// Native host backend: owns the Linux host runtime, native windows, and
/// event-loop integration rather than attaching a runtime to an embedder.
/// Shared lifecycle, frame, image, input, and service state is held through
/// its matching backend/common owner.
struct LinuxNativeHostBackend {
  core : @window_host.DesktopNativeHostBackendCore[
    @window_linux.Window,
    LinuxClientDecorationState,
  ]
  atspi_state : LinuxAtspiHostState
  transparent_titlebar : Bool
  platform_attributes : @window_core.PlatformWindowAttributes
}

///|
pub extend LinuxNativeHostBackend with @wzzc-dev/window/linux.ApplicationHandler::{
  standard_key_binding,
  suspended,
  new_events,
  memory_warning,
  device_event,
  destroy_surfaces,
  can_create_surfaces,
  resumed,
  window_event,
  about_to_wait,
  proxy_wake_up,
}

///|
pub fn LinuxHostAppOptions::new(
  scene_resolver~ : @window_lifecycle.WindowSceneResolver = @window_lifecycle.WindowSceneResolver::unavailable(),
  event_sources~ : @apphost.HostPlatformEventSources? = None,
  platform_view_plugins~ : Array[@host.PlatformViewPlugin] = [],
  transparent_titlebar~ : Bool = false,
  platform_attributes~ : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
) -> LinuxHostAppOptions {
  {
    scene_resolver,
    event_sources,
    platform_view_plugins,
    transparent_titlebar,
    platform_attributes,
  }
}

///|
pub fn LinuxHostSmokeOptions::new(
  first_frame_smoke_auto_exit~ : Bool = false,
) -> LinuxHostSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
pub fn LinuxClientDecorationState::new(
  active~ : Bool,
  titlebar_height~ : Double = linux_client_titlebar_height,
) -> LinuxClientDecorationState {
  { active, titlebar_height: if active { titlebar_height } else { 0.0 }, }
}

///|
let linux_client_titlebar_height : Double = 32.0
