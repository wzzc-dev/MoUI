///|
pub(all) struct LinuxBackendInfo {
  host_info : @host.HostAppInfo
  window_backend_available : Bool
  renderer_available : Bool
  capabilities : LinuxBackendCapabilities
  accessibility : LinuxAccessibilityBridgeInfo
  services : @host.HostServiceCapabilities
  readiness : LinuxBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub extend LinuxBackendInfo with Debug::{to_repr}

///|
pub extend LinuxBackendInfo with Eq::{not_equal, equal}

///|
pub extend LinuxBackendInfo with ToJson::{to_json}

///|
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
} derive(Eq, Debug, ToJson)

///|
pub extend LinuxBackendCapabilities with Debug::{to_repr}

///|
pub extend LinuxBackendCapabilities with Eq::{not_equal, equal}

///|
pub extend LinuxBackendCapabilities with ToJson::{to_json}

///|
pub(all) struct LinuxBackendReadiness {
  ready : Bool
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub extend LinuxBackendReadiness with Debug::{to_repr}

///|
pub extend LinuxBackendReadiness with Eq::{not_equal, equal}

///|
pub extend LinuxBackendReadiness with ToJson::{to_json}

///|
pub(all) struct LinuxAccessibilityBridgeInfo {
  kind : String
  semantics_bridge_available : Bool
  native_accessibility_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub extend LinuxAccessibilityBridgeInfo with Debug::{to_repr}

///|
pub extend LinuxAccessibilityBridgeInfo with Eq::{not_equal, equal}

///|
pub extend LinuxAccessibilityBridgeInfo with ToJson::{to_json}

///|
pub struct LinuxHostAppOptions {
  priv scene_resolver : @window_lifecycle.WindowSceneResolver
  priv event_sources : @runtime.HostPlatformEventSources?
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv platform_attributes : @window_core.PlatformWindowAttributes
}

///|
pub struct LinuxHostSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
priv struct LinuxSurfaceBinding {
  create_renderer : (@window_linux.Window, @core.SurfaceMetrics) -> @render.RendererSession?
  sync_surface : (@window_linux.Window, @core.SurfaceMetrics) -> Unit
}

///|
pub(all) struct LinuxClientDecorationState {
  active : Bool
  titlebar_height : Double
} derive(Eq, Debug, ToJson)

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
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  lifecycle : @window_lifecycle.WindowLifecycle
  frames : @window_frame.WindowFrameStates
  images : @window_image.WindowImageTaskStates
  input : @window_input.WindowInputState
  surface_binding : LinuxSurfaceBinding
  services : @window_services.WindowServiceState
  atspi_state : LinuxAtspiHostState
  platform_slots : @window_lifecycle.WindowSlotMap[
    @window_linux.Window,
    LinuxClientDecorationState,
  ]
  platform_view_plugins : Array[@host.PlatformViewPlugin]
  transparent_titlebar : Bool
  platform_attributes : @window_core.PlatformWindowAttributes
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
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
  scene_resolver? : @window_lifecycle.WindowSceneResolver = @window_lifecycle.WindowSceneResolver::unavailable(),
  event_sources? : @runtime.HostPlatformEventSources? = None,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
  transparent_titlebar? : Bool = false,
  platform_attributes? : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
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
  first_frame_smoke_auto_exit? : Bool = false,
) -> LinuxHostSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
fn LinuxSurfaceBinding::new(
  create_renderer~ : (@window_linux.Window, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface? : (@window_linux.Window, @core.SurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
) -> LinuxSurfaceBinding {
  { create_renderer, sync_surface, }
}

///|
pub fn LinuxClientDecorationState::new(
  active~ : Bool,
  titlebar_height? : Double = linux_client_titlebar_height,
) -> LinuxClientDecorationState {
  { active, titlebar_height: if active { titlebar_height } else { 0.0 }, }
}

///|
let linux_client_titlebar_height : Double = 32.0
