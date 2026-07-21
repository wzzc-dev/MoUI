///|
/// Window-hosted MoUI path (winit-style): surface/input come only from
/// `wzzc-dev/window/ios` HostCmd → ApplicationHandler. No Embedding
/// attach_surface inject dual-stack.
pub struct IosWindowHostedApp {
  title : String
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> IosRendererProvider
  mut runtime : @runtime.AppRuntime?
  mut session : IosRuntimeSession?
  mut window : @window_ios.Window?
  mut provider : IosRendererProvider?
  mut last_pointer : @core.Point
  modifiers : @core.KeyModifiers
  mut last_generation : Int
  mut frames_presented : Int
  auto_exit_after_frames : Int?
  ime_sink : IosImeSink
}

///|
pub fn IosWindowHostedApp::new(
  title~ : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> IosRendererProvider,
  auto_exit_after_frames? : Int? = None,
) -> IosWindowHostedApp {
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
    ime_sink: IosImeSink::new(),
  }
}

///|
pub fn IosWindowHostedApp::frames_presented(
  self : IosWindowHostedApp,
) -> Int {
  self.frames_presented
}

///|
pub fn IosWindowHostedApp::surface_generation(
  self : IosWindowHostedApp,
) -> Int {
  self.last_generation
}

///|
pub fn IosWindowHostedApp::session_attached(
  self : IosWindowHostedApp,
) -> Bool {
  match self.session {
    Some(session) => session.surface_attached()
    None => false
  }
}

///|
pub fn IosWindowHostedApp::has_session(self : IosWindowHostedApp) -> Bool {
  self.session is Some(_)
}

///|
fn IosWindowHostedApp::metrics_from_window(
  _self : IosWindowHostedApp,
  window : @window_ios.Window,
) -> @host.HostSurfaceMetrics {
  let size = window.inner_size()
  let scale = window.scale_factor()
  @host.surface_metrics_from_physical(size, scale_factor=scale)
}

///|
fn IosWindowHostedApp::attach_session(
  self : IosWindowHostedApp,
  window : @window_ios.Window,
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
  let view = IosViewHandle::new(raw=window.view_handle())
  match self.session {
    Some(session) => {
      ignore(session.attach_view(view, metrics, provider))
      self.last_generation = session.session_generation()
    }
    None =>
      match create_session(runtime~, view=view, metrics~, provider~) {
        Some(session) => {
          self.session = Some(session)
          self.last_generation = session.session_generation()
        }
        None => ()
      }
  }
}

///|
fn IosWindowHostedApp::detach_session(self : IosWindowHostedApp) -> Unit {
  match self.session {
    Some(session) => ignore(session.detach_view())
    None => ()
  }
  self.window = None
}

///|
fn IosWindowHostedApp::sync_ime(self : IosWindowHostedApp) -> Unit {
  match self.runtime {
    Some(runtime) => self.ime_sink.apply(runtime.focused_text_input())
    None => {
      let empty = @core.TextInputState::none()
      self.ime_sink.apply(empty)
    }
  }
}

///|
fn IosWindowHostedApp::dispatch_window_event(
  self : IosWindowHostedApp,
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
  self.sync_ime()
}

///|
pub impl @window_ios.ApplicationHandler for IosWindowHostedApp with fn resumed(
  _self,
  _event_loop,
) {
  ()
}

///|
pub impl @window_ios.ApplicationHandler for IosWindowHostedApp with fn can_create_surfaces(
  self,
  event_loop,
) {
  if self.window is Some(_) {
    return
  }
  let attrs = @window_core.WindowAttributes::default().with_title(self.title)
  let created : @window_ios.Window? = Some(
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
pub impl @window_ios.ApplicationHandler for IosWindowHostedApp with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.detach_session()
}

///|
pub impl @window_ios.ApplicationHandler for IosWindowHostedApp with fn suspended(
  self,
  _event_loop,
) {
  // Surface may already be destroyed; ensure session is detached.
  if self.window is None {
    self.detach_session()
  }
}

///|
pub impl @window_ios.ApplicationHandler for IosWindowHostedApp with fn window_event(
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
        Some(limit) =>
          if self.frames_presented >= limit {
            event_loop.exit()
          }
        None => ()
      }
    }
    _ => self.dispatch_window_event(event)
  }
}

///|
pub impl @window_ios.ApplicationHandler for IosWindowHostedApp with fn about_to_wait(
  self,
  _event_loop,
) {
  self.sync_ime()
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
pub fn ios_window_hosted_pump_host_sim(
  app : IosWindowHostedApp,
  surface_handle~ : UInt64 = 0xABCUL,
  width~ : Int = 320,
  height~ : Int = 640,
  scale~ : Double = 2.0,
) -> Unit {
  @window_ios.host_reset_for_test()
  let event_loop = @window_ios.EventLoop::new()
  @window_ios.host_push(@window_ios.HostCmd::Start)
  @window_ios.host_push(@window_ios.HostCmd::Resume)
  @window_ios.host_push(
    @window_ios.HostCmd::SurfaceInit(surface_handle, 0UL, width, height, scale),
  )
  ignore(event_loop.pump_app_events(None, app))
  match app.window {
    Some(window) => window.request_redraw()
    None => ()
  }
  ignore(event_loop.pump_app_events(None, app))
  @window_ios.host_push(@window_ios.HostCmd::PointerButton(true, 10.0, 20.0))
  @window_ios.host_push(@window_ios.HostCmd::PointerButton(false, 10.0, 20.0))
  ignore(event_loop.pump_app_events(None, app))
  @window_ios.host_push(@window_ios.HostCmd::SurfaceTerm)
  @window_ios.host_push(@window_ios.HostCmd::Stop)
  ignore(event_loop.pump_app_events(None, app))
  event_loop.drop()
}
