///|
pub(all) struct HostWindowId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostWindowLifecyclePhase {
  WindowCreated
  WindowVisible
  WindowFocused
  WindowMinimized
  WindowCloseRequested
  WindowClosed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowScene {
  scene_id : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowRecord {
  id : HostWindowId
  title : String
  scene : HostWindowScene
  metrics : HostSurfaceMetrics
  phase : HostWindowLifecyclePhase
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowOpenRequest {
  title : String
  scene : HostWindowScene
  metrics : HostSurfaceMetrics
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowSceneInstance {
  request : HostWindowOpenRequest
  runtime : @core.AppRuntime
}

///|
pub(all) enum HostWindowSceneResolution {
  SceneResolved(HostWindowSceneInstance)
  SceneRejected(String)
}

///|
pub(all) struct HostWindowResolvedOpen {
  id : HostWindowId
  record : HostWindowRecord
  instance : HostWindowSceneInstance
}

///|
pub(all) struct HostWindowRuntimeSlot {
  id : HostWindowId
  record : HostWindowRecord
  driver : HostRuntimeDriver
}

///|
pub(all) struct HostPlatformWindowBinding {
  platform_id : @window_core.WindowId
  host_id : HostWindowId
} derive(Eq, Debug)

///|
pub(all) enum HostWindowOpenResolution {
  OpenResolved(HostWindowResolvedOpen)
  OpenRejected(String)
}

///|
pub(all) struct HostWindowSceneResolver {
  resolve : (HostWindowOpenRequest) -> HostWindowSceneResolution
}

///|
pub(all) enum HostWindowRequest {
  OpenWindow(HostWindowOpenRequest)
  FocusWindow(HostWindowId)
  CloseWindow(HostWindowId)
  ResizeWindow(HostWindowId, HostSurfaceMetrics)
  MinimizeWindow(HostWindowId)
  ShowWindow(HostWindowId)
  SetPrimaryWindow(HostWindowId)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostWindowRequestResult {
  WindowOpened(HostWindowId)
  WindowUpdated(HostWindowId)
  WindowRejected(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowRequestCompletion {
  request : HostWindowRequest
  result : HostWindowRequestResult
} derive(Eq, Debug, ToJson)

///|
pub struct HostWindowRegistry {
  mut next_value : Int
  mut records : Array[HostWindowRecord]
}

///|
pub struct HostWindowRequestQueue {
  mut requests : Array[HostWindowRequest]
  mut completed : Array[HostWindowRequestCompletion]
}

///|
pub struct HostWindowRuntimeSlots {
  mut slots : Array[HostWindowRuntimeSlot]
}

///|
pub struct HostPlatformWindowMap {
  mut bindings : Array[HostPlatformWindowBinding]
}

///|
pub fn HostWindowId::new(value : Int) -> HostWindowId {
  { value, }
}

///|
pub fn HostWindowScene::new(
  scene_id~ : String,
  payload? : String = "",
) -> HostWindowScene {
  { scene_id, payload }
}

///|
pub fn HostWindowScene::main() -> HostWindowScene {
  HostWindowScene::new(scene_id="main")
}

///|
pub fn HostWindowRecord::new(
  id~ : HostWindowId,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  phase? : HostWindowLifecyclePhase = WindowCreated,
  primary? : Bool = false,
) -> HostWindowRecord {
  { id, title, scene, metrics, phase, primary }
}

///|
pub fn HostWindowOpenRequest::new(
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> HostWindowOpenRequest {
  { title, scene, metrics, primary }
}

///|
pub fn HostWindowSceneInstance::new(
  request~ : HostWindowOpenRequest,
  runtime~ : @core.AppRuntime,
) -> HostWindowSceneInstance {
  { request, runtime }
}

///|
pub fn HostWindowSceneResolver::new(
  resolve~ : (HostWindowOpenRequest) -> HostWindowSceneResolution,
) -> HostWindowSceneResolver {
  { resolve, }
}

///|
pub fn HostWindowSceneResolver::unavailable(
  reason? : String = "window scene resolver is unavailable",
) -> HostWindowSceneResolver {
  HostWindowSceneResolver::new(resolve=_request => {
    HostWindowSceneResolution::SceneRejected(reason)
  })
}

///|
pub fn HostWindowSceneResolver::resolve(
  self : HostWindowSceneResolver,
  request : HostWindowOpenRequest,
) -> HostWindowSceneResolution {
  (self.resolve)(request)
}

///|
pub fn HostWindowResolvedOpen::new(
  id~ : HostWindowId,
  record~ : HostWindowRecord,
  instance~ : HostWindowSceneInstance,
) -> HostWindowResolvedOpen {
  { id, record, instance }
}

///|
pub fn HostWindowRuntimeSlot::new(
  record~ : HostWindowRecord,
  runtime~ : @core.AppRuntime,
  schedule_redraw~ : () -> Unit,
) -> HostWindowRuntimeSlot {
  {
    id: record.id,
    record,
    driver: HostRuntimeDriver::new(runtime~, schedule_redraw~),
  }
}

///|
pub fn HostWindowRuntimeSlot::from_driver(
  record~ : HostWindowRecord,
  driver~ : HostRuntimeDriver,
) -> HostWindowRuntimeSlot {
  { id: record.id, record, driver }
}

///|
pub fn HostWindowRuntimeSlot::from_resolved_open(
  resolved : HostWindowResolvedOpen,
  schedule_redraw~ : () -> Unit,
) -> HostWindowRuntimeSlot {
  HostWindowRuntimeSlot::new(
    record=resolved.record,
    runtime=resolved.instance.runtime,
    schedule_redraw~,
  )
}

///|
pub fn HostWindowRegistry::new() -> HostWindowRegistry {
  { next_value: 1, records: [] }
}

///|
pub fn HostWindowRequestQueue::new() -> HostWindowRequestQueue {
  { requests: [], completed: [] }
}

///|
pub fn HostWindowRuntimeSlots::new() -> HostWindowRuntimeSlots {
  { slots: [] }
}

///|
pub fn HostPlatformWindowMap::new() -> HostPlatformWindowMap {
  { bindings: [] }
}

///|
pub fn HostPlatformWindowMap::count(self : HostPlatformWindowMap) -> Int {
  self.bindings.length()
}

///|
pub fn HostPlatformWindowMap::is_empty(self : HostPlatformWindowMap) -> Bool {
  self.bindings.is_empty()
}

///|
pub fn HostPlatformWindowMap::bind(
  self : HostPlatformWindowMap,
  platform_id~ : @window_core.WindowId,
  host_id~ : HostWindowId,
) -> Bool {
  match (self.lookup_host(platform_id), self.lookup_platform(host_id)) {
    (None, None) => {
      self.bindings.push({ platform_id, host_id })
      true
    }
    _ => false
  }
}

///|
pub fn HostPlatformWindowMap::lookup_host(
  self : HostPlatformWindowMap,
  platform_id : @window_core.WindowId,
) -> HostWindowId? {
  for binding in self.bindings {
    if binding.platform_id == platform_id {
      return Some(binding.host_id)
    }
  }
  None
}

///|
pub fn HostPlatformWindowMap::lookup_platform(
  self : HostPlatformWindowMap,
  host_id : HostWindowId,
) -> @window_core.WindowId? {
  for binding in self.bindings {
    if binding.host_id == host_id {
      return Some(binding.platform_id)
    }
  }
  None
}

///|
pub fn HostPlatformWindowMap::remove_platform(
  self : HostPlatformWindowMap,
  platform_id : @window_core.WindowId,
) -> HostWindowId? {
  let mut removed = None
  let kept = []
  for binding in self.bindings {
    if binding.platform_id == platform_id {
      removed = Some(binding.host_id)
    } else {
      kept.push(binding)
    }
  }
  self.bindings = kept
  removed
}

///|
pub fn HostPlatformWindowMap::remove_host(
  self : HostPlatformWindowMap,
  host_id : HostWindowId,
) -> @window_core.WindowId? {
  let mut removed = None
  let kept = []
  for binding in self.bindings {
    if binding.host_id == host_id {
      removed = Some(binding.platform_id)
    } else {
      kept.push(binding)
    }
  }
  self.bindings = kept
  removed
}

///|
pub fn HostWindowRuntimeSlots::count(self : HostWindowRuntimeSlots) -> Int {
  self.slots.length()
}

///|
pub fn HostWindowRuntimeSlots::is_empty(self : HostWindowRuntimeSlots) -> Bool {
  self.slots.is_empty()
}

///|
pub fn HostWindowRuntimeSlots::insert(
  self : HostWindowRuntimeSlots,
  slot : HostWindowRuntimeSlot,
) -> Bool {
  match self.lookup(slot.id) {
    Some(_) => false
    None => {
      self.slots.push(slot)
      true
    }
  }
}

///|
pub fn HostWindowRuntimeSlots::insert_from_registry(
  self : HostWindowRuntimeSlots,
  registry : HostWindowRegistry,
  id : HostWindowId,
  driver~ : HostRuntimeDriver,
) -> Bool {
  match registry.lookup(id) {
    Some(record) =>
      self.insert(HostWindowRuntimeSlot::from_driver(record~, driver~))
    None => false
  }
}

///|
pub fn HostWindowRuntimeSlots::lookup(
  self : HostWindowRuntimeSlots,
  id : HostWindowId,
) -> HostWindowRuntimeSlot? {
  for slot in self.slots {
    if slot.id == id {
      return Some(slot)
    }
  }
  None
}

///|
pub fn HostWindowRuntimeSlots::open_slots(
  self : HostWindowRuntimeSlots,
) -> Array[HostWindowRuntimeSlot] {
  self.slots.filter(slot => slot.record.phase != WindowClosed)
}

///|
pub fn HostWindowRuntimeSlots::primary_slot(
  self : HostWindowRuntimeSlots,
) -> HostWindowRuntimeSlot? {
  for slot in self.open_slots() {
    if slot.record.primary {
      return Some(slot)
    }
  }
  None
}

///|
pub fn HostWindowRuntimeSlots::focused_slot(
  self : HostWindowRuntimeSlots,
) -> HostWindowRuntimeSlot? {
  for slot in self.open_slots() {
    if slot.record.phase == WindowFocused {
      return Some(slot)
    }
  }
  None
}

///|
pub fn HostWindowRuntimeSlots::sync_record(
  self : HostWindowRuntimeSlots,
  record : HostWindowRecord,
) -> Bool {
  let mut changed = false
  self.slots = self.slots.map(slot => {
    if slot.id == record.id {
      changed = true
      { ..slot, record, }
    } else {
      slot
    }
  })
  changed
}

///|
pub fn HostWindowRuntimeSlots::sync_from_registry(
  self : HostWindowRuntimeSlots,
  registry : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  match registry.lookup(id) {
    Some(record) => self.sync_record(record)
    None => false
  }
}

///|
pub fn HostWindowRuntimeSlots::apply_host_event(
  self : HostWindowRuntimeSlots,
  registry : HostWindowRegistry,
  id : HostWindowId,
  event : HostEvent,
) -> Bool {
  if registry.apply_host_event(id, event) {
    ignore(self.sync_from_registry(registry, id))
    true
  } else {
    false
  }
}

///|
pub fn HostWindowRuntimeSlots::apply_request(
  self : HostWindowRuntimeSlots,
  registry : HostWindowRegistry,
  request : HostWindowRequest,
) -> HostWindowRequestResult {
  let result = registry.apply_request(request)
  match result {
    HostWindowRequestResult::WindowOpened(id)
    | HostWindowRequestResult::WindowUpdated(id) =>
      ignore(self.sync_from_registry(registry, id))
    HostWindowRequestResult::WindowRejected(_) => ()
  }
  result
}

///|
pub fn HostWindowRuntimeSlots::remove(
  self : HostWindowRuntimeSlots,
  id : HostWindowId,
) -> HostWindowRuntimeSlot? {
  let mut removed = None
  let kept = []
  for slot in self.slots {
    if slot.id == id {
      removed = Some(slot)
    } else {
      kept.push(slot)
    }
  }
  self.slots = kept
  removed
}

///|
pub fn HostWindowRuntimeSlots::remove_closed(
  self : HostWindowRuntimeSlots,
) -> Int {
  let before = self.slots.length()
  self.slots = self.slots.filter(slot => slot.record.phase != WindowClosed)
  before - self.slots.length()
}

///|
pub fn HostWindowRequestQueue::pending_count(
  self : HostWindowRequestQueue,
) -> Int {
  self.requests.length()
}

///|
pub fn HostWindowRequestQueue::completed_count(
  self : HostWindowRequestQueue,
) -> Int {
  self.completed.length()
}

///|
pub fn HostWindowRequestQueue::is_empty(self : HostWindowRequestQueue) -> Bool {
  self.requests.is_empty()
}

///|
pub fn HostWindowRequestQueue::push(
  self : HostWindowRequestQueue,
  request : HostWindowRequest,
) -> Unit {
  self.requests.push(request)
}

///|
pub fn HostWindowRequestQueue::open_window(
  self : HostWindowRequestQueue,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.push(
    HostWindowRequest::OpenWindow(
      HostWindowOpenRequest::new(title~, scene~, metrics~, primary~),
    ),
  )
}

///|
pub fn HostWindowRequestQueue::focus_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::FocusWindow(id))
}

///|
pub fn HostWindowRequestQueue::close_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::CloseWindow(id))
}

///|
pub fn HostWindowRequestQueue::resize_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
  metrics : HostSurfaceMetrics,
) -> Unit {
  self.push(HostWindowRequest::ResizeWindow(id, metrics))
}

///|
pub fn HostWindowRequestQueue::minimize_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::MinimizeWindow(id))
}

///|
pub fn HostWindowRequestQueue::show_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::ShowWindow(id))
}

