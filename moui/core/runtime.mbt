///|
struct RuntimeKernel {
  state : RuntimeState
  program_runtime_snapshot_fn : () -> ProgramRuntimeSnapshot
}

///|
pub fn[Msg] RuntimeKernel::new_view(
  root~ : View[Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
  program_runtime_snapshot? : (() -> ProgramRuntimeSnapshot)? = None,
) -> RuntimeKernel {
  let emit = match on_message {
    Some(handler) => handler
    None => _message => ()
  }
  let snapshot = match program_runtime_snapshot {
    Some(provider) => provider
    None => () => ProgramRuntimeSnapshot::empty()
  }
  {
    state: RuntimeState::new_spec(
      root=realize_view(root, emit),
      size~,
      environment~,
    ),
    program_runtime_snapshot_fn: snapshot,
  }
}

///|
pub fn RuntimeKernel::dispatch_event(
  self : RuntimeKernel,
  event : AppEvent,
) -> Unit {
  self.state.dispatch_event(event)
}

///|
pub fn RuntimeKernel::environment(self : RuntimeKernel) -> Environment {
  self.state.environment()
}

///|
pub fn RuntimeKernel::text_system(self : RuntimeKernel) -> TextSystem {
  self.state.text_system()
}

///|
pub fn RuntimeKernel::set_text_system(
  self : RuntimeKernel,
  text_system : TextSystem,
) -> Unit {
  self.state.set_text_system(text_system)
}

///|
pub fn RuntimeKernel::register_font_data(
  self : RuntimeKernel,
  family : FontFamily,
  data : Bytes,
) -> Unit {
  self.state.register_font_data(family, data)
}

///|
pub fn RuntimeKernel::set_environment(
  self : RuntimeKernel,
  environment : Environment,
) -> Unit {
  self.state.set_environment(environment)
}

///|
pub fn RuntimeKernel::advance_time(
  self : RuntimeKernel,
  time_ms : Double,
) -> Unit {
  self.state.advance_time(time_ms)
}

///|
pub fn RuntimeKernel::destroy(self : RuntimeKernel) -> Unit {
  self.state.destroy()
}

///|
pub fn RuntimeKernel::rebuild(self : RuntimeKernel) -> Unit {
  self.state.rebuild()
}

///|
pub fn RuntimeKernel::layout_pass(self : RuntimeKernel) -> Unit {
  self.state.layout_pass()
}

///|
pub fn RuntimeKernel::layout(self : RuntimeKernel) -> LayoutResult {
  self.state.layout()
}

///|
fn RuntimeKernel::view_tree_inspector_snapshot(
  self : RuntimeKernel,
) -> ViewTreeInspectorSnapshot {
  self.state.view_tree_inspector_snapshot()
}

///|
fn RuntimeKernel::inspector_rebuild_reason(self : RuntimeKernel) -> String {
  self.state.inspector_rebuild_reason()
}

///|
fn RuntimeKernel::inspector_dirty_reasons(
  self : RuntimeKernel,
) -> Array[String] {
  self.state.inspector_dirty_reasons()
}

///|
pub fn RuntimeKernel::paint_pass(self : RuntimeKernel) -> Array[DrawCommand] {
  self.state.paint_pass()
}

///|
pub fn RuntimeKernel::semantics(self : RuntimeKernel) -> SemanticsNode {
  self.state.semantics()
}

///|
pub fn RuntimeKernel::focused_text_input(
  self : RuntimeKernel,
) -> TextInputState {
  self.state.focused_text_input()
}

///|
pub fn RuntimeKernel::focus_next(self : RuntimeKernel) -> Bool {
  self.state.move_focus()
}

///|
pub fn RuntimeKernel::focus_previous(self : RuntimeKernel) -> Bool {
  self.state.move_focus(reverse=true)
}

///|
pub fn RuntimeKernel::focus_key(self : RuntimeKernel, key : String) -> Bool {
  self.state.focus_key(key)
}

///|
pub fn RuntimeKernel::draw_commands(self : RuntimeKernel) -> Array[DrawCommand] {
  self.state.build_draw_commands()
}

///|
pub fn RuntimeKernel::draw_frame(self : RuntimeKernel) -> DrawFrame {
  self.state.build_draw_frame()
}

///|
pub fn RuntimeKernel::invalidate_cached_layer_key(
  self : RuntimeKernel,
  key : String,
) -> Unit {
  self.state.invalidate_cached_layer_key(key)
}

///|
pub fn RuntimeKernel::size(self : RuntimeKernel) -> Size {
  self.state.size
}

///|
pub fn RuntimeKernel::needs_redraw(self : RuntimeKernel) -> Bool {
  self.state.needs_redraw
}

///|
pub fn RuntimeKernel::needs_rebuild(self : RuntimeKernel) -> Bool {
  self.state.needs_rebuild
}

///|
pub fn RuntimeKernel::needs_layout(self : RuntimeKernel) -> Bool {
  self.state.needs_layout
}

///|
pub fn RuntimeKernel::needs_paint(self : RuntimeKernel) -> Bool {
  self.state.needs_paint
}

///|
pub fn RuntimeKernel::dirty_count(self : RuntimeKernel) -> Int {
  self.state.dirty_count()
}

///|
pub fn RuntimeKernel::dirty_element_ids(
  self : RuntimeKernel,
) -> Array[ElementId] {
  self.state.dirty_element_ids()
}

///|
pub fn RuntimeKernel::inspector_snapshot(
  self : RuntimeKernel,
) -> InspectorSnapshot {
  InspectorSnapshot::from_runtime(self)
}

///|
pub fn RuntimeKernel::program_runtime_snapshot(
  self : RuntimeKernel,
) -> ProgramRuntimeSnapshot {
  (self.program_runtime_snapshot_fn)()
}

///|
pub fn RuntimeKernel::set_redraw_callback(
  self : RuntimeKernel,
  callback : () -> Unit,
) -> Unit {
  self.state.set_redraw_callback(callback)
}

///|
pub fn RuntimeKernel::set_action_commands(
  self : RuntimeKernel,
  commands : ActionCommandMap,
) -> Unit {
  self.state.set_action_commands(commands)
}

///|
pub fn RuntimeKernel::action_commands(
  self : RuntimeKernel,
) -> Array[ActionCommand] {
  self.state.action_commands()
}

///|
pub fn RuntimeKernel::dispatch_command(
  self : RuntimeKernel,
  intent : CommandIntent,
) -> Bool {
  self.state.dispatch_command(intent)
}

///|
pub fn RuntimeKernel::dispatch_action_command(
  self : RuntimeKernel,
  command : ActionCommand,
) -> Bool {
  self.state.dispatch_action_command(command)
}

///|
pub fn RuntimeKernel::dispatch_focused_text_command(
  self : RuntimeKernel,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  self.state.dispatch_focused_text_command(intent, paste_text~)
}
