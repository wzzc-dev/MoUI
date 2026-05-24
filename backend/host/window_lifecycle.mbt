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
pub(all) struct HostWindowRecord {
  id : HostWindowId
  title : String
  metrics : HostSurfaceMetrics
  phase : HostWindowLifecyclePhase
  primary : Bool
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
pub fn HostWindowRecord::new(
  id~ : HostWindowId,
  title~ : String,
  metrics~ : HostSurfaceMetrics,
  phase? : HostWindowLifecyclePhase = WindowCreated,
  primary? : Bool = false,
) -> HostWindowRecord {
  { id, title, metrics, phase, primary }
}

///|
pub fn HostWindowRegistry::new() -> HostWindowRegistry {
  { next_value: 1, records: [] }
}

///|
pub fn HostWindowRegistry::open(
  self : HostWindowRegistry,
  title~ : String,
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
