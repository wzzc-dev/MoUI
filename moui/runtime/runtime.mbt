///|
pub struct AppRuntime {
  priv state : RuntimeState
  priv program_runtime_snapshot_fn : () -> ProgramRuntimeSnapshot
  priv destroy_program_runtime_fn : Ref[() -> Unit]
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
fn[Msg] run_effect(
  effect : @core.Effect[Msg],
  dispatch : (Msg) -> Unit,
  start_task : (@core.EffectDescriptor, ((Msg) -> Unit) -> (() -> Unit)?) -> Unit,
) -> Int {
  let mut count = 0
  for op in effect.runtime_ops() {
    op.runtime_visit(
      dispatch,
      run => run(dispatch),
      (_descriptor, run) => run(dispatch),
      start_task,
    )
    count = count + 1
  }
  count
}

///|
pub fn[Msg] AppRuntime::new_view(
  root~ : @core.View[Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> AppRuntime {
  AppRuntime::{
    state: RuntimeState::new_view(root~, size~, environment~, on_message~),
    program_runtime_snapshot_fn: () => program_runtime_snapshot_empty(),
    destroy_program_runtime_fn: Ref(() => ()),
  }
}

///|
pub fn[Model, Msg] AppRuntime::new_program(
  program~ : @core.Program[Model, Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
) -> AppRuntime {
  let (initial_model, initial_effect) = program.runtime_init()
  let model = @core.State::new(initial_model)
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
      program.runtime_subscriptions(model.get()),
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
        let (next_model, effect) = program.runtime_update(model.get(), message)
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
  let runtime = AppRuntime::{
    state: RuntimeState::new_view(
      root=runtime_component_view(ctx => {
        program.runtime_view(ctx.watch(model), ctx.view_environment())
      }),
      size~,
      environment~,
      on_message=Some(dispatch),
    ),
    program_runtime_snapshot_fn: () => program_runtime.snapshot(),
    destroy_program_runtime_fn: Ref(() => ()),
  }
  runtime.destroy_program_runtime_fn.val = () => {
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
fn[Msg] runtime_component_view(
  build : (@core.BuildContext) -> @core.View[Msg],
) -> @core.View[Msg] {
  @core.View::widget(
    @core.WidgetOps::new(
      identity=() => @core.WidgetIdentity::new(kind="Component"),
      revision=() => "component",
      build_child=Some(build),
      layout=ctx => {
        let child_size = if ctx.child_sizes.length() > 0 {
          ctx.child_sizes[0]
        } else {
          @core.Size::new(width=0.0, height=0.0)
        }
        @core.WidgetLayoutResult::new(
          size=ctx.constraints.constrain(child_size),
          child_frames=if ctx.child_sizes.length() > 0 {
            [
              @core.Rect::new(
                x=0.0,
                y=0.0,
                width=child_size.width,
                height=child_size.height,
              ),
            ]
          } else {
            []
          },
        )
      },
    ),
  )
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
pub fn[Model, Msg] new_program_with_dimensions(
  program~ : @core.Program[Model, Msg],
  width~ : Double,
  height~ : Double,
  environment? : @core.Environment = @core.Environment::default(),
) -> AppRuntime {
  AppRuntime::new_program(
    program~,
    size=@core.Size::new(width~, height~),
    environment~,
  )
}

///|
pub fn AppRuntime::dispatch_event(
  self : AppRuntime,
  event : @core.AppEvent,
) -> Unit {
  self.state.dispatch_event(event)
}

///|
pub fn AppRuntime::environment(self : AppRuntime) -> @core.Environment {
  self.state.environment()
}

///|
pub fn AppRuntime::text_system(self : AppRuntime) -> @core.TextSystem {
  self.state.text_system()
}

///|
pub fn AppRuntime::set_text_system(
  self : AppRuntime,
  text_system : @core.TextSystem,
) -> Unit {
  self.state.set_text_system(text_system)
}

///|
pub fn AppRuntime::register_font_data(
  self : AppRuntime,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  self.state.register_font_data(family, data)
}

///|
pub fn AppRuntime::set_environment(
  self : AppRuntime,
  environment : @core.Environment,
) -> Unit {
  self.state.set_environment(environment)
}

///|
pub fn AppRuntime::advance_time(self : AppRuntime, time_ms : Double) -> Unit {
  self.state.advance_time(time_ms)
}

///|
pub fn AppRuntime::destroy(self : AppRuntime) -> Unit {
  (self.destroy_program_runtime_fn.val)()
  self.state.destroy()
}

///|
pub fn AppRuntime::layout(self : AppRuntime) -> @core.LayoutResult {
  self.state.layout()
}

///|
pub fn AppRuntime::semantics(self : AppRuntime) -> @core.SemanticsNode {
  self.state.semantics()
}

///|
pub fn AppRuntime::focused_text_input(
  self : AppRuntime,
) -> @core.TextInputState {
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
pub fn AppRuntime::draw_commands(self : AppRuntime) -> Array[@core.DrawCommand] {
  self.state.build_draw_commands()
}

///|
pub fn AppRuntime::draw_frame(self : AppRuntime) -> @core.DrawFrame {
  self.state.build_draw_frame()
}

///|
pub fn AppRuntime::invalidate_cached_layer_key(
  self : AppRuntime,
  key : String,
) -> Unit {
  self.state.invalidate_cached_layer_key(key)
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

///|
pub fn AppRuntime::dirty_count(self : AppRuntime) -> Int {
  self.state.dirty_count()
}

///|
pub fn AppRuntime::dirty_element_ids(
  self : AppRuntime,
) -> Array[@core.ElementId] {
  self.state.dirty_element_ids()
}

///|
pub fn AppRuntime::inspector_snapshot(self : AppRuntime) -> InspectorSnapshot {
  self.inspector_snapshot_from_state()
}

///|
pub fn AppRuntime::program_runtime_snapshot(
  self : AppRuntime,
) -> ProgramRuntimeSnapshot {
  (self.program_runtime_snapshot_fn)()
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
  commands : @core.ActionCommandMap,
) -> Unit {
  self.state.set_action_commands(commands)
}

///|
/// Installs an observer invoked with every `AppEvent` before it is processed.
/// Replaces any previously installed observer. Passing a no-op effectively
/// disables observation. This is the additive hook the agent layer consumes;
/// it is inert unless explicitly called.
pub fn AppRuntime::set_event_observer(
  self : AppRuntime,
  observer : (@core.AppEvent) -> Unit,
) -> Unit {
  self.state.event_observer = observer
}

///|
pub fn AppRuntime::action_commands(
  self : AppRuntime,
) -> Array[@core.ActionCommand] {
  self.state.action_commands()
}

///|
pub fn AppRuntime::dispatch_command(
  self : AppRuntime,
  intent : @core.CommandIntent,
) -> Bool {
  self.state.dispatch_command(intent)
}

///|
pub fn AppRuntime::dispatch_action_command(
  self : AppRuntime,
  command : @core.ActionCommand,
) -> Bool {
  self.state.dispatch_action_command(command)
}

///|
pub fn AppRuntime::dispatch_focused_text_command(
  self : AppRuntime,
  intent : @core.CommandIntent,
  paste_text? : String? = None,
) -> @core.TextCommandResult {
  self.state.dispatch_focused_text_command(intent, paste_text~)
}
