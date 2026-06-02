///|
pub struct AppRuntime {
  state : RuntimeState
}

///|
pub fn[Msg] AppRuntime::new_view(
  root~ : View[Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> AppRuntime {
  let emit = match on_message {
    Some(handler) => handler
    None => _message => ()
  }
  {
    state: RuntimeState::new_spec(
      root=realize_view(root, emit),
      size~,
      environment~,
    ),
  }
}

///|
fn AppRuntime::new_component(
  root~ : Component,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  { state: RuntimeState::new_component(root~, size~, environment~) }
}

///|
fn[Msg] AppRuntime::new_component_view(
  root~ : (BuildContext) -> View[Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> AppRuntime {
  let emit = match on_message {
    Some(handler) => handler
    None => _message => ()
  }
  AppRuntime::new_component(
    root=Component::new(ctx => realize_view(root(ctx), emit)),
    size~,
    environment~,
  )
}

///|
pub fn[Model, Msg] AppRuntime::new_program(
  program~ : Program[Model, Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  let (initial_model, initial_effect) = (program.init)()
  let model = State::new(initial_model)
  let dispatch_ref : Ref[((Msg) -> Unit)?] = Ref(None)
  let dispatch = message => {
    let (next_model, effect) = (program.update)(model.get(), message)
    model.set(next_model)
    run_effect(effect, message => {
      match dispatch_ref.val {
        Some(dispatch) => dispatch(message)
        None => ()
      }
    })
  }
  dispatch_ref.val = Some(dispatch)
  run_effect(initial_effect, dispatch)
  AppRuntime::new_component_view(
    root=ctx => (program.view)(ctx.watch(model), ctx.view_environment()),
    size~,
    environment~,
    on_message=Some(dispatch),
  )
}

///|
pub fn AppRuntime::dispatch_event(self : AppRuntime, event : AppEvent) -> Unit {
  self.state.dispatch_event(event)
}

///|
pub fn AppRuntime::environment(self : AppRuntime) -> Environment {
  self.state.environment()
}

///|
pub fn AppRuntime::text_system(self : AppRuntime) -> TextSystem {
  self.state.text_system()
}

///|
pub fn AppRuntime::set_text_system(
  self : AppRuntime,
  text_system : TextSystem,
) -> Unit {
  self.state.set_text_system(text_system)
}

///|
pub fn AppRuntime::register_font_data(
  self : AppRuntime,
  family : FontFamily,
  data : Bytes,
) -> Unit {
  self.state.register_font_data(family, data)
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
fn AppRuntime::layout_tree_root(self : AppRuntime) -> PlacedNode {
  self.state.layout_tree_root()
}

///|
fn AppRuntime::view_tree_inspector_snapshot(
  self : AppRuntime,
) -> ViewTreeInspectorSnapshot {
  self.state.view_tree_inspector_snapshot()
}

///|
fn AppRuntime::inspector_rebuild_reason(self : AppRuntime) -> String {
  self.state.inspector_rebuild_reason()
}

///|
fn AppRuntime::inspector_dirty_reasons(self : AppRuntime) -> Array[String] {
  self.state.inspector_dirty_reasons()
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
pub fn AppRuntime::focus_key(self : AppRuntime, key : String) -> Bool {
  self.state.focus_key(key)
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
pub fn AppRuntime::inspector_snapshot(self : AppRuntime) -> InspectorSnapshot {
  InspectorSnapshot::from_runtime(self)
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

///|
pub fn AppRuntime::dispatch_focused_text_command(
  self : AppRuntime,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  self.state.dispatch_focused_text_command(intent, paste_text~)
}
