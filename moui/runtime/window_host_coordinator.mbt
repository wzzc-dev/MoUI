///|
/// Platform-window surface closure bundle (ADR 0020 convergence).
///
/// A platform adapter builds one `WindowSurfaceActions` per native window at
/// attach time and registers it on the `WindowHostCoordinator`. The closures
/// capture only the native window (and anything re-derivable from it); they
/// must not capture mutable slot state, because closures are constructed once
/// at attach time. State that changes after attach (Linux client decorations)
/// is re-derived inside the closure from the native window at call time.
pub struct WindowSurfaceActions {
  focus : () -> Unit
  /// Request the native surface size for a host metrics request. The platform
  /// converts to native dpi inside the closure.
  request_surface_size : (@backend_host.HostSurfaceMetrics) -> Unit
  /// Sync the platform renderer surface (GPU swapchain / EGL / offscreen)
  /// against a host metrics value.
  sync_surface : (@backend_host.HostSurfaceMetrics) -> Unit
  /// Resize the platform renderer's window buffer.
  renderer_resize : (@render.RendererSurfaceMetrics) -> Unit
  set_minimized : (Bool) -> Unit
  set_visible : (Bool) -> Unit
  request_redraw : () -> Unit
  /// Forward a decoded IME session action to the native window.
  request_ime_update : (@backend_host.TextInputSessionAction) -> Unit
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
  request_surface_size~ : (@backend_host.HostSurfaceMetrics) -> Unit,
  sync_surface~ : (@backend_host.HostSurfaceMetrics) -> Unit,
  renderer_resize~ : (@render.RendererSurfaceMetrics) -> Unit,
  set_minimized~ : (Bool) -> Unit,
  set_visible~ : (Bool) -> Unit,
  request_redraw~ : () -> Unit,
  request_ime_update~ : (@backend_host.TextInputSessionAction) -> Unit,
  drop~ : () -> Unit,
  native_view_handle~ : () -> UInt64?,
  dispose_platform_views~ : () -> Unit,
) -> WindowSurfaceActions {
  {
    focus,
    request_surface_size,
    sync_surface,
    renderer_resize,
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
/// Per-window runtime-coordinated state owned by `WindowHostCoordinator`.
struct CoordinatedSurface {
  host_id : @backend_host.HostWindowId
  renderer : @render.HostWindowRenderer
  image_loader : @render.HostAsyncImageLoader?
  actions : WindowSurfaceActions
  mut frame_pending : Bool
}

///|
/// Platform-neutral window host coordinator (ADR 0018/0020).
///
/// Owns the window request queue, registry, runtime slots, platform window
/// map, image repaint tracker, IME session, subscription sources, services
/// bridge, and per-surface async image loaders selected during renderer
/// negotiation. Platform adapters embed one coordinator and keep only native decode,
/// window creation, and frame production local.
pub struct WindowHostCoordinator {
  window_requests : @backend_host.HostWindowRequestQueue
  scene_resolver : HostWindowSceneResolver
  windows : @backend_host.HostWindowRegistry
  runtime_slots : HostWindowRuntimeSlots
  platform_windows : @backend_host.HostPlatformWindowMap
  image_repaint_tracker : @render.HostImageResourceRepaintTracker
  event_sources : HostPlatformEventSources?
  text_input_session : @backend_host.TextInputSession
  services : @backend_host.HostServiceBridge
  mut surfaces : Array[CoordinatedSurface]
}

///|
pub fn WindowHostCoordinator::new(
  window_requests~ : @backend_host.HostWindowRequestQueue,
  scene_resolver~ : HostWindowSceneResolver,
  services~ : @backend_host.HostServiceBridge,
  event_sources~ : HostPlatformEventSources?,
) -> WindowHostCoordinator {
  {
    window_requests,
    scene_resolver,
    windows: @backend_host.HostWindowRegistry::new(),
    runtime_slots: HostWindowRuntimeSlots::new(),
    platform_windows: @backend_host.HostPlatformWindowMap::new(),
    image_repaint_tracker: @render.HostImageResourceRepaintTracker::new(),
    event_sources,
    text_input_session: @backend_host.TextInputSession::new(),
    services,
    surfaces: [],
  }
}

///|
pub fn WindowHostCoordinator::services(
  self : WindowHostCoordinator,
) -> @backend_host.HostServiceBridge {
  self.services
}

///|
pub fn WindowHostCoordinator::attach_surface(
  self : WindowHostCoordinator,
  host_id : @backend_host.HostWindowId,
  renderer : @render.HostWindowRenderer,
  actions : WindowSurfaceActions,
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> Bool {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return false
    }
  }
  self.surfaces.push({
    host_id,
    renderer,
    image_loader,
    actions,
    frame_pending: false,
  })
  true
}

///|
pub fn WindowHostCoordinator::detach_surface(
  self : WindowHostCoordinator,
  host_id : @backend_host.HostWindowId,
) -> WindowSurfaceActions? {
  let mut removed = None
  let kept = []
  for surface in self.surfaces {
    if surface.host_id == host_id {
      removed = Some(surface.actions)
    } else {
      kept.push(surface)
    }
  }
  self.surfaces = kept
  removed
}

///|
pub fn WindowHostCoordinator::surface_actions(
  self : WindowHostCoordinator,
  host_id : @backend_host.HostWindowId,
) -> WindowSurfaceActions? {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return Some(surface.actions)
    }
  }
  None
}

