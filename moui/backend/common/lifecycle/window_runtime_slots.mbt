///|
pub(all) struct WindowRuntimeSlot {
  id : @backend_host.WindowId
  record : @backend_host.WindowRecord
  driver : @runtime.HostRuntimeDriver
}

///|
pub struct WindowRuntimeSlots {
  mut slots : Array[WindowRuntimeSlot]
}

///|
pub fn WindowRuntimeSlot::new(
  record~ : @backend_host.WindowRecord,
  runtime~ : @runtime.AppRuntime,
  schedule_redraw~ : () -> Unit,
) -> WindowRuntimeSlot {
  {
    id: record.id,
    record,
    driver: @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw~),
  }
}

///|
pub fn WindowRuntimeSlot::from_driver(
  record~ : @backend_host.WindowRecord,
  driver~ : @runtime.HostRuntimeDriver,
) -> WindowRuntimeSlot {
  { id: record.id, record, driver }
}

///|
pub fn WindowRuntimeSlot::from_resolved_open(
  resolved : @runtime.WindowResolvedOpen,
  schedule_redraw~ : () -> Unit,
) -> WindowRuntimeSlot {
  WindowRuntimeSlot::new(
    record=resolved.record,
    runtime=resolved.instance.runtime,
    schedule_redraw~,
  )
}

///|
pub fn WindowRuntimeSlots::new() -> WindowRuntimeSlots {
  { slots: [] }
}

///|
pub fn WindowRuntimeSlots::count(self : WindowRuntimeSlots) -> Int {
  self.slots.length()
}

///|
pub fn WindowRuntimeSlots::is_empty(self : WindowRuntimeSlots) -> Bool {
  self.slots.is_empty()
}

///|
pub fn WindowRuntimeSlots::insert(
  self : WindowRuntimeSlots,
  slot : WindowRuntimeSlot,
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
pub fn WindowRuntimeSlots::insert_from_registry(
  self : WindowRuntimeSlots,
  registry : WindowRegistry,
  id : @backend_host.WindowId,
  driver~ : @runtime.HostRuntimeDriver,
) -> Bool {
  match registry.lookup(id) {
    Some(record) =>
      self.insert(WindowRuntimeSlot::from_driver(record~, driver~))
    None => false
  }
}

///|
pub fn WindowRuntimeSlots::lookup(
  self : WindowRuntimeSlots,
  id : @backend_host.WindowId,
) -> WindowRuntimeSlot? {
  for slot in self.slots {
    if slot.id == id {
      return Some(slot)
    }
  }
  None
}

///|
pub fn WindowRuntimeSlots::open_slots(
  self : WindowRuntimeSlots,
) -> Array[WindowRuntimeSlot] {
  self.slots.filter(slot => slot.record.phase != @backend_host.WindowClosed)
}

///|
pub fn WindowRuntimeSlots::primary_slot(
  self : WindowRuntimeSlots,
) -> WindowRuntimeSlot? {
  for slot in self.open_slots() {
    if slot.record.primary {
      return Some(slot)
    }
  }
  None
}

///|
pub fn WindowRuntimeSlots::focused_slot(
  self : WindowRuntimeSlots,
) -> WindowRuntimeSlot? {
  for slot in self.open_slots() {
    if slot.record.phase == @backend_host.WindowFocused {
      return Some(slot)
    }
  }
  None
}

///|
pub fn WindowRuntimeSlots::sync_record(
  self : WindowRuntimeSlots,
  record : @backend_host.WindowRecord,
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
pub fn WindowRuntimeSlots::sync_from_registry(
  self : WindowRuntimeSlots,
  registry : WindowRegistry,
  id : @backend_host.WindowId,
) -> Bool {
  match registry.lookup(id) {
    Some(record) => self.sync_record(record)
    None => false
  }
}

///|
pub fn WindowRuntimeSlots::sync_open_from_registry(
  self : WindowRuntimeSlots,
  registry : WindowRegistry,
) -> Int {
  let mut synced = 0
  for record in registry.open_windows() {
    if self.sync_record(record) {
      synced = synced + 1
    }
  }
  synced
}

///|
pub fn WindowRuntimeSlots::apply_host_event(
  self : WindowRuntimeSlots,
  registry : WindowRegistry,
  id : @backend_host.WindowId,
  event : @backend_host.Event,
) -> Bool {
  if registry.apply_host_event(id, event) {
    ignore(self.sync_open_from_registry(registry))
    true
  } else {
    false
  }
}

///|
pub fn WindowRuntimeSlots::apply_request(
  self : WindowRuntimeSlots,
  registry : WindowRegistry,
  request : @backend_host.WindowRequest,
) -> @backend_host.WindowRequestResult {
  let result = registry.apply_request(request)
  match result {
    @backend_host.WindowRequestResult::WindowOpened(_)
    | @backend_host.WindowRequestResult::WindowUpdated(_) =>
      ignore(self.sync_open_from_registry(registry))
    @backend_host.WindowRequestResult::WindowRejected(_) => ()
  }
  result
}

///|
pub fn WindowRuntimeSlots::remove(
  self : WindowRuntimeSlots,
  id : @backend_host.WindowId,
) -> WindowRuntimeSlot? {
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
pub fn WindowRuntimeSlots::remove_closed(self : WindowRuntimeSlots) -> Int {
  let before = self.slots.length()
  self.slots = self.slots.filter(slot => {
    slot.record.phase != @backend_host.WindowClosed
  })
  before - self.slots.length()
}

///|
pub fn drain_to_runtime_slots(
  commands : WindowCommands,
  registry : WindowRegistry,
  slots : WindowRuntimeSlots,
) -> Array[@backend_host.WindowRequestCompletion] {
  let completions = commands.drain_to_registry(registry)
  for _ in completions {
    ignore(slots.sync_open_from_registry(registry))
  }
  completions
}
