///|
priv struct WindowImageTaskEntry {
  id : @backend_host.WindowId
  tasks : WindowImageTasks
}

///|
pub struct WindowImageTaskStates {
  priv mut entries : Array[WindowImageTaskEntry]
}

///|
pub fn WindowImageTaskStates::new() -> WindowImageTaskStates {
  { entries: [] }
}

///|
pub fn WindowImageTaskStates::attach(
  self : WindowImageTaskStates,
  id : @backend_host.WindowId,
  starter? : WindowImageTaskStarter = WindowImageTaskStarter::immediate(),
  request_redraw~ : () -> Unit,
) -> Bool {
  if self.lookup(id) is Some(_) {
    return false
  }
  self.entries.push({
    id,
    tasks: WindowImageTasks::new(starter~, request_redraw~),
  })
  true
}

///|
pub fn WindowImageTaskStates::lookup(
  self : WindowImageTaskStates,
  id : @backend_host.WindowId,
) -> WindowImageTasks? {
  for entry in self.entries {
    if entry.id == id {
      return Some(entry.tasks)
    }
  }
  None
}

///|
pub fn WindowImageTaskStates::remove(
  self : WindowImageTaskStates,
  id : @backend_host.WindowId,
) -> WindowImageTasks? {
  let mut removed = None
  let kept : Array[WindowImageTaskEntry] = []
  for entry in self.entries {
    if entry.id == id {
      removed = Some(entry.tasks)
    } else {
      kept.push(entry)
    }
  }
  self.entries = kept
  removed
}

///|
pub fn WindowImageTaskStates::dispose_window(
  self : WindowImageTaskStates,
  id : @backend_host.WindowId,
) -> Bool {
  match self.remove(id) {
    Some(tasks) => {
      tasks.dispose()
      true
    }
    None => false
  }
}

///|
pub fn WindowImageTaskStates::count(self : WindowImageTaskStates) -> Int {
  self.entries.length()
}
