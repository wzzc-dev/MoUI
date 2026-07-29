///|
pub(all) struct MacosBackendInfo {
  host_info : @host.HostAppInfo
  renderer_available : Bool
  accessibility : MacosAccessibilityBridgeInfo
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MacosAccessibilityBridgeInfo {
  kind : @runtime.NativeAccessibilityBridgeKind
  semantics_bridge_available : Bool
  native_platform_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct MacosHostAppOptions {
  priv scene_resolver : @runtime.HostWindowSceneResolver
  priv event_sources : @runtime.HostPlatformEventSources?
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv platform_attributes : @window_core.PlatformWindowAttributes
  /// Optional callback invoked once after the primary window is created and
  /// the app has finished launching. This runs after the default macOS menu
  /// bar is installed, so it is the correct place to install a custom system
  /// menu via `@window_macos.set_system_menus` (installing earlier gets
  /// overwritten by the default menu during `did_finish_launching`).
  priv on_ready : (() -> Unit)?
  priv min_window_size : @dpi.LogicalSize?
}

///|
pub struct MacosHostSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
  priv native_ime_runtime_smoke : Bool
  /// When > 0, keep presenting for this many milliseconds after warm-up and
  /// emit a performance summary line. Mutually exclusive with first-frame
  /// auto-exit in normal use; first-frame takes precedence if both are set.
  priv performance_smoke_duration_ms : Int
  priv performance_smoke_warm_up_presents : Int
  priv performance_smoke_refresh_hz : Int
  /// When true, after the performance measure window also runs resize/fg-bg
  /// cycles and injects context-loss controls for remaining ADR 0006 gates.
  priv promotion_lifecycle_enabled : Bool
  priv promotion_surface_cycles : Int
  priv promotion_fg_bg_cycles : Int
  priv promotion_context_loss_count : Int
}

///|
pub struct MacosRendererProvider {
  priv create_renderer : (@window_macos.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|
/// Native host backend: owns the macOS host runtime, native windows, and
/// event-loop integration rather than attaching a runtime to an embedder.
struct MacosNativeHostBackend {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  renderer_provider : MacosRendererProvider
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @runtime.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @runtime.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : MacosWindowPlatformSlots
  image_repaint_tracker : @render.HostImageResourceRepaintTracker
  event_sources : @runtime.HostPlatformEventSources?
  platform_view_plugins : Array[@host.PlatformViewPlugin]
  transparent_titlebar : Bool
  platform_attributes : @window_core.PlatformWindowAttributes
  on_ready : (() -> Unit)?
  min_window_size : @dpi.LogicalSize?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
  native_ime_runtime_smoke : Bool
  mut native_ime_runtime_smoke_done : Bool
  mut native_ime_runtime_smoke_phase : Int
  mut native_ime_runtime_smoke_wait_redraws : Int
  mut native_ime_runtime_smoke_before_commit_text : String
  performance_smoke_duration_ms : Int
  performance_smoke_warm_up_presents : Int
  performance_smoke_refresh_hz : Int
  mut performance_smoke_active : Bool
  mut performance_smoke_presented : Int
  mut performance_smoke_started_ms : Double
  mut performance_smoke_measure_started_ms : Double
  mut performance_smoke_last_present_ms : Double
  mut performance_smoke_last_checkpoint_ms : Double
  performance_smoke_intervals_ms : Array[Double]
  promotion_lifecycle_enabled : Bool
  promotion_surface_cycles_target : Int
  promotion_fg_bg_cycles_target : Int
  promotion_context_loss_target : Int
  mut promotion_phase : Int
  mut promotion_surface_cycles_done : Int
  mut promotion_fg_bg_cycles_done : Int
  mut promotion_context_loss_done : Int
  mut promotion_context_loss_injected : Int
  mut promotion_wait_presents : Int
  mut promotion_mailbox_ok : Bool
  mut promotion_readback_eliminated : Bool
  mut promotion_runtime_preserved : Bool
  mut promotion_automatic_fallback : Bool
  mut promotion_recovered_within_vsyncs : Int
  mut promotion_recovery_count_before : Int
  mut promotion_fallback_count : Int
}

///|
priv struct MacosWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_macos.Window
  renderer : @render.HostWindowRenderer
  mut frame_pending : Bool
}

///|
priv struct MacosWindowPlatformSlots {
  mut slots : Array[MacosWindowPlatformSlot]
}

///|
pub fn MacosHostAppOptions::new(
  scene_resolver? : @runtime.HostWindowSceneResolver = @runtime.HostWindowSceneResolver::unavailable(),
  event_sources? : @runtime.HostPlatformEventSources? = None,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
  transparent_titlebar? : Bool = false,
  platform_attributes? : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
  on_ready? : (() -> Unit)? = None,
  min_window_size? : @dpi.LogicalSize? = None,
) -> MacosHostAppOptions {
  {
    scene_resolver,
    event_sources,
    platform_view_plugins,
    transparent_titlebar,
    platform_attributes,
    on_ready,
    min_window_size,
  }
}

///|
pub fn MacosHostAppOptions::platform_view_plugins(
  self : MacosHostAppOptions,
) -> Array[@host.PlatformViewPlugin] {
  self.platform_view_plugins
}

///|
pub fn MacosHostSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
  native_ime_runtime_smoke? : Bool = false,
  performance_smoke_duration_ms? : Int = 0,
  performance_smoke_warm_up_presents? : Int = 30,
  performance_smoke_refresh_hz? : Int = 60,
  promotion_lifecycle_enabled? : Bool = false,
  promotion_surface_cycles? : Int = 100,
  promotion_fg_bg_cycles? : Int = 100,
  promotion_context_loss_count? : Int = 1,
) -> MacosHostSmokeOptions {
  {
    first_frame_smoke_auto_exit,
    native_ime_runtime_smoke,
    performance_smoke_duration_ms,
    performance_smoke_warm_up_presents,
    performance_smoke_refresh_hz,
    promotion_lifecycle_enabled,
    promotion_surface_cycles,
    promotion_fg_bg_cycles,
    promotion_context_loss_count,
  }
}

///|
pub fn MacosHostSmokeOptions::performance_enabled(
  self : MacosHostSmokeOptions,
) -> Bool {
  self.performance_smoke_duration_ms > 0
}

///|

///|
/// Platform utility: get the native content view handle from a macOS window.
/// Used by platform-view plugins' sync/dispose callbacks to pass the window
/// pointer to the platform-agnostic plugin.
pub fn macos_native_view_handle(window : @window_macos.Window) -> UInt64? {
  Some(window.content_view_handle()) catch {
    _ => None
  }
}

///|
pub fn MacosRendererProvider::new(
  create_renderer~ : (@window_macos.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync_surface? : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> MacosRendererProvider {
  { create_renderer, sync_surface, image_loader }
}
