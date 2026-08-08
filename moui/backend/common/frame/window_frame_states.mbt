///|
priv struct WindowFrameEntry {
  id : @backend_host.WindowId
  state : WindowFrameState
}

///|
/// Collection owner for per-window frame/session state.
pub struct WindowFrameStates {
  priv mut entries : Array[WindowFrameEntry]
}

///|
pub fn WindowFrameStates::new() -> WindowFrameStates {
  { entries: [] }
}

///|
pub fn WindowFrameStates::attach(
  self : WindowFrameStates,
  id : @backend_host.WindowId,
  renderer : @render.RendererSession,
  surface_generation? : Int = 1,
  hooks? : WindowFrameHooks = WindowFrameHooks::new(),
) -> Bool {
  if self.lookup(id) is Some(_) {
    return false
  }
  self.entries.push({
    id,
    state: WindowFrameState::new(renderer~, surface_generation~, hooks~),
  })
  true
}

///|
pub fn WindowFrameStates::lookup(
  self : WindowFrameStates,
  id : @backend_host.WindowId,
) -> WindowFrameState? {
  for entry in self.entries {
    if entry.id == id {
      return Some(entry.state)
    }
  }
  None
}

///|
pub fn WindowFrameStates::renderer(
  self : WindowFrameStates,
  id : @backend_host.WindowId,
) -> @render.RendererSession? {
  match self.lookup(id) {
    Some(state) => Some(state.renderer())
    None => None
  }
}

///|
pub fn WindowFrameStates::remove(
  self : WindowFrameStates,
  id : @backend_host.WindowId,
) -> WindowFrameState? {
  let mut removed = None
  let kept = []
  for entry in self.entries {
    if entry.id == id {
      removed = Some(entry.state)
    } else {
      kept.push(entry)
    }
  }
  self.entries = kept
  removed
}

///|
pub fn WindowFrameStates::dispose_window(
  self : WindowFrameStates,
  id : @backend_host.WindowId,
) -> Bool {
  match self.remove(id) {
    Some(state) => {
      state.dispose()
      true
    }
    None => false
  }
}

///|
pub fn WindowFrameStates::count(self : WindowFrameStates) -> Int {
  self.entries.length()
}
