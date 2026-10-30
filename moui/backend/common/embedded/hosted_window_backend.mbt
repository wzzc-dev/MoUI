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
  { scale_factor, inner_size, request_redraw, drop, }
}

///|
/// Neutral host-surface projection used by embedded platform backends.
/// Platform packages adapt their typed surface handles to this shape with
/// raw (`UInt64`) handles.
pub struct HostSurfaceBinding {
  create_renderer : (UInt64, @core.SurfaceMetrics) -> @render.RendererSession?
  sync : (UInt64, @core.SurfaceMetrics) -> Unit
}

///|
pub fn HostSurfaceBinding::new(
  create_renderer~ : (UInt64, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync~ : (UInt64, @core.SurfaceMetrics) -> Unit,
) -> HostSurfaceBinding {
  { create_renderer, sync, }
}

///|
/// Assemble the renderer-neutral host surface shared by Android, iOS, and
/// HarmonyOS. Platform packages provide only presenter and opaque handles.
pub fn mobile_host_surface_binding(
  providers : Array[@render.RendererProvider],
  presenter_description~ : String,
  cpu_present~ : (UInt64, @render.PixelFrame) -> Bool,
  native_surface~ : (UInt64) -> @render.NativeSurface?,
  sync~ : (UInt64, @core.SurfaceMetrics) -> Unit = (_raw, _metrics) => (),
) -> HostSurfaceBinding {
  let image_source = @host_image_native.filesystem_image_source()
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
      @render_common.resolve_renderer(
        providers,
        @render.HostSurface::new(
          metrics=renderer_metrics,
          cpu_present=Some(present),
          native_surface=native_surface(raw_handle),
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
  surface_generation~ : Int32,
  service_handler~ : (@host.HostServiceRequest) -> @host.HostServiceResponse? = _ => {
    None
  },
) -> HostedRuntimeSession? {
  match (binding.create_renderer)(raw_handle, metrics) {
    Some(resolution) => {
      let renderer = resolution
      let core = EmbeddedRuntimeBackendCore::new(
        runtime~,
        renderer~,
        metrics~,
        surface_generation~,
        service_handler~,
      )
      (binding.sync)(raw_handle, metrics)
      Some({ raw_handle, core, })
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
  surface_generation~ : Int32,
) -> Bool {
  match (binding.create_renderer)(raw_handle, metrics) {
    Some(resolution) => {
      let renderer = resolution
      if self.core.attach_surface(renderer~, metrics~, surface_generation~) {
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
) -> Int32 {
  self.core.session_generation()
}

///|
pub fn HostedRuntimeSession::surface_epoch(
  self : HostedRuntimeSession,
) -> Int32 {
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
pub fn HostedRuntimeSession::keyboard_command_intent(
  self : HostedRuntimeSession,
  event : @core.KeyboardEvent,
) -> @core.CommandIntent? {
  self.core.keyboard_command_intent(event)
}

///|
pub fn HostedRuntimeSession::drain_pending_service_requests(
  self : HostedRuntimeSession,
) -> Array[@host.HostPendingServiceRequest] {
  self.core.drain_pending_service_requests()
}

///|
pub fn HostedRuntimeSession::complete_service_request(
  self : HostedRuntimeSession,
  id : @host.HostServiceRequestId,
  response : @host.HostServiceResponse,
) -> Bool {
  self.core.complete_service_request(id, response)
}

///|
pub fn HostedRuntimeSession::image_resource_records(
  self : HostedRuntimeSession,
) -> Array[@render.ImageResourceRecord] {
  self.core.image_resource_records()
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
pub fn HostedRuntimeSession::present_count(
  self : HostedRuntimeSession,
) -> Int32 {
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
  /// Platform clipboard answer for synchronous host service requests.
  service_handler : (@host.HostServiceRequest) -> @host.HostServiceResponse?
  /// Monotonic milliseconds for frame timing. The runtime advances its animation
  /// clock from this on every presented frame; without it every animation stays
  /// latched in flight (a wheel settle never ends).
  clock_ms : () -> Double
  mut window : HostedWindow?
  mut runtime : @runtime.AppRuntime?
  mut session : HostedRuntimeSession?
  lifecycle : @window_lifecycle.EmbeddedLifecycle
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut frames_presented : Int32
  auto_exit_after_frames : Int32?
}

///|
pub fn HostedWindowBackend::new(
  title~ : String = "MoUI",
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  surface_binding_factory~ : () -> HostSurfaceBinding,
  ime_sync~ : ((@runtime.AppRuntime?) -> Unit)? = None,
  service_handler~ : (@host.HostServiceRequest) -> @host.HostServiceResponse? = _ => {
    None
  },
  clock_ms~ : () -> Double = () => 0.0,
  auto_exit_after_frames~ : Int32? = None,
) -> HostedWindowBackend {
  {
    title,
    runtime_factory,
    surface_binding_factory,
    ime_sync,
    service_handler,
    clock_ms,
    window: None,
    runtime: None,
    session: None,
    lifecycle: @window_lifecycle.EmbeddedLifecycle::new(),
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
pub fn HostedWindowBackend::frames_presented(
  self : HostedWindowBackend,
) -> Int32 {
  self.frames_presented
}

///|
pub fn HostedWindowBackend::surface_generation(
  self : HostedWindowBackend,
) -> Int32 {
  self.lifecycle.surface_generation()
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
/// Runs `f` against the live session. Used by platform backends that need to
/// reach the runtime for host-driven work (accessibility publishing) without
/// exposing the session field itself.
pub fn[T] HostedWindowBackend::with_session(
  self : HostedWindowBackend,
  f : (HostedRuntimeSession) -> T,
  default~ : T,
) -> T {
  match self.session {
    Some(session) => f(session)
    None => default
  }
}

///|
/// Reads the current semantics for accessibility publishing, or `None` when no
/// session is attached.
pub fn HostedWindowBackend::read_semantics(
  self : HostedWindowBackend,
) -> @runtime.SemanticsRead? {
  match self.session {
    Some(session) =>
      match session.runtime().read_semantics() {
        Ok(read) => Some(read)
        Err(_) => None
      }
    None => None
  }
}

///|
/// Current modifier state tracked from `ModifiersChanged`.
pub fn HostedWindowBackend::modifiers(
  self : HostedWindowBackend,
) -> @core.KeyModifiers {
  self.modifiers
}

///|
/// Whether a text control currently owns focus. Clipboard shortcuts need a
/// target; without one the runtime answers `ignored()` and nothing happens.
pub fn HostedWindowBackend::has_focused_text_input(
  self : HostedWindowBackend,
) -> Bool {
  match self.session {
    Some(session) => session.runtime().focused_text_input().focused
    None => false
  }
}

///|
/// The clipboard command a platform key event maps to, or `None`. Platform
/// diagnostics use this before dispatch; decoding happens here so callers do not
/// need the shared input package.
pub fn HostedWindowBackend::keyboard_command_intent_event(
  self : HostedWindowBackend,
  event : @window_core.KeyEvent,
) -> @core.CommandIntent? {
  match self.session {
    Some(session) =>
      session.keyboard_command_intent(
        @window_input.keyboard_event_to_core(event, self.modifiers),
      )
    None => None
  }
}

///|
/// Pending clipboard / platform-channel service requests from the attached
/// session. A platform with its own clipboard implementation drains these and
/// answers them, which is what makes Ctrl+C / Ctrl+V work on the embedded path.
pub fn HostedWindowBackend::drain_pending_service_requests(
  self : HostedWindowBackend,
) -> Array[@host.HostPendingServiceRequest] {
  match self.session {
    Some(session) => session.drain_pending_service_requests()
    None => []
  }
}

///|
/// Completes one pending service request with a platform answer.
pub fn HostedWindowBackend::complete_service_request(
  self : HostedWindowBackend,
  id : @host.HostServiceRequestId,
  response : @host.HostServiceResponse,
) -> Bool {
  match self.session {
    Some(session) => session.complete_service_request(id, response)
    None => false
  }
}

///|
/// Image resource records for the attached renderer. Empty when no session is
/// attached.
pub fn HostedWindowBackend::image_resource_records(
  self : HostedWindowBackend,
) -> Array[@render.ImageResourceRecord] {
  match self.session {
    Some(session) => session.image_resource_records()
    None => []
  }
}

///|
/// Dispatches a semantics action coming from the platform accessibility bridge.
/// Returns whether the runtime accepted it.
pub fn HostedWindowBackend::perform_semantics_action(
  self : HostedWindowBackend,
  request : @runtime.PerformSemanticsActionRequest,
) -> Bool {
  match self.session {
    Some(session) =>
      match session.runtime().perform_semantics_action(request) {
        Ok(_) => true
        Err(_) => false
      }
    None => false
  }
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
  let metrics = @window_input.make_surface_metrics(
    (window.inner_size)(),
    scale_factor=(window.scale_factor)(),
  )
  let runtime = match self.runtime {
    Some(runtime) => {
      runtime.dispatch_event(Resize(metrics.logical_size))
      runtime
    }
    None => {
      let runtime = (self.runtime_factory)(metrics)
      self.runtime = Some(runtime)
      runtime
    }
  }
  let binding = (self.surface_binding_factory)()
  ignore(self.lifecycle.attach_surface(raw_handle, metrics))
  let surface_generation = self.lifecycle.surface_generation()
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
          service_handler=self.service_handler,
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
    ignore(self.lifecycle.detach_surface())
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
  ignore(self.lifecycle.detach_surface())
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
  ignore(self.lifecycle.suspended())
}

///|
/// Forward the physical host's resumed callback to the MoUI logical owner.
pub fn HostedWindowBackend::resumed(self : HostedWindowBackend) -> Unit {
  ignore(self.lifecycle.resumed())
}

///|
/// Dispatch a host event into the session and drive requested redraws plus
/// the platform IME sync hook.
pub fn HostedWindowBackend::dispatch_host_event(
  self : HostedWindowBackend,
  host_event : @host.Event,
) -> Unit {
  match host_event {
    Pointer(pointer) => {
      match self.session {
        Some(session) => ignore(session.dispatch(host_event))
        None => ()
      }
      self.last_pointer = pointer.position
    }
    Resized(metrics) =>
      match self.session {
        Some(session) => {
          ignore(self.lifecycle.resize_surface(metrics))
          ignore(session.resize(metrics))
        }
        None => ()
      }
    RedrawRequested =>
      match self.session {
        Some(session) => {
          // Advance the animation clock before rendering. Paint reads
          // `environment.now_ms`, and a settle that never sees the clock move
          // stays latched: the surface crawls a few pixels then freezes until the
          // next event. Hosts that supply no clock keep the previous behaviour.
          let now = (self.clock_ms)()
          if now > 0.0 {
            session.advance_time(now)
          }
          let result = session.render_frame()
          if result.presented {
            self.frames_presented = self.frames_presented + 1
          }
          // Keep the animation clock moving. A control that reported
          // `animating` asked for another frame from inside the paint (through
          // `redraw_callback` -> transport), but that request only becomes a
          // window redraw when something pumps it — and between input events
          // nothing does. Without this the surface advances exactly one frame per
          // input event, which is the "stutters, then jumps" motion.
          //
          // The request is made even when this frame could not be submitted
          // (`result.queued` with `pending`): the previous frame is still in
          // flight, and dropping the follow-up there is what produced a visible
          // gap between animation steps.
          if session.redraw_requested() ||
            session.take_redraw_requested() ||
            result.queued {
            match self.window {
              Some(window) => (window.request_redraw)()
              None => ()
            }
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
    Resized(_) | RedrawRequested => ()
    _ => self.pump_redraw_requested()
  }
  self.sync_ime()
}

///|
/// Whether the runtime still owes a frame. The host loop uses this to keep
/// polling tight while a frame is outstanding and to idle-sleep otherwise —
/// without it a fixed sleep throttles every scroll glide to the sleep interval.
pub fn HostedWindowBackend::needs_redraw(self : HostedWindowBackend) -> Bool {
  match self.session {
    Some(session) => session.redraw_requested()
    None => false
  }
}

///|
/// Current window scale factor (physical pixels per logical pixel).
pub fn HostedWindowBackend::scale_factor(self : HostedWindowBackend) -> Double {
  match self.window {
    Some(window) => {
      let scale = (window.scale_factor)()
      if scale > 0.0 {
        scale
      } else {
        1.0
      }
    }
    None => 1.0
  }
}

///|
/// Dispatches a wheel event together with the pointer position that produced it.
///
/// `window-core`'s `MouseWheel` carries no position, and the wheel decode reads
/// `last_pointer`; without the position the scroll landed on whatever position
/// the previous pointer event left behind (on HarmonyOS: the last click). Taking
/// both in one call keeps the wheel path to a single dispatch instead of a
/// synthetic `PointerMoved` + `MouseWheel` pair, which halved the per-notch work
/// and removed the stutter.
pub fn HostedWindowBackend::dispatch_wheel(
  self : HostedWindowBackend,
  position : @core.Point,
  delta : @window_core.MouseScrollDelta,
) -> Unit {
  self.last_pointer = position
  self.dispatch_window_event(
    @window_core.WindowEvent::MouseWheel(
      None,
      delta,
      @window_core.TouchPhase::Moved,
    ),
  )
  // A wheel step changes what the scroll view paints, so a frame must be
  // requested. `pump_redraw_requested` alone is not enough: it only asks when the
  // transport already recorded a frame request, and a wheel dispatch updates the
  // runtime's dirty flags without going through `dispatch_host_event` (whose tail
  // pumps). Ask the window directly, which is what actually schedules the present.
  match self.window {
    Some(window) => (window.request_redraw)()
    None => ()
  }
  self.pump_redraw_requested()
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
  // Modifier state must be recorded before decoding the event that carries it:
  // `window_event_to_host_with_modifiers` reads `self.modifiers`, and shortcut
  // predicates in `moui/core` (Ctrl+A / Ctrl+C / Ctrl+V) only fire when the
  // decoded `KeyboardEvent.modifiers.control` is set. `ModifiersChanged` is
  // classified as platform-specific by the transformer, so without this the
  // stored state stayed `none()` for the whole session and every chord was
  // decoded as an unmodified key.
  match event {
    @window_core.WindowEvent::ModifiersChanged(next) =>
      self.modifiers = @window_input.modifiers_to_core(next)
    _ => ()
  }
  match
    @window_input.window_event_to_host_with_modifiers(
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
    @window_input.transform_cross_platform_event(
      event,
      scale_factor~,
      surface_size~,
    ) {
    CloseRequested => {
      self.dispatch_host_event(CloseRequested)
      self.destroy_surfaces()
      ignore(self.lifecycle.request_exit(0))
      exit()
    }
    DispatchHostEvent(host_event) => self.dispatch_host_event(host_event)
    WindowRedrawRequired => {
      self.dispatch_host_event(RedrawRequested)
      match self.auto_exit_after_frames {
        Some(limit) =>
          if self.frames_presented >= limit {
            self.destroy_surfaces()
            ignore(self.lifecycle.request_exit(0))
            exit()
          }
        None => ()
      }
    }
    _ => self.dispatch_window_event(event)
  }
}

///|
/// Handles a window event that carries its own pointer position.
///
/// `handle_window_event` routes `MouseWheel` through `dispatch_window_event`,
/// which reads `last_pointer`. Platforms whose wheel event carries the cursor
/// position (HarmonyOS axis events) call this instead so the position is applied
/// first, and only one dispatch happens per notch.
pub fn HostedWindowBackend::handle_window_event_at(
  self : HostedWindowBackend,
  event : @window_core.WindowEvent,
  position : @core.Point,
  exit~ : () -> Unit,
) -> Unit {
  match event {
    @window_core.WindowEvent::MouseWheel(_, delta, _) => {
      self.last_pointer = position
      self.dispatch_wheel(position, delta)
    }
    _ => self.handle_window_event(event, exit~)
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
