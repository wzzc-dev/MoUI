///|
pub struct AppRuntime {
  priv inner : @core.AppRuntime
}

///|
pub fn[Msg] AppRuntime::new_view(
  root~ : @core.View[Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> AppRuntime {
  AppRuntime::{
    inner: @core.AppRuntime::new_view(root~, size~, environment~, on_message~),
  }
}

///|
pub fn[Model, Msg] AppRuntime::new_program(
  program~ : @core.Program[Model, Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
) -> AppRuntime {
  AppRuntime::{
    inner: @core.AppRuntime::new_program(program~, size~, environment~),
  }
}

///|
pub fn[Msg] new_view(
  root~ : @core.View[Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> AppRuntime {
  AppRuntime::new_view(root~, size~, environment~, on_message~)
}

///|
pub fn[Model, Msg] new_program(
  program~ : @core.Program[Model, Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
) -> AppRuntime {
  AppRuntime::new_program(program~, size~, environment~)
}

///|
pub fn AppRuntime::dispatch_event(
  self : AppRuntime,
  event : @core.AppEvent,
) -> Unit {
  self.inner.dispatch_event(event)
}

///|
pub fn AppRuntime::environment(self : AppRuntime) -> @core.Environment {
  self.inner.environment()
}

///|
pub fn AppRuntime::text_system(self : AppRuntime) -> @core.TextSystem {
  self.inner.text_system()
}

///|
pub fn AppRuntime::set_text_system(
  self : AppRuntime,
  text_system : @core.TextSystem,
) -> Unit {
  self.inner.set_text_system(text_system)
}

///|
pub fn AppRuntime::register_font_data(
  self : AppRuntime,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  self.inner.register_font_data(family, data)
}

///|
pub fn AppRuntime::set_environment(
  self : AppRuntime,
  environment : @core.Environment,
) -> Unit {
  self.inner.set_environment(environment)
}

///|
pub fn AppRuntime::add_animation(
  self : AppRuntime,
  controller : @core.AnimationController,
) -> Unit {
  self.inner.add_animation(controller)
}

///|
pub fn AppRuntime::advance_time(self : AppRuntime, time_ms : Double) -> Unit {
  self.inner.advance_time(time_ms)
}

///|
pub fn AppRuntime::destroy(self : AppRuntime) -> Unit {
  self.inner.destroy()
}

///|
pub fn AppRuntime::rebuild(self : AppRuntime) -> Unit {
  self.inner.rebuild()
}

///|
pub fn AppRuntime::layout_pass(self : AppRuntime) -> Unit {
  self.inner.layout_pass()
}

///|
pub fn AppRuntime::layout(self : AppRuntime) -> @core.LayoutResult {
  self.inner.layout()
}

///|
pub fn AppRuntime::paint_pass(self : AppRuntime) -> Array[@core.DrawCommand] {
  self.inner.paint_pass()
}

///|
pub fn AppRuntime::semantics(self : AppRuntime) -> @core.SemanticsNode {
  self.inner.semantics()
}

///|
pub fn AppRuntime::focused_text_input(
  self : AppRuntime,
) -> @core.TextInputState {
  self.inner.focused_text_input()
}

///|
pub fn AppRuntime::focus_next(self : AppRuntime) -> Bool {
  self.inner.focus_next()
}

///|
pub fn AppRuntime::focus_previous(self : AppRuntime) -> Bool {
  self.inner.focus_previous()
}

///|
pub fn AppRuntime::focus_key(self : AppRuntime, key : String) -> Bool {
  self.inner.focus_key(key)
}

///|
pub fn AppRuntime::restore_route_focus(
  self : AppRuntime,
  store : @core.RouteFocusStore,
  route : String,
) -> Bool {
  match store.focus_key(route) {
    Some(key) => self.focus_key(key)
    None => false
  }
}

///|
pub fn AppRuntime::restore_location_focus(
  self : AppRuntime,
  store : @core.RouteFocusStore,
  location : @core.RouteLocation,
) -> Bool {
  match store.focus_key_for_location(location) {
    Some(key) => self.focus_key(key)
    None => false
  }
}

///|
pub fn AppRuntime::draw_commands(self : AppRuntime) -> Array[@core.DrawCommand] {
  self.inner.draw_commands()
}

///|
pub fn AppRuntime::draw_frame(self : AppRuntime) -> @core.DrawFrame {
  self.inner.draw_frame()
}

///|
pub fn AppRuntime::invalidate_cached_layer_key(
  self : AppRuntime,
  key : String,
) -> Unit {
  self.inner.invalidate_cached_layer_key(key)
}

///|
pub fn AppRuntime::size(self : AppRuntime) -> @core.Size {
  self.inner.size()
}

///|
pub fn AppRuntime::needs_redraw(self : AppRuntime) -> Bool {
  self.inner.needs_redraw()
}

///|
pub fn AppRuntime::needs_rebuild(self : AppRuntime) -> Bool {
  self.inner.needs_rebuild()
}

///|
pub fn AppRuntime::needs_layout(self : AppRuntime) -> Bool {
  self.inner.needs_layout()
}

///|
pub fn AppRuntime::needs_paint(self : AppRuntime) -> Bool {
  self.inner.needs_paint()
}

///|
pub fn AppRuntime::dirty_count(self : AppRuntime) -> Int {
  self.inner.dirty_count()
}

///|
pub fn AppRuntime::dirty_element_ids(
  self : AppRuntime,
) -> Array[@core.ElementId] {
  self.inner.dirty_element_ids()
}

///|
pub fn AppRuntime::inspector_snapshot(
  self : AppRuntime,
) -> @core.InspectorSnapshot {
  self.inner.inspector_snapshot()
}

///|
pub fn AppRuntime::program_runtime_snapshot(
  self : AppRuntime,
) -> @core.ProgramRuntimeSnapshot {
  self.inner.program_runtime_snapshot()
}

///|
pub fn AppRuntime::animation_count(self : AppRuntime) -> Int {
  self.inner.animation_count()
}

///|
pub fn AppRuntime::set_redraw_callback(
  self : AppRuntime,
  callback : () -> Unit,
) -> Unit {
  self.inner.set_redraw_callback(callback)
}

///|
pub fn AppRuntime::set_action_commands(
  self : AppRuntime,
  commands : @core.ActionCommandMap,
) -> Unit {
  self.inner.set_action_commands(commands)
}

///|
pub fn AppRuntime::action_commands(
  self : AppRuntime,
) -> Array[@core.ActionCommand] {
  self.inner.action_commands()
}

///|
pub fn AppRuntime::dispatch_command(
  self : AppRuntime,
  intent : @core.CommandIntent,
) -> Bool {
  self.inner.dispatch_command(intent)
}

///|
pub fn AppRuntime::dispatch_action_command(
  self : AppRuntime,
  command : @core.ActionCommand,
) -> Bool {
  self.inner.dispatch_action_command(command)
}

///|
pub fn AppRuntime::dispatch_focused_text_command(
  self : AppRuntime,
  intent : @core.CommandIntent,
  paste_text? : String? = None,
) -> @core.TextCommandResult {
  self.inner.dispatch_focused_text_command(intent, paste_text~)
}
