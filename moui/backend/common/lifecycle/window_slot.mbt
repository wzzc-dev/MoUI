///|
/// Shared platform resource slot. Platform-id mapping belongs exclusively to
/// the lifecycle owner; this table is keyed only by the backend window id.
/// The generic `extra` carries platform-private per-window state (Linux client
/// decorations, `Unit` elsewhere).
pub struct WindowSlot[W, X] {
  host_id : @backend_host.WindowId
  window : W
  mut extra : X
}

///|
pub fn[W, X] WindowSlot::new(
  host_id~ : @backend_host.WindowId,
  window~ : W,
  extra~ : X,
) -> WindowSlot[W, X] {
  { host_id, window, extra }
}

///|
/// Ordered backend-id resource registry with duplicate rejection.
pub struct WindowSlotMap[W, X] {
  mut slots : Array[WindowSlot[W, X]]
}

///|
pub fn[W, X] WindowSlotMap::new() -> WindowSlotMap[W, X] {
  { slots: [] }
}

///|
pub fn[W, X] WindowSlotMap::insert(
  self : WindowSlotMap[W, X],
  slot : WindowSlot[W, X],
) -> Bool {
  match self.lookup_host(slot.host_id) {
    None => {
      self.slots.push(slot)
      true
    }
    Some(_) => false
  }
}

///|
pub fn[W, X] WindowSlotMap::lookup_host(
  self : WindowSlotMap[W, X],
  host_id : @backend_host.WindowId,
) -> WindowSlot[W, X]? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
pub fn[W, X] WindowSlotMap::remove_host(
  self : WindowSlotMap[W, X],
  host_id : @backend_host.WindowId,
) -> WindowSlot[W, X]? {
  let mut removed = None
  let kept = []
  for slot in self.slots {
    if slot.host_id == host_id {
      removed = Some(slot)
    } else {
      kept.push(slot)
    }
  }
  self.slots = kept
  removed
}

///|
/// Replace the platform-private per-window state (Linux client decorations).
pub fn[W, X] WindowSlot::set_extra(self : WindowSlot[W, X], extra~ : X) -> Unit {
  self.extra = extra
}
