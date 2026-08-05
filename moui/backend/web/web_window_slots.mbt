///|
priv struct WebWindowPlatformSlot {
  host_id : @host.WindowId
  window : @window_web.Window
  renderer : @render.WindowRenderer
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
  match self.lookup_host(slot.host_id) {
    None => {
      self.slots.push(slot)
      true
    }
    Some(_) => false
  }
}

///|
fn WebWindowPlatformSlots::lookup_host(
  self : WebWindowPlatformSlots,
  host_id : @host.WindowId,
) -> WebWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WebWindowPlatformSlots::remove_host(
  self : WebWindowPlatformSlots,
  host_id : @host.WindowId,
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
