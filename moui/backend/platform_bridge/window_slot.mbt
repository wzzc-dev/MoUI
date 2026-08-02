///|
/// Shared platform-window slot (ADR 0020). Each desktop backend maps a
/// `HostWindowId` + `WindowId` pair to its native window object; the generic
/// `extra` carries platform-private per-window state (Linux client
/// decorations, `Unit` elsewhere). Web keeps its own slot because it also
/// binds a canvas surface.
pub struct WindowSlot[W, X] {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : W
  mut extra : X
}

///|
pub fn[W, X] WindowSlot::new(
  host_id~ : @host.HostWindowId,
  platform_id~ : @window_core.WindowId,
  window~ : W,
  extra~ : X,
) -> WindowSlot[W, X] {
  { host_id, platform_id, window, extra }
}

///|
/// Ordered registry of `WindowSlot`s with bidirectional lookup and
/// duplicate rejection, shared by the desktop backends.
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
  match
    (self.lookup_host(slot.host_id), self.lookup_platform(slot.platform_id)) {
    (None, None) => {
      self.slots.push(slot)
      true
    }
    _ => false
  }
}

///|
pub fn[W, X] WindowSlotMap::lookup_host(
  self : WindowSlotMap[W, X],
  host_id : @host.HostWindowId,
) -> WindowSlot[W, X]? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
pub fn[W, X] WindowSlotMap::lookup_platform(
  self : WindowSlotMap[W, X],
  platform_id : @window_core.WindowId,
) -> WindowSlot[W, X]? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
pub fn[W, X] WindowSlotMap::remove_host(
  self : WindowSlotMap[W, X],
  host_id : @host.HostWindowId,
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
