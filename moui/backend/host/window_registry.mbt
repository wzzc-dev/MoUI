///|
pub struct HostWindowRegistry {
  mut next_value : Int
  mut records : Array[HostWindowRecord]
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
