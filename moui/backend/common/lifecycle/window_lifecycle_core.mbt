///|
/// Private lifecycle ledger shared by desktop coordinator adapters.
///
/// The public window registry describes application-visible state. This
/// ledger describes resource ownership, so a late close/detach callback cannot
/// run native teardown twice for the same backend window.
priv enum WindowLifecycleState {
  Active
  Closing
  Closed
}

///|
priv struct WindowLifecycleEntry {
  id : @backend_host.WindowId
  mut state : WindowLifecycleState
}

///|
priv struct WindowLifecycleCore {
  mut entries : Array[WindowLifecycleEntry]
}

///|
fn WindowLifecycleCore::new() -> WindowLifecycleCore {
  { entries: [] }
}

///|
/// Register one resource owner. Duplicate active registrations are rejected.
fn WindowLifecycleCore::register(
  self : WindowLifecycleCore,
  id : @backend_host.WindowId,
) -> Bool {
  for entry in self.entries {
    if entry.id == id {
      return false
    }
  }
  self.entries.push({ id, state: WindowLifecycleState::Active })
  true
}

///|
/// Begin teardown exactly once and claim the teardown effect.
fn WindowLifecycleCore::begin_close(
  self : WindowLifecycleCore,
  id : @backend_host.WindowId,
) -> Bool {
  for entry in self.entries {
    if entry.id == id {
      match entry.state {
        WindowLifecycleState::Active => {
          entry.state = WindowLifecycleState::Closing
          return true
        }
        WindowLifecycleState::Closing | WindowLifecycleState::Closed =>
          return false
      }
    }
  }
  false
}

///|
/// Mark a claimed teardown complete; late callbacks remain harmless.
fn WindowLifecycleCore::finish_close(
  self : WindowLifecycleCore,
  id : @backend_host.WindowId,
) -> Bool {
  for entry in self.entries {
    if entry.id == id {
      match entry.state {
        WindowLifecycleState::Closing => {
          entry.state = WindowLifecycleState::Closed
          return true
        }
        WindowLifecycleState::Closed => return false
        WindowLifecycleState::Active => return false
      }
    }
  }
  false
}

///|
/// Roll back a registration when native window creation or binding fails.
fn WindowLifecycleCore::rollback(
  self : WindowLifecycleCore,
  id : @backend_host.WindowId,
) -> Bool {
  let before = self.entries.length()
  self.entries = self.entries.filter(entry => entry.id != id)
  before != self.entries.length()
}
