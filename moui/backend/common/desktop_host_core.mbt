///|
/// Shared host-surface binding for the desktop native backends. The macOS,
/// Linux, and Windows bindings are structurally identical; the platforms
/// differ only in their window type (`@window_macos.Window`,
/// `@window_linux.Window`, `@win.Window`), which is the `W` parameter.
pub(all) struct DesktopSurfaceBinding[W] {
  create_renderer : (W, @core.SurfaceMetrics) -> @render.RendererSession?
  sync_surface : (W, @core.SurfaceMetrics) -> Unit
}

///|
pub fn[W] DesktopSurfaceBinding::new(
  create_renderer~ : (W, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface~ : (W, @core.SurfaceMetrics) -> Unit = (_window, _metrics) => (),
) -> DesktopSurfaceBinding[W] {
  { create_renderer, sync_surface, }
}

///|
/// Parameterized desktop host-backend core: the struct fields and the
/// construction sequence shared verbatim by the macOS, Linux, and Windows
/// native host backends. Platform-private state (macOS drag region / dock
/// icon / smoke harnesses, Linux decorations / atspi state, Windows
/// frame-present hook) stays on the platform struct; `W` is the platform
/// window type and `Extra` the per-platform `WindowSlotMap` payload.
pub(all) struct DesktopNativeHostBackendCore[W, Extra] {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  lifecycle : @window_lifecycle.WindowLifecycle
  frames : @window_frame.WindowFrameStates
  images : @window_image.WindowImageTaskStates
  input : @window_input.WindowInputState
  surface_binding : DesktopSurfaceBinding[W]
  services : @window_services.WindowServiceState
  platform_slots : @window_lifecycle.WindowSlotMap[W, Extra]
  platform_view_plugins : Array[@backend_host.PlatformViewPlugin]
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
}

///|
/// Build the shared core exactly as each platform's `create_*_app` did
/// before the convergence: same field order, same sub-owner constructors.
pub fn[W, Extra] DesktopNativeHostBackendCore::new(
  title~ : String,
  runtime~ : @runtime.AppRuntime,
  window_requests~ : @backend_host.WindowRequests,
  surface_binding~ : DesktopSurfaceBinding[W],
  services~ : @window_services.WindowServiceState,
  scene_resolver~ : @window_lifecycle.WindowSceneResolver = @window_lifecycle.WindowSceneResolver::unavailable(),
  event_sources~ : @runtime.HostPlatformEventSources? = None,
  frame_clock~ : (() -> Double)? = None,
  platform_view_plugins~ : Array[@backend_host.PlatformViewPlugin] = [],
  first_frame_smoke_auto_exit~ : Bool = false,
) -> DesktopNativeHostBackendCore[W, Extra] {
  {
    title,
    runtime,
    driver: @runtime.HostRuntimeDriver::new(
      runtime~,
      schedule_redraw=() => (),
      frame_clock~,
    ),
    lifecycle: @window_lifecycle.WindowLifecycle::new(
      requests=window_requests,
      scene_resolver~,
    ),
    frames: @window_frame.WindowFrameStates::new(),
    images: @window_image.WindowImageTaskStates::new(),
    input: @window_input.WindowInputState::new(event_sources~),
    surface_binding,
    services,
    platform_slots: @window_lifecycle.WindowSlotMap::new(),
    platform_view_plugins,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    first_frame_smoke_auto_exit,
  }
}
