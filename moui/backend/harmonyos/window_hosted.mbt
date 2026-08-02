///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/harmonyos` HostCmd → ApplicationHandler.
/// Surface attachment is driven only by the platform event loop. The backend
/// is a thin shell around the shared `HostedWindowBackend`; native
/// XComponent surface access and window creation stay here.
pub struct HarmonyOSEmbeddedRuntimeBackend {
  backend : @embedded_runtime_backend.HostedWindowBackend
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> HarmonyOSRendererProvider,
  auto_exit_after_frames? : Int? = None,
) -> HarmonyOSEmbeddedRuntimeBackend {
  {
    backend: @embedded_runtime_backend.HostedWindowBackend::new(
      title~,
      runtime_factory~,
      provider_factory=() => {
        let provider = provider_factory()
        @embedded_runtime_backend.RendererProviderAdapter::new(
          create_renderer=fn(raw, metrics) {
            provider.create(HarmonyOSSurfaceHandle::new(raw~), metrics)
          },
          sync=fn(raw, metrics) {
            provider.sync(HarmonyOSSurfaceHandle::new(raw~), metrics)
          },
          image_loader=provider.image_loader,
        )
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
  _self,
  _event_loop,
) {
  ()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  if self.backend.has_window() {
    return
  }
  let attrs = @window_core.WindowAttributes::default().with_title(
    self.backend.title(),
  )
  let created : @window_harmonyos.Window? = Some(
    event_loop.try_create_window(attrs),
  ) catch {
    _ => None
  }
  match created {
    Some(window) => {
      let hosted = @embedded_runtime_backend.HostedWindow::new(
        scale_factor=fn() { window.scale_factor() },
        inner_size=fn() { window.inner_size() },
        request_redraw=fn() { window.request_redraw() },
      )
      self.backend.attach_session(
        hosted,
        raw_handle=window.xcomponent_window_handle(),
      )
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.backend.detach_session()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  // Surface may already be destroyed; ensure session is detached.
  if !self.backend.has_window() {
    self.backend.detach_session()
  }
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
