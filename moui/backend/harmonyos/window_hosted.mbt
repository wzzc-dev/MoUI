///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/harmonyos` HostCmd → ApplicationHandler.
/// Surface attachment is driven only by the platform event loop. The backend
/// is a thin shell around the shared `HostedWindowBackend`; native
/// XComponent surface access and window creation stay here.
pub struct HarmonyOSEmbeddedRuntimeBackend {
  backend : @embedded_runtime.HostedWindowBackend
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  renderer_providers~ : Array[@render.RendererProvider],
  auto_exit_after_frames? : Int? = None,
) -> HarmonyOSEmbeddedRuntimeBackend {
  new_harmonyos_embedded_runtime(
    title~,
    runtime_factory~,
    surface_binding_factory=() => harmonyos_surface_binding(renderer_providers),
    auto_exit_after_frames~,
  )
}

///|
/// Application-builder entry for the HarmonyOS window-hosted event loop.
pub fn entry(auto_exit_after_frames? : Int? = None) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="harmonyos", launch=request => {
    let runtime = request.runtime()
    let app = HarmonyOSEmbeddedRuntimeBackend::new(
      title=request.title(),
      runtime_factory=_metrics => runtime,
      renderer_providers=request.renderer_providers(),
      auto_exit_after_frames~,
    )
    let event_loop = @window_harmonyos.EventLoop::new()
    event_loop.run_app(app)
  })
}

///|
fn new_harmonyos_embedded_runtime(
  title~ : String,
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  surface_binding_factory~ : () -> HarmonyOSSurfaceBinding,
  auto_exit_after_frames~ : Int?,
) -> HarmonyOSEmbeddedRuntimeBackend {
  {
    backend: @embedded_runtime.HostedWindowBackend::new(
      title~,
      runtime_factory~,
      surface_binding_factory=() => {
        host_surface_binding_from_harmonyos(surface_binding_factory())
      },
      auto_exit_after_frames~,
    ),
  }
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::frames_presented(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Int {
  self.backend.frames_presented()
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::surface_generation(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Int {
  self.backend.surface_generation()
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::session_attached(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.session_attached()
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::has_session(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.has_session()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn resumed(
  self,
  _event_loop,
) {
  self.backend.resumed()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  ignore(
    self.backend.ensure_surface(create=() => {
      let attrs = @window_core.WindowAttributes::default().with_title(
        self.backend.title(),
      )
      let created : @window_harmonyos.Window? = Some(
        event_loop.try_create_window(attrs),
      ) catch {
        _ => None
      }
      match created {
        Some(window) =>
          Some(
            (
              @embedded_runtime.HostedWindow::new(
                scale_factor=fn() { window.scale_factor() },
                inner_size=fn() { window.inner_size() },
                request_redraw=fn() { window.request_redraw() },
                drop=fn() { window.drop() },
              ),
              window.xcomponent_window_handle(),
            ),
          )
        None => None
      }
    }),
  )
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.backend.destroy_surfaces()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  self.backend.suspended()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  self.backend.handle_window_event(event, exit=fn() { event_loop.exit() })
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn about_to_wait(
  self,
  _event_loop,
) {
  self.backend.about_to_wait()
}

///|
/// Pump one host-sim cycle for tests / offline validation.
pub fn harmonyos_window_hosted_pump_host_sim(
  app : HarmonyOSEmbeddedRuntimeBackend,
  surface_handle? : UInt64 = 0xABCUL,
  width? : Int = 320,
  height? : Int = 640,
  scale? : Double = 2.0,
) -> Unit {
  @window_harmonyos.host_reset_for_test()
  let event_loop = @window_harmonyos.EventLoop::new()
  @window_harmonyos.host_push(@window_harmonyos.HostCmd::Start)
  @window_harmonyos.host_push(@window_harmonyos.HostCmd::Resume)
  @window_harmonyos.host_push(
    @window_harmonyos.HostCmd::SurfaceInit(
      surface_handle, 0UL, width, height, scale,
    ),
  )
  ignore(event_loop.pump_app_events(None, app))
  app.backend.force_redraw()
  ignore(event_loop.pump_app_events(None, app))
  @window_harmonyos.host_push(
    @window_harmonyos.HostCmd::PointerButton(true, 10.0, 20.0),
  )
  @window_harmonyos.host_push(
    @window_harmonyos.HostCmd::PointerButton(false, 10.0, 20.0),
  )
  ignore(event_loop.pump_app_events(None, app))
  @window_harmonyos.host_push(@window_harmonyos.HostCmd::SurfaceTerm)
  @window_harmonyos.host_push(@window_harmonyos.HostCmd::Stop)
  ignore(event_loop.pump_app_events(None, app))
  event_loop.drop()
}
