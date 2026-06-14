///|
struct RuntimeKernel {
  state : RuntimeState
  mut program_runtime_snapshot_fn : () -> ProgramRuntimeSnapshot
  mut destroy_program_runtime_fn : () -> Unit
}

///|
fn program_message_drain_limit() -> Int {
  1024
}

///|
fn[Msg] compact_pending_program_messages(
  pending_messages : Array[Msg],
  start : Int,
) -> Unit {
  let remaining : Array[Msg] = []
  for index in start..<pending_messages.length() {
    remaining.push(pending_messages[index])
  }
  pending_messages.clear()
  pending_messages.append(remaining)
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
    destroy_program_runtime_fn: () => (),
  }
}

///|
fn RuntimeKernel::new_component(
  root~ : Component,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> RuntimeKernel {
  {
    state: RuntimeState::new_component(root~, size~, environment~),
    program_runtime_snapshot_fn: () => ProgramRuntimeSnapshot::empty(),
    destroy_program_runtime_fn: () => (),
  }
}

///|
fn[Msg] RuntimeKernel::new_component_view(
  root~ : (BuildContext) -> View[Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> RuntimeKernel {
  let emit = match on_message {
    Some(handler) => handler
    None => _message => ()
  }
  RuntimeKernel::new_component(
    root=Component::new(ctx => realize_view(root(ctx), emit)),
    size~,
    environment~,
  )
}

///|
pub fn[Model, Msg] RuntimeKernel::new_program(
  program~ : Program[Model, Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> RuntimeKernel {
  let (initial_model, initial_effect) = (program.init)()
  let model = State::new(initial_model)
  let program_runtime = ProgramRuntimeDiagnostics::new()
  let pending_messages : Array[Msg] = []
  let pending_index = Ref(0)
  let dispatching = Ref(false)
  let syncing_subscriptions = Ref(false)
  let program_active = Ref(true)
  let process_ref : Ref[(() -> Unit)?] = Ref(None)
  let pending_count = () => pending_messages.length() - pending_index.val
  let dispatch = message => {
    if program_active.val {
      pending_messages.push(message)
      program_runtime.record_message_enqueued(pending_count())
      if !syncing_subscriptions.val {
        match process_ref.val {
          Some(process) => process()
          None => ()
        }
      }
    } else {
      program_runtime.record_ignored_program_dispatch()
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
      let mut processed_this_drain = 0
      while pending_index.val < pending_messages.length() &&
            processed_this_drain < program_message_drain_limit() {
        let message = pending_messages[pending_index.val]
        pending_index.val = pending_index.val + 1
        processed_this_drain = processed_this_drain + 1
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
      if pending_index.val < pending_messages.length() {
        compact_pending_program_messages(pending_messages, pending_index.val)
        pending_index.val = 0
        program_runtime.record_message_processed(pending_count())
      } else {
        pending_messages.clear()
        pending_index.val = 0
        program_runtime.record_message_queue_cleared()
      }
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
  let runtime = RuntimeKernel::new_component_view(
    root=ctx => (program.view)(ctx.watch(model), ctx.view_environment()),
    size~,
    environment~,
    on_message=Some(dispatch),
  )
  runtime.program_runtime_snapshot_fn = () => program_runtime.snapshot()
  runtime.destroy_program_runtime_fn = () => {
    if program_active.val {
      program_active.val = false
      program_runtime.cancel_all_effect_tasks(
        EffectTaskCancelReason::EffectTaskRuntimeDestroyed,
      )
      program_runtime.cancel_all_subscriptions(
        SubscriptionCancelReason::SubscriptionRuntimeDestroyed,
      )
    }
  }
  runtime
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
  (self.destroy_program_runtime_fn)()
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
