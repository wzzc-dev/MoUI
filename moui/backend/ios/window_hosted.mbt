///|
/// Embedded runtime backend on the window-hosted route: surface/input comes
/// only from `wzzc-dev/window/ios` HostCmd → ApplicationHandler. Surface
/// attachment is driven only by the platform event loop.
pub struct IosEmbeddedRuntimeBackend {
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
  mut surface_lifecycle : @platform_bridge.PlatformSurfaceLifecycle
  auto_exit_after_frames : Int?
  ime_sink : IosImeSink
}

///|
pub fn IosEmbeddedRuntimeBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> IosRendererProvider,
  auto_exit_after_frames? : Int? = None,
) -> IosEmbeddedRuntimeBackend {
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
    surface_lifecycle: @platform_bridge.PlatformSurfaceLifecycle::Detached,
    auto_exit_after_frames,
    ime_sink: IosImeSink::new(),
  }
}

///|
pub fn IosEmbeddedRuntimeBackend::frames_presented(
  self : IosEmbeddedRuntimeBackend,
) -> Int {
  self.frames_presented
}

///|
pub fn IosEmbeddedRuntimeBackend::surface_generation(
  self : IosEmbeddedRuntimeBackend,
) -> Int {
  self.last_generation
}

///|
pub fn IosEmbeddedRuntimeBackend::session_attached(
  self : IosEmbeddedRuntimeBackend,
) -> Bool {
  match self.session {
    Some(session) => session.surface_attached()
    None => false
  }
}

///|
pub fn IosEmbeddedRuntimeBackend::has_session(
  self : IosEmbeddedRuntimeBackend,
) -> Bool {
  self.session is Some(_)
}

///|
fn IosEmbeddedRuntimeBackend::metrics_from_window(
  _self : IosEmbeddedRuntimeBackend,
  window : @window_ios.Window,
) -> @host.HostSurfaceMetrics {
  let size = window.inner_size()
  let scale = window.scale_factor()
  @platform_bridge.make_surface_metrics(size, scale_factor=scale)
}

///|
fn IosEmbeddedRuntimeBackend::attach_session(
  self : IosEmbeddedRuntimeBackend,
  window : @window_ios.Window,
) -> Unit {
  let metrics = self.metrics_from_window(window)
  self.surface_lifecycle = @platform_bridge.PlatformSurfaceLifecycle::attach(
    metrics,
  )
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
      match create_session(runtime~, view~, metrics~, provider~) {
        Some(session) => {
          self.session = Some(session)
          self.last_generation = session.session_generation()
        }
        None => ()
      }
  }
}

///|
fn IosEmbeddedRuntimeBackend::detach_session(
  self : IosEmbeddedRuntimeBackend,
) -> Unit {
  match self.session {
    Some(session) => ignore(session.detach_view())
    None => ()
  }
  self.window = None
  self.surface_lifecycle = self.surface_lifecycle.detach()
}

///|
fn IosEmbeddedRuntimeBackend::sync_ime(
  self : IosEmbeddedRuntimeBackend,
) -> Unit {
  match self.runtime {
    Some(runtime) => self.ime_sink.apply(runtime.focused_text_input())
    None => {
      let empty = @core.TextInputState::none()
      self.ime_sink.apply(empty)
    }
  }
}

///|
fn IosEmbeddedRuntimeBackend::dispatch_window_event(
  self : IosEmbeddedRuntimeBackend,
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
    Some(host_event) => self.dispatch_host_event(host_event)
    None => ()
  }
}

///|
fn IosEmbeddedRuntimeBackend::dispatch_host_event(
  self : IosEmbeddedRuntimeBackend,
  host_event : @host.HostEvent,
) -> Unit {
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
  self.sync_ime()
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
  if self.window is Some(_) {
    return
  }
  let attrs = @window_core.WindowAttributes::default().with_title(self.title)
  let created : @window_ios.Window? = Some(event_loop.try_create_window(attrs)) catch {
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
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.detach_session()
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  // Surface may already be destroyed; ensure session is detached.
  if self.window is None {
    self.detach_session()
  }
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  let (scale_factor, surface_size) = match self.window {
    Some(window) => (window.scale_factor(), Some(window.inner_size()))
    None => (1.0, None)
  }
  match
    @platform_bridge.transform_cross_platform_event(
      event,
      scale_factor~,
      surface_size~,
    ) {
    @platform_bridge.TransformedWindowEvent::CloseRequested => {
      self.dispatch_host_event(@host.HostEvent::CloseRequested)
      event_loop.exit()
    }
    @platform_bridge.TransformedWindowEvent::DispatchHostEvent(host_event) =>
      self.dispatch_host_event(host_event)
    @platform_bridge.TransformedWindowEvent::WindowRedrawRequired => {
      self.dispatch_host_event(@host.HostEvent::RedrawRequested)
      match self.auto_exit_after_frames {
        Some(limit) => if self.frames_presented >= limit { event_loop.exit() }
        None => ()
      }
    }
    _ => self.dispatch_window_event(event)
  }
}

///|
pub impl @window_ios.ApplicationHandler for IosEmbeddedRuntimeBackend with fn about_to_wait(
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
