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
pub fn AppRuntime::new_spec(
  root~ : @core.ViewSpec,
  size~ : @core.Size,
) -> AppRuntime {
  { state: @core.RuntimeState::new_spec(root~, size~) }
}

///|
pub fn AppRuntime::new_dynamic(
  root~ : () -> @core.ViewNode,
  size~ : @core.Size,
) -> AppRuntime {
  { state: @core.RuntimeState::new_dynamic(root~, size~) }
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
pub fn AppRuntime::set_root_spec(
  self : AppRuntime,
  root : @core.ViewSpec,
) -> Unit {
  self.state.set_root_spec(root)
}

///|
pub fn AppRuntime::mount(self : AppRuntime, root : @core.ViewSpec) -> Unit {
  self.state.mount(root)
}

///|
pub fn AppRuntime::rebuild(self : AppRuntime) -> Unit {
  self.state.rebuild()
}

///|
pub fn AppRuntime::layout_pass(self : AppRuntime) -> Unit {
  self.state.layout_pass()
}

///|
pub fn AppRuntime::paint_pass(self : AppRuntime) -> Array[@core.DrawCommand] {
  self.state.paint_pass()
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

///|
pub fn AppRuntime::needs_layout(self : AppRuntime) -> Bool {
  self.state.needs_layout
}

///|
pub fn AppRuntime::needs_paint(self : AppRuntime) -> Bool {
  self.state.needs_paint
}
