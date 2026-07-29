///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/android` HostCmd → ApplicationHandler. Surface
/// attachment is driven only by the platform event loop.
pub struct AndroidEmbeddedRuntimeBackend {
  title : String
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> AndroidRendererProvider
  mut runtime : @runtime.AppRuntime?
  mut session : AndroidRuntimeSession?
  mut window : @window_android.Window?
  mut provider : AndroidRendererProvider?
  mut last_pointer : @core.Point
  modifiers : @core.KeyModifiers
  mut last_generation : Int
  mut frames_presented : Int
  auto_exit_after_frames : Int?
}

///|
pub fn AndroidEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> AndroidRendererProvider,
  auto_exit_after_frames? : Int? = None,
) -> AndroidEmbeddedRuntimeBackend {
  {
    title,
    runtime_factory,
    provider_factory,
    runtime: None,
    session: None,
    window: None,
    provider: None,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    last_generation: 0,
    frames_presented: 0,
    auto_exit_after_frames,
  }
}

///|
pub fn AndroidEmbeddedRuntimeBackend::frames_presented(
  self : AndroidEmbeddedRuntimeBackend,
) -> Int {
  self.frames_presented
}

///|
pub fn AndroidEmbeddedRuntimeBackend::surface_generation(
  self : AndroidEmbeddedRuntimeBackend,
) -> Int {
  self.last_generation
}

///|
pub fn AndroidEmbeddedRuntimeBackend::session_attached(
  self : AndroidEmbeddedRuntimeBackend,
) -> Bool {
  match self.session {
    Some(session) => session.surface_attached()
    None => false
  }
}

///|
pub fn AndroidEmbeddedRuntimeBackend::has_session(
  self : AndroidEmbeddedRuntimeBackend,
) -> Bool {
  self.session is Some(_)
}

///|
fn AndroidEmbeddedRuntimeBackend::metrics_from_window(
  _self : AndroidEmbeddedRuntimeBackend,
  window : @window_android.Window,
) -> @host.HostSurfaceMetrics {
  let size = window.inner_size()
  let scale = window.scale_factor()
  @host.surface_metrics_from_physical(size, scale_factor=scale)
}

///|
fn AndroidEmbeddedRuntimeBackend::attach_session(
  self : AndroidEmbeddedRuntimeBackend,
  window : @window_android.Window,
) -> Unit {
  let metrics = self.metrics_from_window(window)
  let runtime = match self.runtime {
    Some(runtime) => {
      runtime.dispatch_event(@core.AppEvent::Resize(metrics.logical_size))
      runtime
    }
    None => {
      let runtime = (self.runtime_factory)(metrics)
      self.runtime = Some(runtime)
      runtime
    }
  }
  let provider = (self.provider_factory)()
  self.provider = Some(provider)
  let surface = AndroidSurfaceHandle::new(raw=window.native_window_handle())
  match self.session {
    Some(session) => {
      ignore(session.attach_surface(surface, metrics, provider))
      self.last_generation = session.session_generation()
    }
    None =>
      match create_session(runtime~, surface~, metrics~, provider~) {
        Some(session) => {
          self.session = Some(session)
          self.last_generation = session.session_generation()
        }
        None => ()
      }
  }
}

///|
fn AndroidEmbeddedRuntimeBackend::detach_session(
  self : AndroidEmbeddedRuntimeBackend,
) -> Unit {
  match self.session {
    Some(session) => ignore(session.detach_surface())
    None => ()
  }
  self.window = None
}

///|
fn AndroidEmbeddedRuntimeBackend::dispatch_window_event(
  self : AndroidEmbeddedRuntimeBackend,
  event : @window_core.WindowEvent,
) -> Unit {
  let scale = match self.window {
    Some(window) => window.scale_factor()
    None => 1.0
  }
  match
    @host.window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor=scale,
    ) {
    Some(host_event) => {
      match host_event {
        @host.HostEvent::Pointer(pointer) => {
          match self.session {
            Some(session) => ignore(session.dispatch(host_event))
            None => ()
          }
          self.last_pointer = pointer.position
        }
        @host.HostEvent::Resized(metrics) =>
          match self.session {
            Some(session) => ignore(session.resize(metrics))
            None => ()
          }
        @host.HostEvent::RedrawRequested =>
          match self.session {
            Some(session) => {
              ignore(session.render_frame())
              self.frames_presented = self.frames_presented + 1
            }
            None => ()
          }
        _ =>
          match self.session {
            Some(session) => ignore(session.dispatch(host_event))
            None => ()
          }
      }
      match host_event {
        @host.HostEvent::Resized(_) | @host.HostEvent::RedrawRequested => ()
        _ =>
          match self.session {
            Some(session) =>
              if session.take_redraw_requested() || session.redraw_requested() {
                match self.window {
                  Some(window) => window.request_redraw()
                  None => ()
                }
              }
            None => ()
          }
      }
    }
    None => ()
  }
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn resumed(
  _self,
  _event_loop,
) {
  ()
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  if self.window is Some(_) {
    return
  }
  let attrs = @window_core.WindowAttributes::default().with_title(self.title)
  let created : @window_android.Window? = Some(
    event_loop.try_create_window(attrs),
  ) catch {
    _ => None
  }
  match created {
    Some(window) => {
      self.window = Some(window)
      self.attach_session(window)
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.detach_session()
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  // Surface may already be destroyed; ensure session is detached.
  if self.window is None {
    self.detach_session()
  }
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  match event {
    @window_core.WindowEvent::CloseRequested => event_loop.exit()
    @window_core.WindowEvent::RedrawRequested => {
      self.dispatch_window_event(event)
      match self.auto_exit_after_frames {
        Some(limit) => if self.frames_presented >= limit { event_loop.exit() }
        None => ()
      }
    }
    _ => self.dispatch_window_event(event)
  }
}

///|
pub impl @window_android.ApplicationHandler for AndroidEmbeddedRuntimeBackend with fn about_to_wait(
  self,
  _event_loop,
) {
  match self.session {
    Some(session) =>
      if session.take_redraw_requested() || session.redraw_requested() {
        match self.window {
          Some(window) => window.request_redraw()
          None => ()
        }
      }
    None => ()
  }
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
  match app.window {
    Some(window) => window.request_redraw()
    None => ()
  }
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
