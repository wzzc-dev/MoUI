///|
/// Shared window-hosted embedded backend skeleton.
///
/// The mobile platform packages (android / ios / harmonyos) declare their
/// `{P}EmbeddedRuntimeBackend` structs, `ApplicationHandler` trait impls and
/// host-sim pumps as thin shells around this type. Native window creation,
/// raw surface handle access and the trait impl declarations stay in the
/// platform package; session lifecycle, event routing, redraw pumping and
/// IME sync live here exactly once.

///|
/// Platform window projection used by the shared backend. Windows are
/// created by the platform package and captured into these closures.
pub struct HostedWindow {
  scale_factor : () -> Double
  inner_size : () -> @dpi.PhysicalSize
  request_redraw : () -> Unit
}

///|
pub fn HostedWindow::new(
  scale_factor~ : () -> Double,
  inner_size~ : () -> @dpi.PhysicalSize,
  request_redraw~ : () -> Unit,
) -> HostedWindow {
  { scale_factor, inner_size, request_redraw }
}

///|
/// Renderer provider projection. Platform providers (`{P}RendererProvider`)
/// are struct-of-closures already; platform packages adapt them to this
/// neutral shape with raw (UInt64) surface handles.
pub struct RendererProviderAdapter {
  create_renderer : (UInt64, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  sync : (UInt64, @host.HostSurfaceMetrics) -> Unit
  image_loader : @render.HostAsyncImageLoader?
}

///|
pub fn RendererProviderAdapter::new(
  create_renderer~ : (UInt64, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync~ : (UInt64, @host.HostSurfaceMetrics) -> Unit,
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> RendererProviderAdapter {
  { create_renderer, sync, image_loader }
}

///|
/// Shared runtime session: wraps `EmbeddedRuntimeBackendCore` with the raw
/// native surface handle. Replaces the per-platform `{P}RuntimeSession`
/// forwarding shells.
pub struct HostedRuntimeSession {
  mut raw_handle : UInt64
  core : EmbeddedRuntimeBackendCore
}

///|
pub fn HostedRuntimeSession::raw_handle(self : HostedRuntimeSession) -> UInt64 {
  self.raw_handle
}

///|
/// Create a session from a fresh surface handle and renderer provider.
pub fn HostedRuntimeSession::create(
  runtime~ : @runtime.AppRuntime,
  raw_handle~ : UInt64,
  metrics~ : @host.HostSurfaceMetrics,
  adapter~ : RendererProviderAdapter,
) -> HostedRuntimeSession? {
  match (adapter.create_renderer)(raw_handle, metrics) {
    Some(renderer) => {
      let core = EmbeddedRuntimeBackendCore::new(
        runtime~,
        renderer~,
        image_loader=adapter.image_loader,
        metrics~,
      )
      (adapter.sync)(raw_handle, metrics)
      Some({ raw_handle, core })
    }
    None => None
  }
}

///|
pub fn HostedRuntimeSession::attach(
  self : HostedRuntimeSession,
  raw_handle~ : UInt64,
  metrics~ : @host.HostSurfaceMetrics,
  adapter~ : RendererProviderAdapter,
) -> Bool {
  match (adapter.create_renderer)(raw_handle, metrics) {
    Some(renderer) =>
      if self.core.attach_surface(
          renderer~,
          metrics~,
          image_loader=adapter.image_loader,
        ) {
        self.raw_handle = raw_handle
        (adapter.sync)(raw_handle, metrics)
        true
      } else {
        false
      }
    None => false
  }
}

///|
pub fn HostedRuntimeSession::detach(self : HostedRuntimeSession) -> Bool {
  if self.core.detach_surface() {
    self.raw_handle = 0UL
    true
  } else {
    false
  }
}

///|
pub fn HostedRuntimeSession::metrics(
  self : HostedRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.core.metrics()
}

///|
pub fn HostedRuntimeSession::runtime(
  self : HostedRuntimeSession,
) -> @runtime.AppRuntime {
  self.core.runtime()
}

///|
pub fn HostedRuntimeSession::disposed(self : HostedRuntimeSession) -> Bool {
  self.core.disposed()
}

///|
pub fn HostedRuntimeSession::surface_attached(
  self : HostedRuntimeSession,
) -> Bool {
  self.core.surface_attached()
}

///|
pub fn HostedRuntimeSession::session_generation(
  self : HostedRuntimeSession,
) -> Int {
  self.core.session_generation()
}

///|
pub fn HostedRuntimeSession::surface_epoch(self : HostedRuntimeSession) -> Int {
  self.core.surface_epoch()
}

///|
pub fn HostedRuntimeSession::dispatch(
  self : HostedRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  self.core.dispatch(event)
}

///|
pub fn HostedRuntimeSession::resize(
  self : HostedRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.core.resize(metrics)
}

///|
pub fn HostedRuntimeSession::render_frame(
  self : HostedRuntimeSession,
) -> @render.RenderFrameResult {
  self.core.render_frame()
}

///|
pub fn HostedRuntimeSession::advance_time(
  self : HostedRuntimeSession,
  time_ms : Double,
) -> Unit {
  self.core.advance_time(time_ms)
}

///|
pub fn HostedRuntimeSession::drain_host_updates(
  self : HostedRuntimeSession,
) -> Array[EmbeddingHostUpdate] {
  self.core.drain_host_updates()
}

///|
pub fn HostedRuntimeSession::drain_host_updates_json(
  self : HostedRuntimeSession,
) -> String {
  self.core.drain_host_updates_json()
}

///|
pub fn HostedRuntimeSession::drain_host_update_envelope_json(
  self : HostedRuntimeSession,
) -> String {
  self.core.drain_host_update_envelope_json()
}

///|
pub fn HostedRuntimeSession::dispatch_host_response(
  self : HostedRuntimeSession,
  response : EmbeddingHostResponse,
) -> Bool {
  self.core.dispatch_host_response(response)
}

///|
pub fn HostedRuntimeSession::dispatch_host_response_envelope(
  self : HostedRuntimeSession,
  envelope : EmbeddingHostResponseEnvelope,
) -> Bool {
  self.core.dispatch_host_response_envelope(envelope)
}

///|
pub fn HostedRuntimeSession::dispatch_host_response_envelope_json(
  self : HostedRuntimeSession,
  text : String,
) -> Bool {
  self.core.dispatch_host_response_envelope_json(text)
}

///|
pub fn HostedRuntimeSession::host_service_bridge(
  self : HostedRuntimeSession,
) -> @host.HostServiceBridge {
  self.core.host_service_bridge()
}

///|
pub fn HostedRuntimeSession::redraw_requested(
  self : HostedRuntimeSession,
) -> Bool {
  self.core.redraw_requested()
}

///|
pub fn HostedRuntimeSession::take_redraw_requested(
  self : HostedRuntimeSession,
) -> Bool {
  self.core.take_redraw_requested()
}

///|
pub fn HostedRuntimeSession::present_count(self : HostedRuntimeSession) -> Int {
  self.core.present_count()
}

///|
pub fn HostedRuntimeSession::dispose(self : HostedRuntimeSession) -> Unit {
  self.core.dispose()
}

///|
/// Shared window-hosted embedded backend state. Platform packages embed this
/// as the single field of their `{P}EmbeddedRuntimeBackend` and forward the
/// public accessors; `ApplicationHandler` slots call the shared methods.
pub struct HostedWindowBackend {
  title : String
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> RendererProviderAdapter
  ime_sync : ((@runtime.AppRuntime?) -> Unit)?
  mut window : HostedWindow?
  mut runtime : @runtime.AppRuntime?
  mut session : HostedRuntimeSession?
  mut last_pointer : @core.Point
  modifiers : @core.KeyModifiers
  mut last_generation : Int
  mut frames_presented : Int
  mut surface_lifecycle : @platform_bridge.PlatformSurfaceLifecycle
  auto_exit_after_frames : Int?
}

///|
pub fn HostedWindowBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> RendererProviderAdapter,
  ime_sync? : ((@runtime.AppRuntime?) -> Unit)? = None,
  auto_exit_after_frames? : Int? = None,
) -> HostedWindowBackend {
  {
    title,
    runtime_factory,
    provider_factory,
    ime_sync,
    window: None,
    runtime: None,
    session: None,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    last_generation: 0,
    frames_presented: 0,
    surface_lifecycle: @platform_bridge.PlatformSurfaceLifecycle::Detached,
    auto_exit_after_frames,
  }
}

///|
pub fn HostedWindowBackend::title(self : HostedWindowBackend) -> String {
  self.title
}

///|
pub fn HostedWindowBackend::frames_presented(self : HostedWindowBackend) -> Int {
  self.frames_presented
}

///|
pub fn HostedWindowBackend::surface_generation(
  self : HostedWindowBackend,
) -> Int {
  self.last_generation
}

///|
pub fn HostedWindowBackend::session_attached(
  self : HostedWindowBackend,
) -> Bool {
  match self.session {
    Some(session) => session.surface_attached()
    None => false
  }
}

///|
pub fn HostedWindowBackend::has_session(self : HostedWindowBackend) -> Bool {
  self.session is Some(_)
}

///|
pub fn HostedWindowBackend::has_window(self : HostedWindowBackend) -> Bool {
  self.window is Some(_)
}

///|
/// Create or re-attach the runtime session for a freshly created window.
/// Called from the platform `can_create_surfaces` slot.
pub fn HostedWindowBackend::attach_session(
  self : HostedWindowBackend,
  window : HostedWindow,
  raw_handle~ : UInt64,
) -> Unit {
  let metrics = @platform_bridge.make_surface_metrics(
    (window.inner_size)(),
    scale_factor=(window.scale_factor)(),
  )
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
  self.window = Some(window)
  let adapter = (self.provider_factory)()
  match self.session {
    Some(session) => {
      ignore(session.attach(raw_handle~, metrics~, adapter~))
      self.last_generation = session.session_generation()
    }
    None =>
      match
        HostedRuntimeSession::create(runtime~, raw_handle~, metrics~, adapter~) {
        Some(session) => {
          self.session = Some(session)
          self.last_generation = session.session_generation()
        }
        None => ()
      }
  }
}

///|
pub fn HostedWindowBackend::detach_session(self : HostedWindowBackend) -> Unit {
  match self.session {
    Some(session) => ignore(session.detach())
    None => ()
  }
  self.window = None
  self.surface_lifecycle = self.surface_lifecycle.detach()
}

///|
/// Dispatch a host event into the session and drive requested redraws plus
/// the platform IME sync hook.
pub fn HostedWindowBackend::dispatch_host_event(
  self : HostedWindowBackend,
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
    _ => self.pump_redraw_requested()
  }
  self.sync_ime()
}

///|
/// Convert a platform `WindowEvent` to a host event and dispatch it.
/// Platform-specific event payloads are decoded by `@host` helpers.
pub fn HostedWindowBackend::dispatch_window_event(
  self : HostedWindowBackend,
  event : @window_core.WindowEvent,
) -> Unit {
  let scale = match self.window {
    Some(window) => (window.scale_factor)()
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
/// Handle the `ApplicationHandler::window_event` slot body: transform the
/// cross-platform subset and route everything else back through
/// `dispatch_window_event`. `exit` is the platform event loop exit.
pub fn HostedWindowBackend::handle_window_event(
  self : HostedWindowBackend,
  event : @window_core.WindowEvent,
  exit~ : () -> Unit,
) -> Unit {
  let (scale_factor, surface_size) = match self.window {
    Some(window) => ((window.scale_factor)(), Some((window.inner_size)()))
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
      exit()
    }
    @platform_bridge.TransformedWindowEvent::DispatchHostEvent(host_event) =>
      self.dispatch_host_event(host_event)
    @platform_bridge.TransformedWindowEvent::WindowRedrawRequired => {
      self.dispatch_host_event(@host.HostEvent::RedrawRequested)
      match self.auto_exit_after_frames {
        Some(limit) => if self.frames_presented >= limit { exit() }
        None => ()
      }
    }
    _ => self.dispatch_window_event(event)
  }
}

///|
/// Body of the `ApplicationHandler::about_to_wait` slot: sync IME state and
/// pump any redraw requested by the session.
pub fn HostedWindowBackend::about_to_wait(self : HostedWindowBackend) -> Unit {
  self.sync_ime()
  self.pump_redraw_requested()
}

///|
/// Request a platform redraw for the hosted window, if one exists.
pub fn HostedWindowBackend::force_redraw(self : HostedWindowBackend) -> Unit {
  match self.window {
    Some(window) => (window.request_redraw)()
    None => ()
  }
}

///|
fn HostedWindowBackend::pump_redraw_requested(
  self : HostedWindowBackend,
) -> Unit {
  match self.session {
    Some(session) =>
      if session.take_redraw_requested() || session.redraw_requested() {
        match self.window {
          Some(window) => (window.request_redraw)()
          None => ()
        }
      }
    None => ()
  }
}

///|
fn HostedWindowBackend::sync_ime(self : HostedWindowBackend) -> Unit {
  match self.ime_sync {
    Some(sync) => sync(self.runtime)
    None => ()
  }
}
