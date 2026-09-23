///|
pub struct WindowRegistry {
  mut next_value : Int
  mut records : Array[@backend_host.WindowRecord]
}

///|
pub fn WindowRegistry::new() -> WindowRegistry {
  { next_value: 1, records: [], }
}

///|
pub fn WindowRegistry::open(
  self : WindowRegistry,
  title~ : String,
  scene? : @backend_host.WindowScene = @backend_host.WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  primary? : Bool = false,
) -> @backend_host.WindowId {
  let id = @backend_host.WindowId::new(self.next_value)
  self.next_value = self.next_value + 1
  let is_primary = primary || self.open_window_count() == 0
  if is_primary {
    self.clear_primary()
  }
  self.records.push(
    @backend_host.WindowRecord::new(
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
pub fn WindowRegistry::lookup(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> @backend_host.WindowRecord? {
  for record in self.records {
    if record.id == id {
      return Some(record)
    }
  }
  None
}

///|
pub fn WindowRegistry::open_windows(
  self : WindowRegistry,
) -> Array[@backend_host.WindowRecord] {
  self.records.filter(record => record.phase != WindowClosed)
}

///|
pub fn WindowRegistry::open_window_count(self : WindowRegistry) -> Int {
  self.open_windows().length()
}

///|
pub fn WindowRegistry::primary_window(
  self : WindowRegistry,
) -> @backend_host.WindowRecord? {
  for record in self.records {
    if record.primary && record.phase != WindowClosed {
      return Some(record)
    }
  }
  None
}

///|
pub fn WindowRegistry::focused_window(
  self : WindowRegistry,
) -> @backend_host.WindowRecord? {
  for record in self.records {
    if record.phase == WindowFocused {
      return Some(record)
    }
  }
  None
}

///|
pub fn WindowRegistry::focus(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  if !self.has_open_window(id) {
    return false
  }
  self.records = self.records.map(record => {
    if record.id == id {
      { ..record, phase: WindowFocused, }
    } else if record.phase == WindowFocused {
      { ..record, phase: WindowVisible, }
    } else {
      record
    }
  })
  true
}

///|
pub fn WindowRegistry::resize(
  self : WindowRegistry,
  id : @backend_host.WindowId,
  metrics : @core.SurfaceMetrics,
) -> Bool {
  self.update_open_window(id, record => { ..record, metrics, })
}

///|
pub fn WindowRegistry::minimize(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  self.update_open_window(id, record => { ..record, phase: WindowMinimized, })
}

///|
pub fn WindowRegistry::show(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  self.update_open_window(id, record => { ..record, phase: WindowVisible, })
}

///|
pub fn WindowRegistry::request_close(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  self.update_open_window(id, record => {
    ..record,
    phase: WindowCloseRequested,
  })
}

///|
pub fn WindowRegistry::close(
  self : WindowRegistry,
  id : @backend_host.WindowId,
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
pub fn WindowRegistry::remove_closed(self : WindowRegistry) -> Int {
  let before = self.records.length()
  self.records = self.records.filter(record => record.phase != WindowClosed)
  before - self.records.length()
}

///|
pub fn WindowRegistry::set_primary(
  self : WindowRegistry,
  id : @backend_host.WindowId,
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
pub fn WindowRegistry::apply_host_event(
  self : WindowRegistry,
  id : @backend_host.WindowId,
  event : @backend_host.Event,
) -> Bool {
  match event {
    Resized(metrics) => self.resize(id, metrics)
    Focus({ focused: true, .. }) => self.focus(id)
    Focus({ focused: false, .. }) =>
      self.update_open_window(id, record => {
        if record.phase == WindowFocused {
          { ..record, phase: WindowVisible, }
        } else {
          record
        }
      })
    CloseRequested => self.request_close(id)
    _ => false
  }
}

///|
pub fn WindowRegistry::apply_request(
  self : WindowRegistry,
  request : @backend_host.WindowRequest,
) -> @backend_host.WindowRequestResult {
  match request {
    OpenWindow(request) =>
      WindowOpened(
        self.open(
          title=request.title,
          scene=request.scene,
          metrics=request.metrics,
          primary=request.primary,
        ),
      )
    FocusWindow(id) =>
      window_request_update_result(id, self.focus(id), action="focus")
    CloseWindow(id) =>
      window_request_update_result(id, self.request_close(id), action="close")
    ResizeWindow(id, metrics) =>
      window_request_update_result(
        id,
        self.resize(id, metrics),
        action="resize",
      )
    MinimizeWindow(id) =>
      window_request_update_result(id, self.minimize(id), action="minimize")
    ShowWindow(id) =>
      window_request_update_result(id, self.show(id), action="show")
    SetPrimaryWindow(id) =>
      window_request_update_result(
        id,
        self.set_primary(id),
        action="set primary",
      )
  }
}

///|
fn WindowRegistry::has_open_window(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  match self.lookup(id) {
    Some(record) => record.phase != WindowClosed
    None => false
  }
}

///|
fn WindowRegistry::clear_primary(self : WindowRegistry) -> Unit {
  self.records = self.records.map(record => { ..record, primary: false, })
}

///|
fn WindowRegistry::ensure_primary_window(self : WindowRegistry) -> Unit {
  match self.primary_window() {
    Some(_) => ()
    None => {
      let mut assigned = false
      self.records = self.records.map(record => {
        if !assigned && record.phase != WindowClosed {
          assigned = true
          { ..record, primary: true, }
        } else {
          record
        }
      })
    }
  }
}

///|
fn WindowRegistry::update_open_window(
  self : WindowRegistry,
  id : @backend_host.WindowId,
  update : (@backend_host.WindowRecord) -> @backend_host.WindowRecord,
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
  id : @backend_host.WindowId,
  changed : Bool,
  action~ : String,
) -> @backend_host.WindowRequestResult {
  if changed {
    WindowUpdated(id)
  } else {
    WindowRejected("cannot " + action + " window: \{id.value}")
  }
}
