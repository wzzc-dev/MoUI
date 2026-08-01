///|
/// Shared platform-window slot (ADR 0020). Each desktop backend maps a
/// `HostWindowId` + `WindowId` pair to its native window object; the generic
/// `extra` carries platform-private per-window state (Linux client
/// decorations, `Unit` elsewhere). Web keeps its own slot because it also
/// binds a canvas surface.
pub struct WindowSlot[W, X] {
  pub host_id : @host.HostWindowId
  pub platform_id : @window_core.WindowId
  pub window : W
  pub mut extra : X
}

///|
pub fn WindowSlot::new[W, X](
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
  pub mut slots : Array[WindowSlot[W, X]]
}

///|
pub fn WindowSlotMap::new[W, X]() -> WindowSlotMap[W, X] {
  { slots: [] }
}

///|
pub fn WindowSlotMap::insert[W, X](
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
pub fn WindowSlotMap::lookup_host[W, X](
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
pub fn WindowSlotMap::lookup_platform[W, X](
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
pub fn WindowSlotMap::remove_host[W, X](
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
pub fn WindowSlot::set_extra[W, X](
  self : WindowSlot[W, X],
  extra~ : X,
) -> Unit {
  self.extra = extra
}
