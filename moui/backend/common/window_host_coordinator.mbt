///|
/// Platform-window surface closure bundle (ADR 0020 convergence).
///
/// A platform adapter builds one `WindowSurfaceActions` per native window at
/// attach time and registers it on the `WindowCoordinator`. The closures
/// capture only the native window (and anything re-derivable from it); they
/// must not capture mutable slot state, because closures are constructed once
/// at attach time. State that changes after attach (Linux client decorations)
/// is re-derived inside the closure from the native window at call time.
pub struct WindowSurfaceActions {
  focus : () -> Unit
  /// Apply a requested content size and return the actual content metrics
  /// after platform adjustments such as Linux client-side decorations.
  request_resize : (@core.SurfaceMetrics) -> @core.SurfaceMetrics
  /// Sync an observed native surface resize and return its content metrics.
  sync_observed_resize : (@core.SurfaceMetrics) -> @core.SurfaceMetrics
  set_minimized : (Bool) -> Unit
  set_visible : (Bool) -> Unit
  request_redraw : () -> Unit
  /// Forward a decoded IME session action to the native window.
  request_ime_update : (TextInputSessionAction) -> Unit
  /// Release the native window (platform `drop`).
  drop : () -> Unit
  /// Extract the platform view handle used by `PlatformViewPlugin` disposal.
  native_view_handle : () -> UInt64?
  /// Dispose platform views hosted on this window through installed plugins.
  dispose_platform_views : () -> Unit
}

///|
pub fn WindowSurfaceActions::new(
  focus~ : () -> Unit,
  request_resize~ : (@core.SurfaceMetrics) -> @core.SurfaceMetrics,
  sync_observed_resize~ : (@core.SurfaceMetrics) -> @core.SurfaceMetrics,
  set_minimized~ : (Bool) -> Unit,
  set_visible~ : (Bool) -> Unit,
  request_redraw~ : () -> Unit,
  request_ime_update~ : (TextInputSessionAction) -> Unit,
  drop~ : () -> Unit,
  native_view_handle~ : () -> UInt64?,
  dispose_platform_views~ : () -> Unit,
) -> WindowSurfaceActions {
  {
    focus,
    request_resize,
    sync_observed_resize,
    set_minimized,
    set_visible,
    request_redraw,
    request_ime_update,
    drop,
    native_view_handle,
    dispose_platform_views,
  }
}

///|
/// Per-window runtime-coordinated state owned by `WindowCoordinator`.
struct CoordinatedSurface {
  host_id : @backend_host.WindowId
  renderer : @render.WindowRenderer
  image_loader : @render.ImageLoader?
  actions : WindowSurfaceActions
  frame : FrameCoordinator
}

///|
/// Platform-neutral window host coordinator (ADR 0018/0024).
///
/// Owns the window request queue, registry, runtime slots, platform window
/// map, per-surface frame coordinators, IME session, subscription sources,
/// services bridge, and async image loaders selected during renderer
/// negotiation. Platform adapters embed one coordinator and keep only native decode,
/// window creation, and frame production local.
pub struct WindowCoordinator {
  priv window_requests : @backend_host.WindowRequests
  priv scene_resolver : @runtime.WindowSceneResolver
  priv windows : WindowRegistry
  priv runtime_slots : WindowRuntimeSlots
  priv platform_windows : PlatformWindowMap
  priv event_sources : @runtime.HostPlatformEventSources?
  priv text_input_session : TextInputSession
  priv services : @backend_host.HostServiceBridge
  priv lifecycle : WindowLifecycleCore
  priv mut surface_generation : Int
  priv mut exit_intent : Int?
  priv mut surfaces : Array[CoordinatedSurface]
}

///|
pub fn WindowCoordinator::new(
  window_requests~ : @backend_host.WindowRequests,
  scene_resolver~ : @runtime.WindowSceneResolver,
  services~ : @backend_host.HostServiceBridge,
  event_sources~ : @runtime.HostPlatformEventSources?,
) -> WindowCoordinator {
  {
    window_requests,
    scene_resolver,
    windows: WindowRegistry::new(),
    runtime_slots: WindowRuntimeSlots::new(),
    platform_windows: PlatformWindowMap::new(),
    lifecycle: WindowLifecycleCore::new(),
    event_sources,
    text_input_session: TextInputSession::new(),
    services,
    surface_generation: 0,
    exit_intent: None,
    surfaces: [],
  }
}

