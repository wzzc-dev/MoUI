///|
pub(all) struct MacosBackendInfo {
  host_info : @host.HostAppInfo
  renderer_available : Bool
  accessibility : MacosAccessibilityBridgeInfo
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MacosAccessibilityBridgeInfo {
  kind : String
  semantics_bridge_available : Bool
  native_accessibility_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct MacosHostAppOptions {
  priv scene_resolver : @runtime.WindowSceneResolver
  priv event_sources : @runtime.HostPlatformEventSources?
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv show_after_first_present : Bool
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
priv struct MacosSurfaceBinding {
  create_renderer : (@window_macos.Window, @core.SurfaceMetrics) -> @render.RendererSession?
  sync_surface : (@window_macos.Window, @core.SurfaceMetrics) -> Unit
}

///|
/// Native host backend: owns the macOS host runtime, native windows, and
/// event-loop integration rather than attaching a runtime to an embedder.
/// Shared lifecycle, frame, image, input, and service state is held through
/// its matching backend/common owner.
struct MacosNativeHostBackend {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  lifecycle : @window_lifecycle.WindowLifecycle
  frames : @window_frame.WindowFrameStates
  images : @window_image.WindowImageTaskStates
  input : @window_input.WindowInputState
  surface_binding : MacosSurfaceBinding
  services : @window_services.WindowServiceState
  accessibility_state : MacosAccessibilityState
  platform_slots : @window_lifecycle.WindowSlotMap[@window_macos.Window, Unit]
  platform_view_plugins : Array[@host.PlatformViewPlugin]
  transparent_titlebar : Bool
  mut show_after_first_present : Bool
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
/// Configure the macOS host. By default the primary window stays hidden until
/// its renderer reports a successful presentation, which prevents an
/// uninitialised native surface from flashing during slow startup. Pass
/// `show_after_first_present=false` only when creation-time visibility is
/// required.
pub fn MacosHostAppOptions::new(
  scene_resolver? : @runtime.WindowSceneResolver = @runtime.WindowSceneResolver::unavailable(),
  event_sources? : @runtime.HostPlatformEventSources? = None,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
  transparent_titlebar? : Bool = false,
  show_after_first_present? : Bool = true,
  platform_attributes? : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
  on_ready? : (() -> Unit)? = None,
  min_window_size? : @dpi.LogicalSize? = None,
) -> MacosHostAppOptions {
  {
    scene_resolver,
    event_sources,
    platform_view_plugins,
    transparent_titlebar,
    show_after_first_present,
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
fn MacosSurfaceBinding::new(
  create_renderer~ : (@window_macos.Window, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface? : (@window_macos.Window, @core.SurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
) -> MacosSurfaceBinding {
  { create_renderer, sync_surface }
}
