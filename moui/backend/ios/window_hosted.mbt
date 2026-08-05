///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/ios` HostCmd → ApplicationHandler. Surface
/// attachment is driven only by the platform event loop. The backend is a
/// thin shell around the shared `HostedWindowBackend`; native surface access,
/// the IME sink and window creation stay here.
pub struct IosEmbeddedRuntimeBackend {
  backend : @embedded_runtime.HostedWindowBackend
}

///|
pub fn IosEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  renderer_factories~ : Array[@render.RendererFactory],
  auto_exit_after_frames? : Int? = None,
) -> IosEmbeddedRuntimeBackend {
  new_ios_embedded_runtime(
    title~,
    runtime_factory~,
    surface_binding_factory=() => ios_surface_binding(renderer_factories),
    auto_exit_after_frames~,
  )
}

///|
/// Application-builder entry for the iOS window-hosted event loop.
pub fn entry(auto_exit_after_frames? : Int? = None) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="ios", launch=request => {
    let runtime = request.runtime()
    let app = IosEmbeddedRuntimeBackend::new(
      title=request.title(),
      runtime_factory=_metrics => runtime,
      renderer_factories=request.renderer_factories(),
      auto_exit_after_frames~,
    )
    let event_loop = @window_ios.EventLoop::new()
    event_loop.run_app(app)
  })
}

///|
fn new_ios_embedded_runtime(
  title~ : String,
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  surface_binding_factory~ : () -> IosSurfaceBinding,
  auto_exit_after_frames~ : Int?,
) -> IosEmbeddedRuntimeBackend {
  let ime_sink = IosImeSink::new()
  {
    backend: @embedded_runtime.HostedWindowBackend::new(
      title~,
      runtime_factory~,
      surface_binding_factory=() => {
        host_surface_binding_from_ios(surface_binding_factory())
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
  self,
  _event_loop,
) {
  self.backend.resumed()
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  ignore(
    self.backend.ensure_surface(create=() => {
      let attrs = @window_core.WindowAttributes::default().with_title(
        self.backend.title(),
      )
      let created : @window_ios.Window? = Some(
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
              window.view_handle(),
            ),
          )
        None => None
      }
    }),
  )
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.backend.destroy_surfaces()
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  self.backend.suspended()
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
