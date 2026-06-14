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
  runtime : @runtime.AppRuntime
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
  runtime~ : @runtime.AppRuntime,
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
pub fn HostWindowRegistry::new() -> HostWindowRegistry {
  { next_value: 1, records: [] }
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
