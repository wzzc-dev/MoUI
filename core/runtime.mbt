///|
pub struct AppRuntime {
  state : RuntimeState
}

///|
pub fn AppRuntime::new_spec(
  root~ : ViewSpec,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  { state: RuntimeState::new_spec(root~, size~, environment~) }
}

///|
pub fn AppRuntime::new_component(
  root~ : Component,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  { state: RuntimeState::new_component(root~, size~, environment~) }
}

///|
pub fn AppRuntime::dispatch_event(self : AppRuntime, event : AppEvent) -> Unit {
  self.state.dispatch_event(event)
}

///|
pub fn AppRuntime::set_root_spec(self : AppRuntime, root : ViewSpec) -> Unit {
  self.state.set_root_spec(root)
}

///|
pub fn AppRuntime::environment(self : AppRuntime) -> Environment {
  self.state.environment()
}

///|
pub fn AppRuntime::set_environment(
  self : AppRuntime,
  environment : Environment,
) -> Unit {
  self.state.set_environment(environment)
}

///|
pub fn AppRuntime::add_animation(
  self : AppRuntime,
  controller : AnimationController,
) -> Unit {
  self.state.add_animation(controller)
}

///|
pub fn AppRuntime::advance_time(self : AppRuntime, time_ms : Double) -> Unit {
  self.state.advance_time(time_ms)
}

///|
pub fn AppRuntime::mount(self : AppRuntime, root : ViewSpec) -> Unit {
  self.state.mount(root)
}

///|
pub fn AppRuntime::destroy(self : AppRuntime) -> Unit {
  self.state.destroy()
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
pub fn AppRuntime::layout(self : AppRuntime) -> LayoutResult {
  self.state.layout()
}

///|
pub fn AppRuntime::paint_pass(self : AppRuntime) -> Array[DrawCommand] {
  self.state.paint_pass()
}

///|
pub fn AppRuntime::semantics(self : AppRuntime) -> SemanticsNode {
  self.state.semantics()
}

///|
pub fn AppRuntime::focused_text_input(self : AppRuntime) -> TextInputState {
  self.state.focused_text_input()
}

///|
pub fn AppRuntime::focus_next(self : AppRuntime) -> Bool {
  self.state.move_focus()
}

///|
pub fn AppRuntime::focus_previous(self : AppRuntime) -> Bool {
  self.state.move_focus(reverse=true)
}

///|
pub fn AppRuntime::draw_commands(self : AppRuntime) -> Array[DrawCommand] {
  self.state.build_draw_commands()
}

///|
pub fn AppRuntime::size(self : AppRuntime) -> Size {
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

///|
pub fn AppRuntime::dirty_count(self : AppRuntime) -> Int {
  self.state.dirty_count()
}

///|
pub fn AppRuntime::animation_count(self : AppRuntime) -> Int {
  self.state.animation_count()
}

///|
pub fn AppRuntime::set_redraw_callback(
  self : AppRuntime,
  callback : () -> Unit,
) -> Unit {
  self.state.set_redraw_callback(callback)
}

///|
pub fn AppRuntime::set_action_commands(
  self : AppRuntime,
  commands : ActionCommandMap,
) -> Unit {
  self.state.set_action_commands(commands)
}

///|
pub fn AppRuntime::action_commands(self : AppRuntime) -> Array[ActionCommand] {
  self.state.action_commands()
}

///|
pub fn AppRuntime::dispatch_command(
  self : AppRuntime,
  intent : CommandIntent,
) -> Bool {
  self.state.dispatch_command(intent)
}
