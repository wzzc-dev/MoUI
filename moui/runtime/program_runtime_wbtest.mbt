///|
fn[Msg] runtime_test_label(text : String) -> @core.View[Msg] {
  @core.View::primitive_text_view(
    text~,
    size=@core.Size::new(width=320.0, height=24.0),
    font=@core.FontSpec::new(size=14.0),
    color=@core.Color::black(),
  )
}

///|
fn has_draw_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
enum RuntimeEffectMsg {
  RuntimeEffectBoot(String)
  RuntimeEffectFinished(String)
}

///|
test "runtime program initial effects run before first view build" {
  let program : @core.Program[String, RuntimeEffectMsg] = @core.Program::new(
    init=() => {
      (
        "booting",
        @core.Effect::batch([
          @core.Effect::send(RuntimeEffectBoot("sent")),
          @core.Effect::dispatch(dispatch => {
            dispatch(RuntimeEffectFinished("dispatched"))
          }),
        ]),
      )
    },
    update=(model, message) => {
      match message {
        RuntimeEffectBoot(value) => ("\{model}+\{value}", @core.Effect::none())
        RuntimeEffectFinished(value) =>
          ("\{model}+\{value}", @core.Effect::none())
      }
    },
    view=model => runtime_test_label("Boot " + model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=220.0, height=72.0),
  )
  assert_true(
    has_draw_text(runtime.draw_commands(), "Boot booting+sent+dispatched"),
  )
  let snapshot = runtime.program_runtime_snapshot()
  inspect(snapshot.dispatched_count, content="2")
  inspect(snapshot.update_count, content="2")
  inspect(snapshot.message_enqueue_count, content="2")
  inspect(snapshot.message_drain_count, content="2")
  inspect(snapshot.pending_message_count, content="0")
  inspect(snapshot.effect_plan_count, content="3")
  inspect(snapshot.effect_count, content="2")
  inspect(snapshot.effect_batch_count, content="1")
  inspect(snapshot.effect_send_count, content="1")
  inspect(snapshot.effect_dispatch_count, content="1")
  assert_true(
    snapshot.last_scheduled_effect_summary.root_kind ==
    @core.EffectPlanKind::EffectPlanBatch,
  )
}

///|
enum RuntimeTaskMsg {
  RuntimeTaskFinished(String)
}

///|
test "runtime program effect tasks complete and ignore stale dispatches" {
  let task_dispatch : Ref[((RuntimeTaskMsg) -> Unit)?] = Ref(None)
  let cleanup_count = Ref(0)
  let program : @core.Program[String, RuntimeTaskMsg] = @core.Program::new(
    init=() => {
      (
        "pending",
        @core.Effect::service_task(key="task:load", label="Load task", start=dispatch => {
          task_dispatch.val = Some(dispatch)
          Some(() => cleanup_count.val = cleanup_count.val + 1)
        }),
      )
    },
    update=(_model, message) => {
      match message {
        RuntimeTaskFinished(value) => (value, @core.Effect::none())
      }
    },
    view=model => runtime_test_label(model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "pending"))
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.effect_task_count, content="1")
  inspect(initial.active_effect_task_count, content="1")
  inspect(initial.started_effect_task_count, content="1")
  inspect(initial.active_effect_tasks[0].key(), content="task:load")
  inspect(initial.active_effect_tasks[0].kind(), content="service")
  match task_dispatch.val {
    Some(dispatch) => dispatch(RuntimeTaskFinished("done"))
    None => fail("expected task dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "done"))
  let completed = runtime.program_runtime_snapshot()
  inspect(completed.dispatched_count, content="1")
  inspect(completed.update_count, content="1")
  inspect(completed.active_effect_task_count, content="0")
  inspect(completed.completed_effect_task_count, content="1")
  inspect(cleanup_count.val, content="0")
  assert_true(
    completed.effect_task_lifecycle.any(entry => {
      entry.key == "task:load" &&
      entry.status == @core.EffectTaskLifecycleStatus::EffectTaskCompleted
    }),
  )
  match task_dispatch.val {
    Some(dispatch) => dispatch(RuntimeTaskFinished("late"))
    None => fail("expected stale task dispatch")
  }
  inspect(
    runtime.program_runtime_snapshot().ignored_effect_task_dispatch_count,
    content="1",
  )
}

///|
enum RuntimeSubscriptionMsg {
  RuntimeSubscriptionToggle
  RuntimeSubscriptionTick
}

///|
struct RuntimeSubscriptionModel {
  channel : String
  ticks : Int
}

///|
test "runtime program subscriptions start reuse cancel and dispatch typed messages" {
  let alpha_dispatch : Ref[((RuntimeSubscriptionMsg) -> Unit)?] = Ref(None)
  let beta_dispatch : Ref[((RuntimeSubscriptionMsg) -> Unit)?] = Ref(None)
  let cleanup_log : Array[String] = []
  let program : @core.Program[RuntimeSubscriptionModel, RuntimeSubscriptionMsg] = @core.Program::new(
    init=() => ({ channel: "alpha", ticks: 0 }, @core.Effect::none()),
    update=(model, message) => {
      match message {
        RuntimeSubscriptionTick =>
          ({ ..model, ticks: model.ticks + 1 }, @core.Effect::none())
        RuntimeSubscriptionToggle =>
          (
            {
              ..model,
              channel: if model.channel == "alpha" {
                "beta"
              } else {
                "alpha"
              },
            },
            @core.Effect::none(),
          )
      }
    },
    view=model => runtime_test_label("\{model.channel}:\{model.ticks}"),
    subscriptions=model => {
      @core.Subscription::timer(
        key="timer:\{model.channel}",
        label=model.channel,
        start=dispatch => {
          if model.channel == "alpha" {
            alpha_dispatch.val = Some(dispatch)
          } else {
            beta_dispatch.val = Some(dispatch)
          }
          Some(() => cleanup_log.push(model.channel))
        },
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "alpha:0"))
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.subscription_plan_count, content="1")
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.started_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key(), content="timer:alpha")
  inspect(
    runtime.inspector_snapshot().runtime.program_subscription_plan_count,
    content="1",
  )
  match alpha_dispatch.val {
    Some(dispatch) => dispatch(RuntimeSubscriptionTick)
    None => fail("expected alpha subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "alpha:1"))
  inspect(
    runtime.program_runtime_snapshot().reused_subscription_count,
    content="1",
  )
  match alpha_dispatch.val {
    Some(dispatch) => dispatch(RuntimeSubscriptionToggle)
    None => fail("expected alpha subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "beta:1"))
  let switched = runtime.program_runtime_snapshot()
  inspect(switched.started_subscription_count, content="2")
  inspect(switched.cancelled_subscription_count, content="1")
  inspect(cleanup_log.join(","), content="alpha")
  match alpha_dispatch.val {
    Some(dispatch) => dispatch(RuntimeSubscriptionTick)
    None => fail("expected stale alpha subscription dispatch")
  }
  inspect(
    runtime.program_runtime_snapshot().ignored_subscription_dispatch_count,
    content="1",
  )
  runtime.destroy()
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count, content="2")
  inspect(cleanup_log.join(","), content="alpha,beta")
}
