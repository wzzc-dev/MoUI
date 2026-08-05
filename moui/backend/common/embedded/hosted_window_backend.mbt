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
  drop : () -> Unit
}

///|
pub fn HostedWindow::new(
  scale_factor~ : () -> Double,
  inner_size~ : () -> @dpi.PhysicalSize,
  request_redraw~ : () -> Unit,
  drop~ : () -> Unit,
) -> HostedWindow {
  { scale_factor, inner_size, request_redraw, drop }
}

///|
/// Neutral host-surface projection used by embedded platform backends.
/// Platform packages adapt their typed surface handles to this shape with
/// raw (`UInt64`) handles.
pub struct HostSurfaceBinding {
  create_renderer : (UInt64, @core.SurfaceMetrics) -> @render.RendererResolution?
  sync : (UInt64, @core.SurfaceMetrics) -> Unit
  image_loader : @render.ImageLoader?
}

///|
pub fn HostSurfaceBinding::new(
  create_renderer~ : (UInt64, @core.SurfaceMetrics) -> @render.RendererResolution?,
  sync~ : (UInt64, @core.SurfaceMetrics) -> Unit,
  image_loader? : @render.ImageLoader? = None,
) -> HostSurfaceBinding {
  { create_renderer, sync, image_loader }
}

///|
/// Assemble the renderer kit shared by Android, iOS, and HarmonyOS. Platform
/// packages provide only their native presenter and GPU descriptor wiring.
pub fn mobile_host_surface_binding(
  factories : Array[@render.RendererFactory],
  presenter_description~ : String,
  cpu_present~ : (UInt64, @render.PixelFrame) -> Bool,
  gpu_descriptor~ : (UInt64) -> @render.GpuHostSurfaceDescriptor?,
  sync? : (UInt64, @core.SurfaceMetrics) -> Unit = (_raw, _metrics) => (),
) -> HostSurfaceBinding {
  let image_source = @host_services_native.filesystem_image_source()
  HostSurfaceBinding::new(
    create_renderer=(raw_handle, metrics) => {
      let renderer_metrics = @core.SurfaceMetrics::new(
        logical_size=metrics.logical_size,
        physical_size=metrics.physical_size,
        scale_factor=metrics.scale_factor,
      )
      let present = @render.PresentTarget::new(
        description=presenter_description,
        present=frame => cpu_present(raw_handle, frame),
      )
      let gpu_surface = match gpu_descriptor(raw_handle) {
        Some(descriptor) =>
          Some(
            @render.HostGpuSurfaceBridge::new(
              descriptor~,
              create_surface=_ => None,
              present=_ => true,
            ),
          )
        None => None
      }
      @render_common.resolve_renderer(
        factories,
        @render.SurfaceContext::new(
          surface=@render.SurfaceDescriptor::cpu_raster(
            width=renderer_metrics.logical_size.width,
            height=renderer_metrics.logical_size.height,
            scale_factor=renderer_metrics.scale_factor,
          ),
          metrics=renderer_metrics,
          cpu_present=Some(present),
          gpu_surface~,
          image_source=Some(image_source),
        ),
      )
    },
    sync~,
  )
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
/// Create a session from a fresh surface handle and neutral host binding.
pub fn HostedRuntimeSession::create(
  runtime~ : @runtime.AppRuntime,
  raw_handle~ : UInt64,
  metrics~ : @core.SurfaceMetrics,
  binding~ : HostSurfaceBinding,
  surface_generation~ : Int,
  frame? : @window_host.FrameCoordinator? = None,
) -> HostedRuntimeSession? {
  match (binding.create_renderer)(raw_handle, metrics) {
    Some(resolution) => {
      let renderer = resolution.renderer()
      let core = EmbeddedRuntimeBackendCore::new(
        runtime~,
        renderer~,
        image_loader=preferred_image_loader(resolution.image_loader(), binding),
        metrics~,
        surface_generation~,
        frame~,
      )
      (binding.sync)(raw_handle, metrics)
      Some({ raw_handle, core })
    }
    None => None
  }
}

///|
pub fn HostedRuntimeSession::attach(
  self : HostedRuntimeSession,
  raw_handle~ : UInt64,
  metrics~ : @core.SurfaceMetrics,
  binding~ : HostSurfaceBinding,
  surface_generation~ : Int,
) -> Bool {
  match (binding.create_renderer)(raw_handle, metrics) {
    Some(resolution) => {
      let renderer = resolution.renderer()
      if self.core.attach_surface(
          renderer~,
          metrics~,
          surface_generation~,
          image_loader=preferred_image_loader(
            resolution.image_loader(),
            binding,
          ),
        ) {
        self.raw_handle = raw_handle
        (binding.sync)(raw_handle, metrics)
        true
      } else {
        false
      }
    }
    None => false
  }
}

///|
fn preferred_image_loader(
  resolved : @render.ImageLoader?,
  binding : HostSurfaceBinding,
) -> @render.ImageLoader? {
  match resolved {
    Some(loader) => Some(loader)
    None => binding.image_loader
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
) -> @core.SurfaceMetrics {
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
  event : @host.Event,
) -> @host.EventResult {
  self.core.dispatch(event)
}

///|
pub fn HostedRuntimeSession::resize(
  self : HostedRuntimeSession,
  metrics : @core.SurfaceMetrics,
) -> @host.EventResult {
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
) -> Array[EmbeddedHostUpdate] {
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
  response : EmbeddedHostResponse,
) -> Bool {
  self.core.dispatch_host_response(response)
}

///|
pub fn HostedRuntimeSession::dispatch_host_response_envelope(
  self : HostedRuntimeSession,
  envelope : EmbeddedHostResponseEnvelope,
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
  runtime_factory : (@core.SurfaceMetrics) -> @runtime.AppRuntime
  surface_binding_factory : () -> HostSurfaceBinding
  ime_sync : ((@runtime.AppRuntime?) -> Unit)?
  mut window : HostedWindow?
  mut runtime : @runtime.AppRuntime?
  mut session : HostedRuntimeSession?
  host : @window_host.EmbeddedWindowCoordinator
  redraw_target : Ref[(() -> Unit)?]
  mut last_pointer : @core.Point
  modifiers : @core.KeyModifiers
  mut frames_presented : Int
  auto_exit_after_frames : Int?
}

///|
pub fn HostedWindowBackend::new(
  title? : String = "MoUI",
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  surface_binding_factory~ : () -> HostSurfaceBinding,
  ime_sync? : ((@runtime.AppRuntime?) -> Unit)? = None,
  auto_exit_after_frames? : Int? = None,
) -> HostedWindowBackend {
  let redraw_target : Ref[(() -> Unit)?] = Ref(None)
  let host = @window_host.EmbeddedWindowCoordinator::new(
    hooks=@window_host.WindowFrameHooks::new(request_redraw=() => {
      match redraw_target.val {
        Some(request_redraw) => request_redraw()
        None => ()
      }
    }),
  )
  {
    title,
    runtime_factory,
    surface_binding_factory,
    ime_sync,
    window: None,
    runtime: None,
    session: None,
    host,
    redraw_target,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    frames_presented: 0,
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
  self.host.surface_generation()
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
/// Create and attach a platform window only when the shared surface state
/// needs one. Failed renderer negotiation drops the nominal native window so
/// a later surface callback can retry cleanly.
pub fn HostedWindowBackend::ensure_surface(
  self : HostedWindowBackend,
  create~ : () -> (HostedWindow, UInt64)?,
) -> Bool {
  if self.has_window() && self.session_attached() {
    return false
  }
  match create() {
    Some((window, raw_handle)) => self.attach_session(window, raw_handle~)
    None => false
  }
}

///|
/// Create or re-attach the runtime session for a freshly created window.
/// Called from the platform `can_create_surfaces` slot.
pub fn HostedWindowBackend::attach_session(
  self : HostedWindowBackend,
  window : HostedWindow,
  raw_handle~ : UInt64,
) -> Bool {
  let metrics = @window_host.make_surface_metrics(
    (window.inner_size)(),
    scale_factor=(window.scale_factor)(),
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
  let binding = (self.surface_binding_factory)()
  self.redraw_target.val = Some(window.request_redraw)
  ignore(self.host.attach_surface(raw_handle, metrics))
  let surface_generation = self.host.surface_generation()
  let attached = match self.session {
    Some(session) =>
      if session.attach(raw_handle~, metrics~, binding~, surface_generation~) {
        true
      } else {
        false
      }
    None =>
      match
        HostedRuntimeSession::create(
          runtime~,
          raw_handle~,
          metrics~,
          binding~,
          surface_generation~,
          frame=Some(self.host.frame()),
        ) {
        Some(session) => {
          self.session = Some(session)
          true
        }
        None => false
      }
  }
  if attached {
    self.window = Some(window)
    (window.request_redraw)()
  } else {
    self.redraw_target.val = None
    ignore(self.host.detach_surface())
    (window.drop)()
  }
  attached
}

///|
pub fn HostedWindowBackend::detach_session(self : HostedWindowBackend) -> Unit {
  match self.session {
    Some(session) => ignore(session.detach())
    None => ()
  }
  match self.window {
    Some(window) => (window.drop)()
    None => ()
  }
  self.window = None
  self.redraw_target.val = None
  ignore(self.host.detach_surface())
}

///|
pub fn HostedWindowBackend::destroy_surfaces(
  self : HostedWindowBackend,
) -> Unit {
  self.detach_session()
}

///|
pub fn HostedWindowBackend::suspended(self : HostedWindowBackend) -> Unit {
  self.destroy_surfaces()
  ignore(self.host.suspended())
}

///|
/// Forward the physical host's resumed callback to the MoUI logical owner.
pub fn HostedWindowBackend::resumed(self : HostedWindowBackend) -> Unit {
  ignore(self.host.resumed())
}

///|
/// Dispatch a host event into the session and drive requested redraws plus
/// the platform IME sync hook.
pub fn HostedWindowBackend::dispatch_host_event(
  self : HostedWindowBackend,
  host_event : @host.Event,
) -> Unit {
  match host_event {
    @host.Event::Pointer(pointer) => {
      match self.session {
        Some(session) => ignore(session.dispatch(host_event))
        None => ()
      }
      self.last_pointer = pointer.position
    }
    @host.Event::Resized(metrics) =>
      match self.session {
        Some(session) => {
          ignore(self.host.resize_surface(metrics))
          ignore(session.resize(metrics))
        }
        None => ()
      }
    @host.Event::RedrawRequested =>
      match self.session {
        Some(session) => {
          let result = session.render_frame()
          if result.presented {
            self.frames_presented = self.frames_presented + 1
          }
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
    @host.Event::Resized(_) | @host.Event::RedrawRequested => ()
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
    @window_host.window_event_to_host_with_modifiers(
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
    @window_host.transform_cross_platform_event(
      event,
      scale_factor~,
      surface_size~,
    ) {
    @window_host.TransformedWindowEvent::CloseRequested => {
      self.dispatch_host_event(@host.Event::CloseRequested)
      self.destroy_surfaces()
      ignore(self.host.request_exit(0))
      exit()
    }
    @window_host.TransformedWindowEvent::DispatchHostEvent(host_event) =>
      self.dispatch_host_event(host_event)
    @window_host.TransformedWindowEvent::WindowRedrawRequired => {
      self.dispatch_host_event(@host.Event::RedrawRequested)
      match self.auto_exit_after_frames {
        Some(limit) =>
          if self.frames_presented >= limit {
            self.destroy_surfaces()
            ignore(self.host.request_exit(0))
            exit()
          }
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
