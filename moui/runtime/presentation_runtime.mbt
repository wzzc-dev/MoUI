///|
/// Dispatch the standard presentation dismissal key and report whether the
/// current view consumed it. Hosts use this before turning Back/close into a
/// window-close operation.
pub fn AppRuntime::dispatch_presentation_escape(self : AppRuntime) -> Bool {
  self.state.dispatch_presentation_key("Escape")
}

///|
pub fn AppRuntime::dispatch_presentation_back(self : AppRuntime) -> Bool {
  self.state.dispatch_presentation_key("Back")
}

///|
pub fn AppRuntime::dispatch_presentation_host_close(self : AppRuntime) -> Bool {
  self.state.dispatch_presentation_key("HostClose")
}

///|
fn RuntimeState::dispatch_presentation_key(
  self : RuntimeState,
  key : String,
) -> Bool {
  self.dispatch_event(@core.AppEvent::Keyboard(@core.KeyboardEvent::new(key~)))
  self.dirty.needs_rebuild || self.dirty.needs_paint
}