///|
pub fn WindowHostCoordinator::surface_renderer(
  self : WindowHostCoordinator,
  host_id : @backend_host.HostWindowId,
) -> @render.HostWindowRenderer? {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return Some(surface.renderer)
    }
  }
  None
}

///|
pub fn WindowHostCoordinator::surface_frame_pending(
  self : WindowHostCoordinator,
  host_id : @backend_host.HostWindowId,
) -> Bool {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      return surface.frame_pending
    }
  }
  false
}

///|
pub fn WindowHostCoordinator::set_surface_frame_pending(
  self : WindowHostCoordinator,
  host_id : @backend_host.HostWindowId,
  pending : Bool,
) -> Unit {
  for surface in self.surfaces {
    if surface.host_id == host_id {
      surface.frame_pending = pending
      return ()
    }
  }
}

///|
pub fn WindowHostCoordinator::runtime_slots_empty(
  self : WindowHostCoordinator,
) -> Bool {
  self.runtime_slots.is_empty()
}

///|
pub fn WindowHostCoordinator::runtime_slot_lookup(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> HostWindowRuntimeSlot? {
  self.runtime_slots.lookup(window_id)
}

///|
pub fn WindowHostCoordinator::open_resolution(
  self : WindowHostCoordinator,
  request : @backend_host.HostWindowOpenRequest,
) -> HostWindowOpenResolution {
  resolve_open_request(self.windows, request, self.scene_resolver)
}

///|
pub fn WindowHostCoordinator::dispatch_host_event(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
  host_event : @backend_host.HostEvent,
  adjust~ : (@backend_host.HostEvent) -> @backend_host.HostEvent?,
) -> Unit {
  match adjust(host_event) {
    Some(adjusted) => {
      ignore(
        self.runtime_slots.apply_host_event(self.windows, window_id, adjusted),
      )
      match self.runtime_slots.lookup(window_id) {
        Some(slot) =>
          match adjusted {
            @backend_host.HostEvent::Keyboard(event) =>
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
fn WindowHostCoordinator::publish_subscription_event(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
  event : @backend_host.HostEvent,
) -> HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
  }
}

///|
pub fn WindowHostCoordinator::publish_platform_event(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
  event : @backend_host.HostEvent,
) -> HostPlatformEventPublishResult? {
  self.publish_subscription_event(window_id, event)
}

///|
pub fn WindowHostCoordinator::active_runtime_slot(
  self : WindowHostCoordinator,
) -> HostWindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
pub fn WindowHostCoordinator::sync_text_input_session(
  self : WindowHostCoordinator,
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
                @backend_host.TextInputSessionAction::NoImeChange => ()
                _ => (actions.request_ime_update)(action)
              }
          }
        None => ()
      }
    None => ()
  }
}