///|
/// Bind one native platform id to one backend window id.
pub fn WindowCoordinator::bind_platform_window(
  self : WindowCoordinator,
  platform_id~ : @window_core.WindowId,
  window_id~ : @backend_host.WindowId,
) -> Bool {
  self.platform_windows.bind(platform_id~, host_id=window_id)
}

///|
/// Resolve a native callback id through the single coordinator-owned map.
pub fn WindowCoordinator::lookup_window(
  self : WindowCoordinator,
  platform_id : @window_core.WindowId,
) -> @backend_host.WindowId? {
  self.platform_windows.lookup_host(platform_id)
}

///|
/// Remove the native mapping as part of the coordinator teardown effect.
pub fn WindowCoordinator::unbind_platform_window(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> @window_core.WindowId? {
  self.platform_windows.remove_host(window_id)
}

///|
pub fn WindowCoordinator::services(
  self : WindowCoordinator,
) -> @backend_host.HostServiceBridge {
  self.services
}

///|
/// Access the coordinator-owned application window registry.
pub fn WindowCoordinator::window_registry(
  self : WindowCoordinator,
) -> WindowRegistry {
  self.windows
}

///|
/// Access runtime slots through the coordinator rather than its fields.
pub fn WindowCoordinator::runtime_slots(
  self : WindowCoordinator,
) -> WindowRuntimeSlots {
  self.runtime_slots
}

///|
/// Read the last IME diagnostics without exposing the session owner.
pub fn WindowCoordinator::text_input_diagnostics(
  self : WindowCoordinator,
) -> TextInputImeRequestDiagnostics? {
  self.text_input_session.last_diagnostics()
}

///|
pub fn WindowCoordinator::attach_surface(
  self : WindowCoordinator,
  host_id : @backend_host.WindowId,
  renderer : @render.WindowRenderer,
  actions : WindowSurfaceActions,
  image_loader? : @render.ImageLoader? = None,
) -> Bool {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      renderer.dispose()
      return false
    }
  }
  self.surface_generation = self.surface_generation + 1
  let frame = FrameCoordinator::new(
    hooks=WindowFrameHooks::new(request_redraw=actions.request_redraw),
  )
  frame.attach_image_resources(to_render_id(host_id), renderer, image_loader)
  self.surfaces.push({ host_id, renderer, image_loader, actions, frame })
  true
}

///|
pub fn WindowCoordinator::detach_surface(
  self : WindowCoordinator,
  host_id : @backend_host.WindowId,
) -> WindowSurfaceActions? {
  let mut removed = None
  let kept = []
  for surface in self.surfaces {
    if surface.host_id == host_id {
      surface.frame.dispose_image_resources()
      removed = Some(surface.actions)
    } else {
      kept.push(surface)
    }
  }
  self.surfaces = kept
  if removed is Some(_) {
    self.surface_generation = self.surface_generation + 1
  }
  removed
}

///|
pub fn WindowCoordinator::surface_generation(self : WindowCoordinator) -> Int {
  self.surface_generation
}

///|
pub fn WindowCoordinator::request_exit(
  self : WindowCoordinator,
  code : Int,
) -> Unit {
  self.exit_intent = Some(code)
}

///|
pub fn WindowCoordinator::exit_intent(self : WindowCoordinator) -> Int? {
  self.exit_intent
}

///|
pub fn WindowCoordinator::surface_actions(
  self : WindowCoordinator,
  host_id : @backend_host.WindowId,
) -> WindowSurfaceActions? {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return Some(surface.actions)
    }
  }
  None
}

///|
pub fn WindowCoordinator::surface_renderer(
  self : WindowCoordinator,
  host_id : @backend_host.WindowId,
) -> @render.WindowRenderer? {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return Some(surface.renderer)
    }
  }
  None
}

///|
pub fn WindowCoordinator::surface_frame_pending(
  self : WindowCoordinator,
  host_id : @backend_host.WindowId,
) -> Bool {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return surface.frame.pending()
    }
  }
  false
}

///|
fn WindowCoordinator::surface_frame(
  self : WindowCoordinator,
  host_id : @backend_host.WindowId,
) -> FrameCoordinator? {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return Some(surface.frame)
    }
  }
  None
}

///|
pub fn WindowCoordinator::runtime_slots_empty(self : WindowCoordinator) -> Bool {
  self.runtime_slots.is_empty()
}

