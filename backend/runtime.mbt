///|
pub struct AppRuntime {
  state : @core.RuntimeState
}

///|
pub fn AppRuntime::new(
  root~ : @core.ViewNode,
  size~ : @core.Size,
) -> AppRuntime {
  { state: @core.RuntimeState::new(root~, size~) }
}

///|
pub fn AppRuntime::dispatch_event(
  self : AppRuntime,
  event : @core.AppEvent,
) -> Unit {
  self.state.dispatch_event(event)
}

///|
pub fn AppRuntime::set_root(self : AppRuntime, root : @core.ViewNode) -> Unit {
  self.state.set_root(root)
}

///|
pub fn AppRuntime::draw_commands(self : AppRuntime) -> Array[@core.DrawCommand] {
  self.state.build_draw_commands()
}

///|
pub fn AppRuntime::size(self : AppRuntime) -> @core.Size {
  self.state.size
}

///|
pub fn AppRuntime::needs_redraw(self : AppRuntime) -> Bool {
  self.state.needs_redraw
}

///|
pub fn AppRuntime::needs_rebuild(self : AppRuntime) -> Bool {
  self.state.needs_rebuild
}
