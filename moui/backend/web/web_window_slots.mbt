///|
priv struct WebWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_web.Window
  renderer : @render.HostWindowRenderer
}

///|
priv struct WebWindowPlatformSlots {
  mut slots : Array[WebWindowPlatformSlot]
}

///|
fn window_web_default_canvas_id(raw_id : Int) -> String {
  "moonbit-window-web-\{raw_id}"
}

///|
fn WebWindowPlatformSlots::new() -> WebWindowPlatformSlots {
  { slots: [] }
}

///|
fn WebWindowPlatformSlots::insert(
  self : WebWindowPlatformSlots,
  slot : WebWindowPlatformSlot,
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
fn WebWindowPlatformSlots::lookup_host(
  self : WebWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> WebWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WebWindowPlatformSlots::lookup_platform(
  self : WebWindowPlatformSlots,
  platform_id : @window_core.WindowId,
) -> WebWindowPlatformSlot? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WebWindowPlatformSlots::remove_host(
  self : WebWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> WebWindowPlatformSlot? {
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
