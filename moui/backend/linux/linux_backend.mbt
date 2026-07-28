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
pub(all) struct LinuxBackendReadiness {
  ready : Bool
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinuxAccessibilityBridgeInfo {
  kind : @runtime.NativeAccessibilityBridgeKind
  semantics_bridge_available : Bool
  native_platform_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct LinuxHostAppOptions {
  priv scene_resolver : @runtime.HostWindowSceneResolver
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
pub struct LinuxRendererProvider {
  priv create_renderer : (@window_linux.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface : (@window_linux.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|
pub(all) struct LinuxClientDecorationState {
  active : Bool
  titlebar_height : Double
} derive(Eq, Debug, ToJson)

///|
struct LinuxApp {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  renderer_provider : LinuxRendererProvider
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @runtime.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @runtime.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : LinuxWindowPlatformSlots
  image_repaint_tracker : @render.HostImageResourceRepaintTracker
  event_sources : @runtime.HostPlatformEventSources?
  platform_view_plugins : Array[@host.PlatformViewPlugin]
  transparent_titlebar : Bool
  platform_attributes : @window_core.PlatformWindowAttributes
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
}

///|
priv struct LinuxWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_linux.Window
  renderer : @render.HostWindowRenderer
  mut decorations : LinuxClientDecorationState
  mut frame_pending : Bool
}

///|
priv struct LinuxWindowPlatformSlots {
  mut slots : Array[LinuxWindowPlatformSlot]
}

///|
pub fn LinuxHostAppOptions::new(
  scene_resolver? : @runtime.HostWindowSceneResolver = @runtime.HostWindowSceneResolver::unavailable(),
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
pub fn LinuxRendererProvider::new(
  create_renderer~ : (@window_linux.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync_surface? : (@window_linux.Window, @host.HostSurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> LinuxRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn LinuxRendererProvider::schedule_image_resource_loads(
  self : LinuxRendererProvider,
  window_id : @host.HostWindowId,
  renderer : @render.HostWindowRenderer,
  completion_source : @render.HostImageResourceCompletionSource,
) -> @render.HostAsyncImageLoadScheduleResult? {
  match self.image_loader {
    Some(loader) =>
      Some(
        loader.schedule_loading_resources(
          window_id, renderer, completion_source,
        ),
      )
    None => None
  }
}

///|
fn LinuxRendererProvider::cancel_image_resource_loads(
  self : LinuxRendererProvider,
  window_id : @host.HostWindowId,
) -> Int {
  match self.image_loader {
    Some(loader) => loader.cancel_window(window_id)
    None => 0
  }
}

///|
pub fn LinuxClientDecorationState::new(
  active~ : Bool,
  titlebar_height? : Double = linux_client_titlebar_height,
) -> LinuxClientDecorationState {
  { active, titlebar_height: if active { titlebar_height } else { 0.0 } }
}

///|
let linux_client_titlebar_height : Double = 32.0