///|
pub fn HostWindowRequestQueue::set_primary_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::SetPrimaryWindow(id))
}

///|
pub fn HostWindowRequestQueue::drain(
  self : HostWindowRequestQueue,
) -> Array[HostWindowRequest] {
  let requests = self.requests
  self.requests = []
  requests
}

///|
pub fn HostWindowRequestQueue::record_result(
  self : HostWindowRequestQueue,
  request : HostWindowRequest,
  result : HostWindowRequestResult,
) -> Unit {
  self.completed.push({ request, result })
}

///|
pub fn HostWindowRequestQueue::drain_with_handler(
  self : HostWindowRequestQueue,
  handle : (HostWindowRequest) -> HostWindowRequestResult,
) -> Array[HostWindowRequestCompletion] {
  let completions = []
  for request in self.drain() {
    let result = handle(request)
    let completion = HostWindowRequestCompletion::{ request, result }
    self.completed.push(completion)
    completions.push(completion)
  }
  completions
}

///|
pub fn HostWindowRequestQueue::drain_completed(
  self : HostWindowRequestQueue,
) -> Array[HostWindowRequestCompletion] {
  let completed = self.completed
  self.completed = []
  completed
}

///|
pub fn HostWindowRegistry::open(
  self : HostWindowRegistry,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> HostWindowId {
  let id = HostWindowId::new(self.next_value)
  self.next_value = self.next_value + 1
  let is_primary = primary || self.open_window_count() == 0
  if is_primary {
    self.clear_primary()
  }
  self.records.push(
    HostWindowRecord::new(
      id~,
      title~,
      scene~,
      metrics~,
      phase=WindowVisible,
      primary=is_primary,
    ),
  )
  id
}

///|
pub fn HostWindowRegistry::lookup(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> HostWindowRecord? {
  for record in self.records {
    if record.id == id {
      return Some(record)
    }
  }
  None
}

///|
pub fn HostWindowRegistry::open_windows(
  self : HostWindowRegistry,
) -> Array[HostWindowRecord] {
  self.records.filter(record => record.phase != WindowClosed)
}

///|
pub fn HostWindowRegistry::open_window_count(self : HostWindowRegistry) -> Int {
  self.open_windows().length()
}

///|
pub fn HostWindowRegistry::primary_window(
  self : HostWindowRegistry,
) -> HostWindowRecord? {
  for record in self.records {
    if record.primary && record.phase != WindowClosed {
      return Some(record)
    }
  }
  None
}

///|
pub fn HostWindowRegistry::focused_window(
  self : HostWindowRegistry,
) -> HostWindowRecord? {
  for record in self.records {
    if record.phase == WindowFocused {
      return Some(record)
    }
  }
  None
}

///|
pub fn HostWindowRegistry::focus(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  if !self.has_open_window(id) {
    return false
  }
  self.records = self.records.map(record => {
    if record.id == id {
      { ..record, phase: WindowFocused }
    } else if record.phase == WindowFocused {
      { ..record, phase: WindowVisible }
    } else {
      record
    }
  })
  true
}

///|
pub fn HostWindowRegistry::resize(
  self : HostWindowRegistry,
  id : HostWindowId,
  metrics : HostSurfaceMetrics,
) -> Bool {
  self.update_open_window(id, record => { ..record, metrics, })
}

///|
pub fn HostWindowRegistry::minimize(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  self.update_open_window(id, record => { ..record, phase: WindowMinimized })
}

///|
pub fn HostWindowRegistry::show(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  self.update_open_window(id, record => { ..record, phase: WindowVisible })
}

///|
pub fn HostWindowRegistry::request_close(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  self.update_open_window(id, record => {
    ..record,
    phase: WindowCloseRequested,
  })
}

///|
pub fn HostWindowRegistry::close(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  let changed = self.update_open_window(id, record => {
    ..record,
    phase: WindowClosed,
    primary: false,
  })
  if changed {
    self.ensure_primary_window()
  }
  changed
}

///|
pub fn HostWindowRegistry::remove_closed(self : HostWindowRegistry) -> Int {
  let before = self.records.length()
  self.records = self.records.filter(record => record.phase != WindowClosed)
  before - self.records.length()
}

///|
pub fn HostWindowRegistry::set_primary(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  if !self.has_open_window(id) {
    return false
  }
  self.records = self.records.map(record => {
    ..record,
    primary: record.id == id && record.phase != WindowClosed,
  })
  true
}

///|
pub fn HostWindowRegistry::apply_host_event(
  self : HostWindowRegistry,
  id : HostWindowId,
  event : HostEvent,
) -> Bool {
  match event {
    HostEvent::Resized(metrics) => self.resize(id, metrics)
    HostEvent::Focus({ focused: true, .. }) => self.focus(id)
    HostEvent::Focus({ focused: false, .. }) =>
      self.update_open_window(id, record => {
        if record.phase == WindowFocused {
          { ..record, phase: WindowVisible }
        } else {
          record
        }
      })
    HostEvent::CloseRequested => self.request_close(id)
    _ => false
  }
}

///|
pub fn HostWindowRegistry::apply_request(
  self : HostWindowRegistry,
  request : HostWindowRequest,
) -> HostWindowRequestResult {
  match request {
    HostWindowRequest::OpenWindow(request) =>
      HostWindowRequestResult::WindowOpened(
        self.open(
          title=request.title,
          scene=request.scene,
          metrics=request.metrics,
          primary=request.primary,
        ),
      )
    HostWindowRequest::FocusWindow(id) =>
      window_request_update_result(id, self.focus(id), action="focus")
    HostWindowRequest::CloseWindow(id) =>
      window_request_update_result(id, self.request_close(id), action="close")
    HostWindowRequest::ResizeWindow(id, metrics) =>
      window_request_update_result(
        id,
        self.resize(id, metrics),
        action="resize",
      )
    HostWindowRequest::MinimizeWindow(id) =>
      window_request_update_result(id, self.minimize(id), action="minimize")
    HostWindowRequest::ShowWindow(id) =>
      window_request_update_result(id, self.show(id), action="show")
    HostWindowRequest::SetPrimaryWindow(id) =>
      window_request_update_result(
        id,
        self.set_primary(id),
        action="set primary",
      )
  }
}

///|
pub fn HostWindowRegistry::resolve_open_request(
  self : HostWindowRegistry,
  request : HostWindowOpenRequest,
  resolver : HostWindowSceneResolver,
) -> HostWindowOpenResolution {
  match resolver.resolve(request) {
    HostWindowSceneResolution::SceneResolved(instance) => {
      let id = self.open(
        title=request.title,
        scene=request.scene,
        metrics=request.metrics,
        primary=request.primary,
      )
      match self.lookup(id) {
        Some(record) =>
          HostWindowOpenResolution::OpenResolved(
            HostWindowResolvedOpen::new(id~, record~, instance~),
          )
        None =>
          HostWindowOpenResolution::OpenRejected(
            "resolved window was not registered: \{id.value}",
          )
      }
    }
    HostWindowSceneResolution::SceneRejected(message) =>
      HostWindowOpenResolution::OpenRejected(message)
  }
}

///|
fn HostWindowRegistry::has_open_window(
  self : HostWindowRegistry,
  id : HostWindowId,
) -> Bool {
  match self.lookup(id) {
    Some(record) => record.phase != WindowClosed
    None => false
  }
}

///|
fn HostWindowRegistry::clear_primary(self : HostWindowRegistry) -> Unit {
  self.records = self.records.map(record => { ..record, primary: false })
}

///|
fn HostWindowRegistry::ensure_primary_window(self : HostWindowRegistry) -> Unit {
  match self.primary_window() {
    Some(_) => ()
    None => {
      let mut assigned = false
      self.records = self.records.map(record => {
        if !assigned && record.phase != WindowClosed {
          assigned = true
          { ..record, primary: true }
        } else {
          record
        }
      })
    }
  }
}

///|
fn HostWindowRegistry::update_open_window(
  self : HostWindowRegistry,
  id : HostWindowId,
  update : (HostWindowRecord) -> HostWindowRecord,
) -> Bool {
  let mut changed = false
  self.records = self.records.map(record => {
    if record.id == id && record.phase != WindowClosed {
      changed = true
      update(record)
    } else {
      record
    }
  })
  changed
}

///|
fn window_request_update_result(
  id : HostWindowId,
  changed : Bool,
  action~ : String,
) -> HostWindowRequestResult {
  if changed {
    HostWindowRequestResult::WindowUpdated(id)
  } else {
    HostWindowRequestResult::WindowRejected(
      "cannot " + action + " window: \{id.value}",
    )
  }
}
