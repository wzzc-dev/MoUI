///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/android` HostCmd → ApplicationHandler. Surface
/// attachment is driven only by the platform event loop. The backend is a
/// thin shell around the shared `HostedWindowBackend`; native window
/// creation and raw surface access stay here.
pub struct AndroidEmbeddedRuntimeBackend {
  backend : @embedded_runtime.HostedWindowBackend
}

///|
/// Android host options captured by the platform entrypoint.
///
/// `status_bar_immersive` enables edge-to-edge content behind the visible
/// status bar. It does not hide the status bar or navigation bar.
pub struct AndroidHostAppOptions {
  priv status_bar_immersive : Bool
}

///|
pub fn AndroidHostAppOptions::new(
  status_bar_immersive? : Bool = false,
) -> AndroidHostAppOptions {
  { status_bar_immersive, }
}

///|
pub fn AndroidHostAppOptions::status_bar_immersive(
  self : AndroidHostAppOptions,
) -> Bool {
  self.status_bar_immersive
}

///|
pub fn AndroidHostAppOptions::with_status_bar_immersive(
  self : AndroidHostAppOptions,
  enabled : Bool,
) -> AndroidHostAppOptions {
  let _ = self
  { status_bar_immersive: enabled }
}

///|
pub fn AndroidEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  renderer_factories~ : Array[@render.RendererFactory],
  auto_exit_after_frames? : Int? = None,
) -> AndroidEmbeddedRuntimeBackend {
  new_android_embedded_runtime(
    title~,
    runtime_factory~,
    surface_binding_factory=() => android_surface_binding(renderer_factories),
    auto_exit_after_frames~,
  )
}

///|
/// Application-builder entry for the Android window-hosted event loop.
pub fn entry(
  options? : AndroidHostAppOptions = AndroidHostAppOptions::new(),
  auto_exit_after_frames? : Int? = None,
) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="android", launch=request => {
    ignore(
      android_set_status_bar_immersive(
        if options.status_bar_immersive {
          1
        } else {
          0
        },
      ),
    )
    let runtime = request.runtime()
    let app = AndroidEmbeddedRuntimeBackend::new(
      title=request.title(),
      runtime_factory=_metrics => runtime,
      renderer_factories=request.renderer_factories(),
      auto_exit_after_frames~,
    )
    let event_loop = @window_android.EventLoop::new()
    event_loop.run_app(app)
  })
}

///|
fn new_android_embedded_runtime(
  title~ : String,
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  surface_binding_factory~ : () -> AndroidSurfaceBinding,
  auto_exit_after_frames~ : Int?,
) -> AndroidEmbeddedRuntimeBackend {
  {
    backend: @embedded_runtime.HostedWindowBackend::new(
      title~,
      runtime_factory~,
      surface_binding_factory=() => {
        host_surface_binding_from_android(surface_binding_factory())
      },
      auto_exit_after_frames~,
    ),
  }
}

///|
pub fn AndroidEmbeddedRuntimeBackend::frames_presented(
  self : AndroidEmbeddedRuntimeBackend,
) -> Int {
  self.backend.frames_presented()
}

///|
pub fn AndroidEmbeddedRuntimeBackend::surface_generation(
  self : AndroidEmbeddedRuntimeBackend,
) -> Int {
  self.backend.surface_generation()
}

///|
pub fn AndroidEmbeddedRuntimeBackend::session_attached(
  self : AndroidEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.session_attached()
}

///|
pub fn AndroidEmbeddedRuntimeBackend::has_session(
  self : AndroidEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.has_session()
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn resumed(
  self,
  _event_loop,
) {
  self.backend.resumed()
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  ignore(
    self.backend.ensure_surface(create=() => {
      let attrs = @window_core.WindowAttributes::default().with_title(
        self.backend.title(),
      )
      let created : @window_android.Window? = Some(
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
              window.native_window_handle(),
            ),
          )
        None => None
      }
    }),
  )
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.backend.destroy_surfaces()
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  self.backend.suspended()
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  self.backend.handle_window_event(event, exit=fn() { event_loop.exit() })
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn about_to_wait(
  self,
  _event_loop,
) {
  self.backend.about_to_wait()
}

///|
/// Pump one host-sim cycle for tests / offline validation.
pub fn android_window_hosted_pump_host_sim(
  app : AndroidEmbeddedRuntimeBackend,
  surface_handle? : UInt64 = 0xABCUL,
  width? : Int = 320,
  height? : Int = 640,
  scale? : Double = 2.0,
) -> Unit {
  @window_android.host_reset_for_test()
  let event_loop = @window_android.EventLoop::new()
  @window_android.host_push(@window_android.HostCmd::Start)
  @window_android.host_push(@window_android.HostCmd::Resume)
  @window_android.host_push(
    @window_android.HostCmd::SurfaceInit(
      surface_handle, 0UL, width, height, scale,
    ),
  )
  ignore(event_loop.pump_app_events(None, app))
  app.backend.force_redraw()
  ignore(event_loop.pump_app_events(None, app))
  @window_android.host_push(
    @window_android.HostCmd::PointerButton(true, 10.0, 20.0),
  )
  @window_android.host_push(
    @window_android.HostCmd::PointerButton(false, 10.0, 20.0),
  )
  ignore(event_loop.pump_app_events(None, app))
  @window_android.host_push(@window_android.HostCmd::SurfaceTerm)
  @window_android.host_push(@window_android.HostCmd::Stop)
  ignore(event_loop.pump_app_events(None, app))
  event_loop.drop()
}