///|
pub fn WindowHostCoordinator::drain_window_requests(
  self : WindowHostCoordinator,
  apply : (@backend_host.HostWindowRequest) -> @backend_host.HostWindowRequestResult,
) -> Unit {
  ignore(self.window_requests.drain_with_handler(apply))
}

///|
pub fn WindowHostCoordinator::apply_window_request(
  self : WindowHostCoordinator,
  request : @backend_host.HostWindowRequest,
  open_window~ : (@backend_host.HostWindowOpenRequest) -> @backend_host.HostWindowRequestResult,
  dispose_window? : (@backend_host.HostWindowId) -> Unit = _window_id => (),
  exit~ : () -> Unit,
) -> @backend_host.HostWindowRequestResult {
  match request {
    @backend_host.HostWindowRequest::OpenWindow(open_request) =>
      open_window(open_request)
    @backend_host.HostWindowRequest::FocusWindow(id) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.focus)()
      })
    @backend_host.HostWindowRequest::CloseWindow(id) =>
      self.apply_platform_window_request(id, request, _actions => {
        dispose_window(id)
        if self.runtime_slots.is_empty() {
          exit()
        }
      })
    @backend_host.HostWindowRequest::ResizeWindow(id, metrics) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.request_surface_size)(metrics)
        (actions.sync_surface)(metrics)
        (actions.renderer_resize)(to_render_metrics(metrics))
        (actions.request_redraw)()
      })
    @backend_host.HostWindowRequest::MinimizeWindow(id) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.set_minimized)(true)
      })
    @backend_host.HostWindowRequest::ShowWindow(id) =>
      self.apply_platform_window_request(id, request, actions => {
        (actions.set_minimized)(false)
        (actions.set_visible)(true)
      })
    @backend_host.HostWindowRequest::SetPrimaryWindow(id) =>
      self.apply_platform_window_request(id, request, _actions => ())
  }
}

///|
pub fn WindowHostCoordinator::apply_platform_window_request(
  self : WindowHostCoordinator,
  id : @backend_host.HostWindowId,
  request : @backend_host.HostWindowRequest,
  apply : (WindowSurfaceActions) -> Unit,
) -> @backend_host.HostWindowRequestResult {
  match self.surface_actions(id) {
    Some(actions) => {
      let result = self.runtime_slots.apply_request(self.windows, request)
      match result {
        @backend_host.HostWindowRequestResult::WindowRejected(_) => ()
        _ => apply(actions)
      }
      result
    }
    None =>
      @backend_host.HostWindowRequestResult::WindowRejected(
        "window request has no active platform window",
      )
  }
}

