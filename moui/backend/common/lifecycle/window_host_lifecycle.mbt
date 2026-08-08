///|
/// Platform projection owned by the logical window lifecycle. The closures
/// carry native effects; frame, image, input, and service state remain in
/// their dedicated owners.
pub(all) struct WindowSurfaceActions {
  focus : () -> Unit
  request_resize : (@core.SurfaceMetrics) -> @core.SurfaceMetrics
  sync_observed_resize : (@core.SurfaceMetrics) -> @core.SurfaceMetrics
  set_minimized : (Bool) -> Unit
  set_visible : (Bool) -> Unit
  request_redraw : () -> Unit
  request_ime_update : (@window_input.TextInputSessionAction) -> Unit
  drop : () -> Unit
  native_view_handle : () -> UInt64?
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
  request_ime_update~ : (@window_input.TextInputSessionAction) -> Unit,
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
priv struct WindowSurfaceEntry {
  id : @backend_host.WindowId
  actions : WindowSurfaceActions
}

///|
/// Logical host-window owner. It intentionally contains no renderer, image,
/// input-session, or service-bridge state.
pub struct WindowLifecycle {
  priv requests : @backend_host.WindowRequests
  priv scene_resolver : @runtime.WindowSceneResolver
  priv windows : WindowRegistry
  priv runtime_slots : WindowRuntimeSlots
  priv platform_windows : PlatformWindowMap
  priv ledger : WindowLifecycleCore
  priv mut surface_generation : Int
  priv mut exit_intent : Int?
  priv mut surfaces : Array[WindowSurfaceEntry]
}

///|
pub fn WindowLifecycle::new(
  requests~ : @backend_host.WindowRequests,
  scene_resolver~ : @runtime.WindowSceneResolver,
) -> WindowLifecycle {
  {
    requests,
    scene_resolver,
    windows: WindowRegistry::new(),
    runtime_slots: WindowRuntimeSlots::new(),
    platform_windows: PlatformWindowMap::new(),
    ledger: WindowLifecycleCore::new(),
    surface_generation: 0,
    exit_intent: None,
    surfaces: [],
  }
}

///|
pub fn WindowLifecycle::window_registry(
  self : WindowLifecycle,
) -> WindowRegistry {
  self.windows
}

///|
pub fn WindowLifecycle::runtime_slots(
  self : WindowLifecycle,
) -> WindowRuntimeSlots {
  self.runtime_slots
}

///|
pub fn WindowLifecycle::runtime_slots_empty(self : WindowLifecycle) -> Bool {
  self.runtime_slots.is_empty()
}

///|
pub fn WindowLifecycle::runtime_slot_lookup(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> WindowRuntimeSlot? {
  self.runtime_slots.lookup(id)
}

///|
pub fn WindowLifecycle::active_runtime_slot(
  self : WindowLifecycle,
) -> WindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
pub fn WindowLifecycle::bind_platform_window(
  self : WindowLifecycle,
  platform_id~ : @window_core.WindowId,
  window_id~ : @backend_host.WindowId,
) -> Bool {
  self.platform_windows.bind(platform_id~, host_id=window_id)
}

///|
pub fn WindowLifecycle::lookup_window(
  self : WindowLifecycle,
  platform_id : @window_core.WindowId,
) -> @backend_host.WindowId? {
  self.platform_windows.lookup_host(platform_id)
}

///|
pub fn WindowLifecycle::unbind_platform_window(
  self : WindowLifecycle,
  window_id : @backend_host.WindowId,
) -> @window_core.WindowId? {
  self.platform_windows.remove_host(window_id)
}

///|
pub fn WindowLifecycle::attach_surface(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
  actions : WindowSurfaceActions,
) -> Bool {
  if self.surface_actions(id) is Some(_) {
    return false
  }
  self.surfaces.push({ id, actions })
  self.surface_generation = self.surface_generation + 1
  true
}

///|
pub fn WindowLifecycle::surface_actions(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> WindowSurfaceActions? {
  for surface in self.surfaces {
    if surface.id == id {
      return Some(surface.actions)
    }
  }
  None
}

///|
pub fn WindowLifecycle::detach_surface(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> WindowSurfaceActions? {
  let mut removed = None
  let kept = []
  for surface in self.surfaces {
    if surface.id == id {
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
pub fn WindowLifecycle::surface_generation(self : WindowLifecycle) -> Int {
  self.surface_generation
}

///|
pub fn WindowLifecycle::request_exit(
  self : WindowLifecycle,
  code : Int,
) -> Unit {
  self.exit_intent = Some(code)
}

///|
pub fn WindowLifecycle::exit_intent(self : WindowLifecycle) -> Int? {
  self.exit_intent
}

///|
pub fn WindowLifecycle::open_resolution(
  self : WindowLifecycle,
  request : @backend_host.WindowOpenRequest,
) -> @runtime.WindowOpenResolution {
  resolve_open_request(self.windows, request, self.scene_resolver)
}

///|
pub fn WindowLifecycle::drain_window_requests(
  self : WindowLifecycle,
  apply : (@backend_host.WindowRequest) -> @backend_host.WindowRequestResult,
) -> Unit {
  ignore(self.requests.drain_with_handler(apply))
}

///|
pub fn WindowLifecycle::register_runtime_slot(
  self : WindowLifecycle,
  slot : WindowRuntimeSlot,
) -> Bool {
  if !self.ledger.register(slot.id) {
    return false
  }
  if self.runtime_slots.insert(slot) {
    true
  } else {
    ignore(self.ledger.rollback(slot.id))
    false
  }
}

///|
pub fn WindowLifecycle::register_primary_runtime_slot(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
  driver : @runtime.HostRuntimeDriver,
) -> Unit {
  match self.windows.lookup(id) {
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
pub fn WindowLifecycle::sync_runtime_slot(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, id))
}

///|
pub fn WindowLifecycle::sync_runtime_slots(self : WindowLifecycle) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}

///|
pub fn WindowLifecycle::apply_request_state(
  self : WindowLifecycle,
  request : @backend_host.WindowRequest,
) -> @backend_host.WindowRequestResult {
  self.runtime_slots.apply_request(self.windows, request)
}

///|
pub fn WindowLifecycle::apply_host_event(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
  event : @backend_host.Event,
) -> Bool {
  self.runtime_slots.apply_host_event(self.windows, id, event)
}

///|
pub fn WindowLifecycle::begin_close(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> Bool {
  self.ledger.begin_close(id)
}

///|
pub fn WindowLifecycle::finish_close(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  ignore(self.windows.close(id))
  self.sync_runtime_slot(id)
  ignore(self.runtime_slots.remove(id))
  ignore(self.unbind_platform_window(id))
  ignore(self.detach_surface(id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
  ignore(self.ledger.finish_close(id))
}

///|
pub fn WindowLifecycle::rollback_window_record(
  self : WindowLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  ignore(self.ledger.rollback(id))
  ignore(self.unbind_platform_window(id))
  ignore(self.detach_surface(id))
  ignore(self.windows.close(id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}
