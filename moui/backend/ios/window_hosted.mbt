///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/ios` HostCmd → ApplicationHandler. Surface
/// attachment is driven only by the platform event loop. The backend is a
/// thin shell around the shared `HostedWindowBackend`; native view access,
/// the IME sink and window creation stay here.
pub struct IosEmbeddedRuntimeBackend {
  backend : @embedded_runtime_backend.HostedWindowBackend
}

///|
pub fn IosEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> IosRendererProvider,
  auto_exit_after_frames? : Int? = None,
) -> IosEmbeddedRuntimeBackend {
  let ime_sink = IosImeSink::new()
  {
    backend: @embedded_runtime_backend.HostedWindowBackend::new(
      title~,
      runtime_factory~,
      provider_factory=() => {
        let provider = provider_factory()
        @embedded_runtime_backend.RendererProviderAdapter::new(
          create_renderer=fn(raw, metrics) {
            provider.create(IosViewHandle::new(raw~), metrics)
          },
          sync=fn(raw, metrics) {
            provider.sync(IosViewHandle::new(raw~), metrics)
          },
          image_loader=provider.image_loader,
        )
      },
      ime_sync=Some(fn(runtime) {
        match runtime {
          Some(runtime) => ime_sink.apply(runtime.focused_text_input())
          None => ime_sink.apply(@core.TextInputState::none())
        }
      }),
      auto_exit_after_frames~,
    ),
  }
}

///|
pub fn IosEmbeddedRuntimeBackend::frames_presented(
  self : IosEmbeddedRuntimeBackend,
) -> Int {
  self.backend.frames_presented()
}

///|
pub fn IosEmbeddedRuntimeBackend::surface_generation(
  self : IosEmbeddedRuntimeBackend,
) -> Int {
  self.backend.surface_generation()
}

///|
pub fn IosEmbeddedRuntimeBackend::session_attached(
  self : IosEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.session_attached()
}

///|
pub fn IosEmbeddedRuntimeBackend::has_session(
  self : IosEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.has_session()
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn resumed(
  _self,
  _event_loop,
) {
  ()
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  if self.backend.has_window() {
    return
  }
  let attrs = @window_core.WindowAttributes::default().with_title(
    self.backend.title(),
  )
  let created : @window_ios.Window? = Some(event_loop.try_create_window(attrs)) catch {
    _ => None
  }
  match created {
    Some(window) => {
      let hosted = @embedded_runtime_backend.HostedWindow::new(
        scale_factor=fn() { window.scale_factor() },
        inner_size=fn() { window.inner_size() },
        request_redraw=fn() { window.request_redraw() },
      )
      self.backend.attach_session(hosted, raw_handle=window.view_handle())
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.backend.detach_session()
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  // Surface may already be destroyed; ensure session is detached.
  if !self.backend.has_window() {
    self.backend.detach_session()
  }
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  self.backend.handle_window_event(event, exit=fn() { event_loop.exit() })
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn about_to_wait(
  self,
  _event_loop,
) {
  self.backend.about_to_wait()
}

///|
/// Pump one host-sim cycle for tests / offline validation.
pub fn ios_window_hosted_pump_host_sim(
  app : IosEmbeddedRuntimeBackend,
  surface_handle? : UInt64 = 0xABCUL,
  width? : Int = 320,
  height? : Int = 640,
  scale? : Double = 2.0,
) -> Unit {
  @window_ios.host_reset_for_test()
  let event_loop = @window_ios.EventLoop::new()
  @window_ios.host_push(@window_ios.HostCmd::Start)
  @window_ios.host_push(@window_ios.HostCmd::Resume)
  @window_ios.host_push(
    @window_ios.HostCmd::SurfaceInit(surface_handle, 0UL, width, height, scale),
  )
  ignore(event_loop.pump_app_events(None, app))
  app.backend.force_redraw()
  ignore(event_loop.pump_app_events(None, app))
  @window_ios.host_push(@window_ios.HostCmd::PointerButton(true, 10.0, 20.0))
  @window_ios.host_push(@window_ios.HostCmd::PointerButton(false, 10.0, 20.0))
  ignore(event_loop.pump_app_events(None, app))
  @window_ios.host_push(@window_ios.HostCmd::SurfaceTerm)
  @window_ios.host_push(@window_ios.HostCmd::Stop)
  ignore(event_loop.pump_app_events(None, app))
  event_loop.drop()
}