///|
pub fn WindowCoordinator::runtime_slot_lookup(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> WindowRuntimeSlot? {
  self.runtime_slots.lookup(window_id)
}

///|
pub fn WindowCoordinator::open_resolution(
  self : WindowCoordinator,
  request : @backend_host.WindowOpenRequest,
) -> @runtime.WindowOpenResolution {
  resolve_open_request(self.windows, request, self.scene_resolver)
}

///|
pub fn WindowCoordinator::dispatch_host_event(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  host_event : @backend_host.Event,
  adjust~ : (@backend_host.Event) -> @backend_host.Event?,
) -> Unit {
  match adjust(host_event) {
    Some(adjusted) => {
      ignore(
        self.runtime_slots.apply_host_event(self.windows, window_id, adjusted),
      )
      match self.runtime_slots.lookup(window_id) {
        Some(slot) =>
          match adjusted {
            @backend_host.Event::Keyboard(event) =>
              ignore(
                slot.driver.dispatch_keyboard_with_services(
                  event,
                  self.services,
                ),
              )
            _ => ignore(slot.driver.dispatch(adjusted))
          }
        None => ()
      }
      ignore(self.publish_subscription_event(window_id, adjusted))
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn WindowCoordinator::publish_subscription_event(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  event : @backend_host.Event,
) -> @runtime.HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
  }
}

///|
pub fn WindowCoordinator::publish_platform_event(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  event : @backend_host.Event,
) -> @runtime.HostPlatformEventPublishResult? {
  self.publish_subscription_event(window_id, event)
}

///|
pub fn WindowCoordinator::active_runtime_slot(
  self : WindowCoordinator,
) -> WindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
pub fn WindowCoordinator::sync_text_input_session(
  self : WindowCoordinator,
) -> Unit {
  match self.active_runtime_slot() {
    Some(runtime_slot) =>
      match self.surface_actions(runtime_slot.id) {
        Some(actions) =>
          match
            self.text_input_session.sync(
              runtime_slot.driver.focused_text_input(),
            ) {
            action =>
              match action {
                TextInputSessionAction::NoImeChange => ()
                _ => (actions.request_ime_update)(action)
              }
          }
        None => ()
      }
    None => ()
  }
}

///|
pub fn WindowCoordinator::drain_window_requests(
  self : WindowCoordinator,
  apply : (@backend_host.WindowRequest) -> @backend_host.WindowRequestResult,
) -> Unit {
  ignore(self.window_requests.drain_with_handler(apply))
}

///|
pub fn WindowCoordinator::apply_window_request(
  self : WindowCoordinator,
  request : @backend_host.WindowRequest,
  open_window~ : (@backend_host.WindowOpenRequest) -> @backend_host.WindowRequestResult,
  dispose_window? : (@backend_host.WindowId) -> Unit = _window_id => (),
  exit~ : () -> Unit,
) -> @backend_host.WindowRequestResult {
  match request {
    @backend_host.WindowRequest::OpenWindow(open_request) =>
      open_window(open_request)
    @backend_host.WindowRequest::FocusWindow(id) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.focus)()
      })
    @backend_host.WindowRequest::CloseWindow(id) =>
      self.apply_platform_window_request(id, request, _actions => {
        dispose_window(id)
        if self.runtime_slots.is_empty() {
          exit()
        }
      })
    @backend_host.WindowRequest::ResizeWindow(id, metrics) =>
      self.apply_platform_window_request(id, request, actions => {
        let applied_metrics = (actions.request_resize)(metrics)
        self.dispatch_host_event(
          id,
          @backend_host.Event::Resized(applied_metrics),
          adjust=event => Some(event),
        )
        (actions.request_redraw)()
      })
    @backend_host.WindowRequest::MinimizeWindow(id) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.set_minimized)(true)
      })
    @backend_host.WindowRequest::ShowWindow(id) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.set_minimized)(false)
        (actions.set_visible)(true)
      })
    @backend_host.WindowRequest::SetPrimaryWindow(id) =>
      self.apply_platform_window_request(id, request, _actions => ())
  }
}

