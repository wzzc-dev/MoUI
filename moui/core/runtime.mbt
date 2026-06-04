///|
pub struct AppRuntime {
  state : RuntimeState
  priv mut program_runtime_snapshot_fn : () -> ProgramRuntimeSnapshot
  priv mut destroy_program_runtime_fn : () -> Unit
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
    program_runtime_snapshot_fn: () => ProgramRuntimeSnapshot::empty(),
    destroy_program_runtime_fn: () => (),
  }
}

///|
fn AppRuntime::new_component(
  root~ : Component,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  {
    state: RuntimeState::new_component(root~, size~, environment~),
    program_runtime_snapshot_fn: () => ProgramRuntimeSnapshot::empty(),
    destroy_program_runtime_fn: () => (),
  }
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
  let program_runtime = ProgramRuntimeDiagnostics::new()
  let pending_messages : Array[Msg] = []
  let pending_index = Ref(0)
  let dispatching = Ref(false)
  let syncing_subscriptions = Ref(false)
  let process_ref : Ref[(() -> Unit)?] = Ref(None)
  let pending_count = () => pending_messages.length() - pending_index.val
  let dispatch = message => {
    pending_messages.push(message)
    program_runtime.record_message_enqueued(pending_count())
    if !syncing_subscriptions.val {
      match process_ref.val {
        Some(process) => process()
        None => ()
      }
    }
  }
  let sync_subscriptions = () => {
    syncing_subscriptions.val = true
    program_runtime.sync_subscriptions(
      (program.subscriptions)(model.get()),
      dispatch,
    )
    syncing_subscriptions.val = false
  }
  let process_messages = () => {
    if !dispatching.val && !syncing_subscriptions.val {
      program_runtime.record_message_drain_started(pending_count())
      dispatching.val = true
      while pending_index.val < pending_messages.length() {
        let message = pending_messages[pending_index.val]
        pending_index.val = pending_index.val + 1
        program_runtime.record_dispatch()
        let (next_model, effect) = (program.update)(model.get(), message)
        program_runtime.record_update()
        model.set(next_model)
        let effect_summary = effect.plan_summary()
        let effect_count = run_effect(effect, dispatch, (descriptor, start) => {
          program_runtime.start_effect_task(descriptor, start, dispatch)
        })
        program_runtime.record_effects(effect_summary, effect_count)
        sync_subscriptions()
        program_runtime.record_message_processed(pending_count())
      }
      pending_messages.clear()
      pending_index.val = 0
      program_runtime.record_message_queue_cleared()
      dispatching.val = false
    }
  }
  process_ref.val = Some(process_messages)
  let initial_effect_summary = initial_effect.plan_summary()
  let initial_effect_count = run_effect(initial_effect, dispatch, (
    descriptor,
    start,
  ) => program_runtime.start_effect_task(descriptor, start, dispatch))
  program_runtime.record_effects(initial_effect_summary, initial_effect_count)
  sync_subscriptions()
  match process_ref.val {
    Some(process) => process()
    None => ()
  }
  let runtime = AppRuntime::new_component_view(
    root=ctx => (program.view)(ctx.watch(model), ctx.view_environment()),
    size~,
    environment~,
    on_message=Some(dispatch),
  )
  runtime.program_runtime_snapshot_fn = () => program_runtime.snapshot()
  runtime.destroy_program_runtime_fn = () => {
    program_runtime.cancel_all_effect_tasks(
      EffectTaskCancelReason::EffectTaskRuntimeDestroyed,
    )
    program_runtime.cancel_all_subscriptions(
      SubscriptionCancelReason::SubscriptionRuntimeDestroyed,
    )
  }
  runtime
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
  (self.destroy_program_runtime_fn)()
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
pub fn AppRuntime::dirty_element_ids(self : AppRuntime) -> Array[ElementId] {
  self.state.dirty_element_ids()
}

///|
pub fn AppRuntime::inspector_snapshot(self : AppRuntime) -> InspectorSnapshot {
  InspectorSnapshot::from_runtime(self)
}

///|
pub fn AppRuntime::program_runtime_snapshot(
  self : AppRuntime,
) -> ProgramRuntimeSnapshot {
  (self.program_runtime_snapshot_fn)()
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
