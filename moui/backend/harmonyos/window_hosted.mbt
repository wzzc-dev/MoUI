///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/harmonyos` HostCmd → ApplicationHandler. Surface
/// attachment is driven only by the platform event loop.
pub struct HarmonyOsEmbeddedRuntimeBackend {
  title : String
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> HarmonyOsRendererProvider
  mut runtime : @runtime.AppRuntime?
  mut session : HarmonyOsRuntimeSession?
  mut window : @window_harmonyos.Window?
  mut provider : HarmonyOsRendererProvider?
  mut last_pointer : @core.Point
  modifiers : @core.KeyModifiers
  mut last_generation : Int
  mut frames_presented : Int
  auto_exit_after_frames : Int?
}

///|
pub fn HarmonyOsEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> HarmonyOsRendererProvider,
  auto_exit_after_frames? : Int? = None,
) -> HarmonyOsEmbeddedRuntimeBackend {
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
pub fn HarmonyOsEmbeddedRuntimeBackend::frames_presented(
  self : HarmonyOsEmbeddedRuntimeBackend,
) -> Int {
  self.frames_presented
}

///|
pub fn HarmonyOsEmbeddedRuntimeBackend::surface_generation(
  self : HarmonyOsEmbeddedRuntimeBackend,
) -> Int {
  self.last_generation
}

///|
pub fn HarmonyOsEmbeddedRuntimeBackend::session_attached(
  self : HarmonyOsEmbeddedRuntimeBackend,
) -> Bool {
  match self.session {
    Some(session) => session.surface_attached()
    None => false
  }
}

///|
pub fn HarmonyOsEmbeddedRuntimeBackend::has_session(
  self : HarmonyOsEmbeddedRuntimeBackend,
) -> Bool {
  self.session is Some(_)
}

///|
fn HarmonyOsEmbeddedRuntimeBackend::metrics_from_window(
  _self : HarmonyOsEmbeddedRuntimeBackend,
  window : @window_harmonyos.Window,
) -> @host.HostSurfaceMetrics {
  let size = window.inner_size()
  let scale = window.scale_factor()
  @host.surface_metrics_from_physical(size, scale_factor=scale)
}

///|
fn HarmonyOsEmbeddedRuntimeBackend::attach_session(
  self : HarmonyOsEmbeddedRuntimeBackend,
  window : @window_harmonyos.Window,
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
  let surface = HarmonyOsSurfaceHandle::new(
    raw=window.xcomponent_window_handle(),
  )
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
fn HarmonyOsEmbeddedRuntimeBackend::detach_session(
  self : HarmonyOsEmbeddedRuntimeBackend,
) -> Unit {
  match self.session {
    Some(session) => ignore(session.detach_surface())
    None => ()
  }
  self.window = None
}

///|
fn HarmonyOsEmbeddedRuntimeBackend::dispatch_window_event(
  self : HarmonyOsEmbeddedRuntimeBackend,
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
pub impl @window_harmonyos.ApplicationHandler for HarmonyOsEmbeddedRuntimeBackend with fn resumed(
  _self,
  _event_loop,
) {
  ()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOsEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  if self.window is Some(_) {
    return
  }
  let attrs = @window_core.WindowAttributes::default().with_title(self.title)
  let created : @window_harmonyos.Window? = Some(
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
pub impl @window_harmonyos.ApplicationHandler for HarmonyOsEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.detach_session()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOsEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  // Surface may already be destroyed; ensure session is detached.
  if self.window is None {
    self.detach_session()
  }
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOsEmbeddedRuntimeBackend with fn window_event(
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
pub impl @window_harmonyos.ApplicationHandler for HarmonyOsEmbeddedRuntimeBackend with fn about_to_wait(
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
pub fn harmonyos_window_hosted_pump_host_sim(
  app : HarmonyOsEmbeddedRuntimeBackend,
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
  match app.window {
    Some(window) => window.request_redraw()
    None => ()
  }
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