///|
pub fn WindowHostCoordinator::request_redraw(
  self : WindowHostCoordinator,
) -> Unit {
  match self.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
pub fn WindowHostCoordinator::request_redraw_window_if_needed(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
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
pub fn WindowHostCoordinator::request_image_resource_redraw_if_changed(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Bool {
  match
    (self.surface_renderer(window_id), self.runtime_slots.lookup(window_id)) {
    (Some(renderer), Some(runtime_slot)) => {
      let render_id = to_render_id(window_id)
      let result = self.image_repaint_tracker.request_redraw_if_changed(
        render_id,
        renderer,
        window_open=runtime_slot.record.phase !=
          @backend_host.HostWindowLifecyclePhase::WindowClosed,
        request_redraw=id => self.request_platform_redraw(to_host_id(id)),
      )
      result.status() ==
      @render.HostImageResourceRepaintStatus::ImageRepaintRequested
    }
    (Some(renderer), None) => {
      ignore(
        self.image_repaint_tracker.request_redraw_if_changed(
          to_render_id(window_id),
          renderer,
          window_open=false,
          request_redraw=_id => (),
        ),
      )
      false
    }
    _ => false
  }
}

///|
pub fn WindowHostCoordinator::bind_renderer_image_resource_changes(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Unit {
  match self.surface_renderer(window_id) {
    Some(renderer) =>
      renderer.set_image_resource_change_callback(
        Some(snapshot => {
          match
            self.image_repaint_tracker.revision_for(to_render_id(window_id)) {
            Some(_) =>
              match self.runtime_slots.lookup(window_id) {
                Some(runtime_slot) =>
                  ignore(
                    self.image_repaint_tracker.request_redraw_for_snapshot_if_changed(
                      to_render_id(window_id),
                      snapshot,
                      window_open=runtime_slot.record.phase !=
                        @backend_host.HostWindowLifecyclePhase::WindowClosed,
                      request_redraw=id => {
                        self.request_platform_redraw(to_host_id(id))
                      },
                    ),
                  )
                None =>
                  ignore(
                    self.image_repaint_tracker.request_redraw_for_snapshot_if_changed(
                      to_render_id(window_id),
                      snapshot,
                      window_open=false,
                      request_redraw=_id => (),
                    ),
                  )
              }
            None => ()
          }
        }),
      )
    None => ()
  }
}

///|
pub fn WindowHostCoordinator::request_platform_redraw(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Unit {
  match self.surface_actions(window_id) {
    Some(actions) => (actions.request_redraw)()
    None => ()
  }
}

///|
pub fn WindowHostCoordinator::image_resource_completion_source(
  self : WindowHostCoordinator,
) -> @render.HostImageResourceCompletionSource {
  @render.HostImageResourceCompletionSource::new(
    tracker=self.image_repaint_tracker,
    window_open=id => self.image_resource_window_open(to_host_id(id)),
    request_redraw=id => self.request_platform_redraw(to_host_id(id)),
  )
}

///|
pub fn WindowHostCoordinator::image_resource_window_open(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Bool {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) =>
      slot.record.phase != @backend_host.HostWindowLifecyclePhase::WindowClosed
    None => false
  }
}

///|
pub fn WindowHostCoordinator::schedule_image_resource_loads(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
  renderer : @render.HostWindowRenderer,
  completion_source : @render.HostImageResourceCompletionSource,
) -> @render.HostAsyncImageLoadScheduleResult? {
  match self.surface_image_loader(window_id) {
    Some(loader) =>
      Some(
        loader.schedule_loading_resources(
          to_render_id(window_id),
          renderer,
          completion_source,
        ),
      )
    None => None
  }
}

///|
pub fn WindowHostCoordinator::cancel_image_resource_loads(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Int {
  match self.surface_image_loader(window_id) {
    Some(loader) => loader.cancel_window(to_render_id(window_id))
    None => 0
  }
}

///|
fn WindowHostCoordinator::surface_image_loader(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> @render.HostAsyncImageLoader? {
  for surface in self.surfaces {
    if surface.host_id == window_id {
      return surface.image_loader
    }
  }
  None
}

///|
pub fn WindowHostCoordinator::register_primary_runtime_slot(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
  driver : HostRuntimeDriver,
) -> Unit {
  ignore(
    self.runtime_slots.insert_from_registry(self.windows, window_id, driver~),
  )
}

///|
pub fn WindowHostCoordinator::sync_runtime_slot(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, window_id))
}

///|
pub fn WindowHostCoordinator::sync_runtime_slots(
  self : WindowHostCoordinator,
) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}

///|
pub fn WindowHostCoordinator::dispose_window(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  self.sync_runtime_slot(window_id)
  ignore(self.image_repaint_tracker.remove_window(to_render_id(window_id)))
  ignore(self.cancel_image_resource_loads(window_id))
  ignore(self.runtime_slots.remove(window_id))
  ignore(self.platform_windows.remove_host(window_id))
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
}

///|
pub fn WindowHostCoordinator::rollback_window_record(
  self : WindowHostCoordinator,
  window_id : @backend_host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
pub fn runtime_slot_needs_redraw(slot : HostWindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
pub fn to_host_id(
  render_id : @render.RenderWindowId,
) -> @backend_host.HostWindowId {
  @backend_host.HostWindowId::new(render_id.value)
}

///|
pub fn to_render_id(
  window_id : @backend_host.HostWindowId,
) -> @render.RenderWindowId {
  @render.RenderWindowId::new(window_id.value)
}

///|
pub fn to_render_metrics(
  metrics : @backend_host.HostSurfaceMetrics,
) -> @render.RendererSurfaceMetrics {
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}
