///|
pub(all) struct MacosBackendInfo {
  host_info : @host.HostAppInfo
  renderer_available : Bool
  accessibility : MacosAccessibilityBridgeInfo
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MacosAccessibilityBridgeInfo {
  kind : @host.NativeAccessibilityBridgeKind
  semantics_bridge_available : Bool
  native_platform_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct MacosHostAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv event_sources : @host.HostPlatformEventSources?
  priv web_view_commands : @host.HostWebViewCommandQueue?
  priv web_view_events : @host.HostWebViewEventSource?
}

///|
pub struct MacosHostSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
  priv native_ime_runtime_smoke : Bool
}

///|
pub struct MacosRendererProvider {
  priv create_renderer : (@window_macos.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_surface : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @host.HostAsyncImageLoader?
}

///|
struct MacosApp {
  title : String
  runtime : @runtime.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  renderer_provider : MacosRendererProvider
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @host.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : MacosWindowPlatformSlots
  image_repaint_tracker : @host.HostImageResourceRepaintTracker
  event_sources : @host.HostPlatformEventSources?
  web_view_commands : @host.HostWebViewCommandQueue?
  web_view_events : @host.HostWebViewEventSource?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
  native_ime_runtime_smoke : Bool
  mut native_ime_runtime_smoke_done : Bool
  mut native_ime_runtime_smoke_phase : Int
  mut native_ime_runtime_smoke_wait_redraws : Int
  mut native_ime_runtime_smoke_before_commit_text : String
}

///|
priv struct MacosWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_macos.Window
  renderer : @host.HostWindowRenderer
}

///|
priv struct MacosWindowPlatformSlots {
  mut slots : Array[MacosWindowPlatformSlot]
}

///|
pub fn MacosHostAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  event_sources? : @host.HostPlatformEventSources? = None,
  web_view_commands? : @host.HostWebViewCommandQueue? = None,
  web_view_events? : @host.HostWebViewEventSource? = None,
) -> MacosHostAppOptions {
  { scene_resolver, event_sources, web_view_commands, web_view_events }
}

///|
pub fn MacosHostSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
  native_ime_runtime_smoke? : Bool = false,
) -> MacosHostSmokeOptions {
  { first_frame_smoke_auto_exit, native_ime_runtime_smoke }
}

///|
pub fn MacosRendererProvider::new(
  create_renderer~ : (@window_macos.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_surface? : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> MacosRendererProvider {
  { create_renderer, sync_surface, image_loader }
}
