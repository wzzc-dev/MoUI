///|
pub struct WindowRegistry {
  mut next_value : Int
  mut records : Array[@backend_host.WindowRecord]
}

///|
pub fn WindowRegistry::new() -> WindowRegistry {
  { next_value: 1, records: [] }
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
      phase=@backend_host.WindowLifecyclePhase::WindowVisible,
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
  self.records.filter(record => {
    record.phase != @backend_host.WindowLifecyclePhase::WindowClosed
  })
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
    if record.primary &&
      record.phase != @backend_host.WindowLifecyclePhase::WindowClosed {
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
    if record.phase == @backend_host.WindowLifecyclePhase::WindowFocused {
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
      { ..record, phase: @backend_host.WindowLifecyclePhase::WindowFocused }
    } else if record.phase == @backend_host.WindowLifecyclePhase::WindowFocused {
      { ..record, phase: @backend_host.WindowLifecyclePhase::WindowVisible }
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
  self.update_open_window(id, record => {
    ..record,
    phase: @backend_host.WindowLifecyclePhase::WindowMinimized,
  })
}

///|
pub fn WindowRegistry::show(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  self.update_open_window(id, record => {
    ..record,
    phase: @backend_host.WindowLifecyclePhase::WindowVisible,
  })
}

///|
pub fn WindowRegistry::request_close(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  self.update_open_window(id, record => {
    ..record,
    phase: @backend_host.WindowLifecyclePhase::WindowCloseRequested,
  })
}

///|
pub fn WindowRegistry::close(
  self : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  let changed = self.update_open_window(id, record => {
    ..record,
    phase: @backend_host.WindowLifecyclePhase::WindowClosed,
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
  self.records = self.records.filter(record => {
    record.phase != @backend_host.WindowLifecyclePhase::WindowClosed
  })
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
    primary: record.id == id &&
    record.phase != @backend_host.WindowLifecyclePhase::WindowClosed,
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
    @backend_host.Event::Resized(metrics) => self.resize(id, metrics)
    @backend_host.Event::Focus({ focused: true, .. }) => self.focus(id)
    @backend_host.Event::Focus({ focused: false, .. }) =>
      self.update_open_window(id, record => {
        if record.phase == @backend_host.WindowLifecyclePhase::WindowFocused {
          { ..record, phase: @backend_host.WindowLifecyclePhase::WindowVisible }
        } else {
          record
        }
      })
    @backend_host.Event::CloseRequested => self.request_close(id)
    _ => false
  }
}

///|
pub fn WindowRegistry::apply_request(
  self : WindowRegistry,
  request : @backend_host.WindowRequest,
) -> @backend_host.WindowRequestResult {
  match request {
    @backend_host.WindowRequest::OpenWindow(request) =>
      @backend_host.WindowRequestResult::WindowOpened(
        self.open(
          title=request.title,
          scene=request.scene,
          metrics=request.metrics,
          primary=request.primary,
        ),
      )
    @backend_host.WindowRequest::FocusWindow(id) =>
      window_request_update_result(id, self.focus(id), action="focus")
    @backend_host.WindowRequest::CloseWindow(id) =>
      window_request_update_result(id, self.request_close(id), action="close")
    @backend_host.WindowRequest::ResizeWindow(id, metrics) =>
      window_request_update_result(
        id,
        self.resize(id, metrics),
        action="resize",
      )
    @backend_host.WindowRequest::MinimizeWindow(id) =>
      window_request_update_result(id, self.minimize(id), action="minimize")
    @backend_host.WindowRequest::ShowWindow(id) =>
      window_request_update_result(id, self.show(id), action="show")
    @backend_host.WindowRequest::SetPrimaryWindow(id) =>
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
    Some(record) =>
      record.phase != @backend_host.WindowLifecyclePhase::WindowClosed
    None => false
  }
}

///|
fn WindowRegistry::clear_primary(self : WindowRegistry) -> Unit {
  self.records = self.records.map(record => { ..record, primary: false })
}

///|
fn WindowRegistry::ensure_primary_window(self : WindowRegistry) -> Unit {
  match self.primary_window() {
    Some(_) => ()
    None => {
      let mut assigned = false
      self.records = self.records.map(record => {
        if !assigned &&
          record.phase != @backend_host.WindowLifecyclePhase::WindowClosed {
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
fn WindowRegistry::update_open_window(
  self : WindowRegistry,
  id : @backend_host.WindowId,
  update : (@backend_host.WindowRecord) -> @backend_host.WindowRecord,
) -> Bool {
  let mut changed = false
  self.records = self.records.map(record => {
    if record.id == id &&
      record.phase != @backend_host.WindowLifecyclePhase::WindowClosed {
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
    @backend_host.WindowRequestResult::WindowUpdated(id)
  } else {
    @backend_host.WindowRequestResult::WindowRejected(
      "cannot " + action + " window: \{id.value}",
    )
  }
}