///|
/// Sync a native resize through the registered platform projection. The
/// returned value is in content coordinates and is ready for Event::Resized.
pub fn WindowCoordinator::sync_observed_resize(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  surface_metrics : @core.SurfaceMetrics,
) -> @core.SurfaceMetrics? {
  match self.surface_actions(window_id) {
    Some(actions) => {
      let content_metrics = (actions.sync_observed_resize)(surface_metrics)
      self.dispatch_host_event(
        window_id,
        @backend_host.Event::Resized(content_metrics),
        adjust=event => Some(event),
      )
      (actions.request_redraw)()
      Some(content_metrics)
    }
    None => None
  }
}

///|
/// Run the platform-neutral redraw state machine for one hosted window.
///
/// The platform closure owns only native composition and presentation. Frame
/// completion, pending-frame retry, runtime driver transitions, image resource
/// tracking, IME synchronization, and follow-up redraw scheduling remain here.
pub fn WindowCoordinator::run_window_redraw(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  render~ : (@render.WindowRenderer, WindowRuntimeSlot, @core.DrawFrame) -> @render.RenderFrameResult,
  finish_presented? : (WindowRuntimeSlot) -> Bool = _slot => false,
) -> Bool {
  match
    (
      self.runtime_slots.lookup(window_id),
      self.surface_renderer(window_id),
      self.surface_frame(window_id),
    ) {
    (Some(runtime_slot), Some(renderer), Some(frame_state)) => {
      let prior_completions = renderer.drain_present_completions()
      let prior_presented = @render.render_present_completions_have_presented(
        prior_completions,
      )
      let prior_terminal = @render.render_present_completions_have_terminal(
        prior_completions,
      )
      if frame_state.pending() {
        ignore(
          frame_state.finish_presented(true, prior_terminal, prior_presented),
        )
        if frame_state.pending() {
          return false
        }
        if prior_presented {
          self.finish_frame_resources(window_id, renderer, presented=true)
          if finish_presented(runtime_slot) {
            return true
          }
          if !runtime_slot_needs_redraw(runtime_slot) {
            return false
          }
        }
      }

      if !frame_state.prepare_frame() {
        return false
      }

      runtime_slot.driver.begin_redraw()
      let frame = runtime_slot.driver.draw_frame()
      let result = render(renderer, runtime_slot, frame)
      let present_completions = renderer.drain_present_completions()
      runtime_slot.driver.apply_render_frame_result(result)
      runtime_slot.driver.finish_redraw()

      let completion_presented = @render.render_present_completions_have_presented(
        present_completions,
      )
      let completion_terminal = @render.render_present_completions_have_terminal(
        present_completions,
      )
      let presented = completion_presented ||
        (present_completions.is_empty() && result.presented)
      ignore(
        frame_state.finish_presented(
          result.queued,
          completion_terminal,
          presented,
        ),
      )
      self.finish_frame_resources(window_id, renderer, presented~)
      if presented && finish_presented(runtime_slot) {
        true
      } else {
        false
      }
    }
    _ => false
  }
}

///|
fn WindowCoordinator::finish_frame_resources(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  renderer : @render.WindowRenderer,
  presented~ : Bool,
) -> Unit {
  match self.surface_frame(window_id) {
    Some(frame) =>
      ignore(frame.finish_image_frame(renderer.present_count(), presented~))
    None => ()
  }
  self.sync_text_input_session()
}

///|
pub fn WindowCoordinator::apply_platform_window_request(
  self : WindowCoordinator,
  id : @backend_host.WindowId,
  request : @backend_host.WindowRequest,
  apply : (WindowSurfaceActions) -> Unit,
) -> @backend_host.WindowRequestResult {
  match self.surface_actions(id) {
    Some(actions) => {
      let result = self.runtime_slots.apply_request(self.windows, request)
      match result {
        @backend_host.WindowRequestResult::WindowRejected(_) => ()
        _ => apply(actions)
      }
      result
    }
    None =>
      @backend_host.WindowRequestResult::WindowRejected(
        "window request has no active platform window",
      )
  }
}

///|
pub fn WindowCoordinator::request_redraw(self : WindowCoordinator) -> Unit {
  match self.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
pub fn WindowCoordinator::request_redraw_window_if_needed(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Unit {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) => {
      let image_redraw_requested = self.request_image_resource_redraw_if_changed(
        window_id,
      )
      if runtime_slot_needs_redraw(slot) && !image_redraw_requested {
        self.request_platform_redraw(window_id)
      }
    }
    None => ()
  }
}

