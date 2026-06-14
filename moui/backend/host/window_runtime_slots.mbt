///|
pub(all) struct HostWindowRuntimeSlot {
  id : HostWindowId
  record : HostWindowRecord
  driver : HostRuntimeDriver
}

///|
pub struct HostWindowRuntimeSlots {
  mut slots : Array[HostWindowRuntimeSlot]
}

///|
pub fn HostWindowRuntimeSlot::new(
  record~ : HostWindowRecord,
  runtime~ : @runtime.AppRuntime,
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
pub fn HostWindowRuntimeSlots::new() -> HostWindowRuntimeSlots {
  { slots: [] }
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
pub fn HostWindowRuntimeSlots::sync_open_from_registry(
  self : HostWindowRuntimeSlots,
  registry : HostWindowRegistry,
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
pub fn HostWindowRuntimeSlots::apply_host_event(
  self : HostWindowRuntimeSlots,
  registry : HostWindowRegistry,
  id : HostWindowId,
  event : HostEvent,
) -> Bool {
  if registry.apply_host_event(id, event) {
    ignore(self.sync_open_from_registry(registry))
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
    HostWindowRequestResult::WindowOpened(_)
    | HostWindowRequestResult::WindowUpdated(_) =>
      ignore(self.sync_open_from_registry(registry))
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