///|
pub fn WindowCoordinator::request_image_resource_redraw_if_changed(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Bool {
  match
    (self.surface_renderer(window_id), self.runtime_slots.lookup(window_id)) {
    (Some(_renderer), Some(runtime_slot)) => {
      guard runtime_slot.record.phase !=
        @backend_host.WindowLifecyclePhase::WindowClosed else {
        return false
      }
      match self.surface_frame(window_id) {
        Some(frame) => frame.request_image_redraw_if_changed()
        None => false
      }
    }
    (Some(_renderer), None) => false
    _ => false
  }
}

///|
pub fn WindowCoordinator::bind_renderer_image_resource_changes(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Unit {
  match self.surface_frame(window_id) {
    Some(frame) => frame.bind_image_resource_changes()
    None => ()
  }
}

///|
pub fn WindowCoordinator::request_platform_redraw(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Unit {
  match self.surface_actions(window_id) {
    Some(actions) => (actions.request_redraw)()
    None => ()
  }
}

///|
pub fn WindowCoordinator::schedule_image_resource_loads(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  renderer : @render.WindowRenderer,
  completion_source : @render_common.ImageResourceCompletionSource,
) -> @render.ImageLoadScheduleResult? {
  match self.surface_image_loader(window_id) {
    Some(loader) =>
      Some(
        loader.schedule_loading_resources(to_render_id(window_id), renderer, complete=(
          id,
          target,
          completion,
        ) => ignore(completion_source.complete(id, target, completion))),
      )
    None => None
  }
}

///|
pub fn WindowCoordinator::cancel_image_resource_loads(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Int {
  match self.surface_frame(window_id) {
    Some(frame) => frame.cancel_image_resources()
    None => 0
  }
}

///|
fn WindowCoordinator::surface_image_loader(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> @render.ImageLoader? {
  for surface in self.surfaces {
    if surface.host_id == window_id {
      return surface.image_loader
    }
  }
  None
}

///|
pub fn WindowCoordinator::register_primary_runtime_slot(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
  driver : @runtime.HostRuntimeDriver,
) -> Unit {
  match self.windows.lookup(window_id) {
    Some(record) =>
      ignore(
        self.register_runtime_slot(
          WindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
    None => ()
  }
}

///|
/// Atomically register the lifecycle owner and runtime slot.
pub fn WindowCoordinator::register_runtime_slot(
  self : WindowCoordinator,
  slot : WindowRuntimeSlot,
) -> Bool {
  if !self.lifecycle.register(slot.id) {
    return false
  }
  if self.runtime_slots.insert(slot) {
    true
  } else {
    ignore(self.lifecycle.rollback(slot.id))
    false
  }
}

///|
pub fn WindowCoordinator::sync_runtime_slot(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, window_id))
}

///|
pub fn WindowCoordinator::sync_runtime_slots(self : WindowCoordinator) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}

///|
pub fn WindowCoordinator::dispose_window(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Unit {
  guard self.lifecycle.begin_close(window_id) else { return }
  ignore(self.windows.close(window_id))
  self.sync_runtime_slot(window_id)
  ignore(self.runtime_slots.remove(window_id))
  ignore(self.unbind_platform_window(window_id))
  let renderer = self.surface_renderer(window_id)
  match self.detach_surface(window_id) {
    Some(actions) => {
      match renderer {
        Some(renderer) => {
          renderer.set_image_resource_change_callback(None)
          renderer.dispose()
        }
        None => ()
      }
      (actions.dispose_platform_views)()
      (actions.drop)()
    }
    None => ()
  }
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
  ignore(self.lifecycle.finish_close(window_id))
}

///|
pub fn WindowCoordinator::rollback_window_record(
  self : WindowCoordinator,
  window_id : @backend_host.WindowId,
) -> Unit {
  ignore(self.lifecycle.rollback(window_id))
  ignore(self.unbind_platform_window(window_id))
  ignore(self.windows.close(window_id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
pub fn runtime_slot_needs_redraw(slot : WindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
pub fn to_host_id(render_id : @render.RenderWindowId) -> @backend_host.WindowId {
  @backend_host.WindowId::new(render_id.value)
}

///|
pub fn to_render_id(
  window_id : @backend_host.WindowId,
) -> @render.RenderWindowId {
  @render.RenderWindowId::new(window_id.value)
}

///|
pub fn to_render_metrics(
  metrics : @core.SurfaceMetrics,
) -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}
