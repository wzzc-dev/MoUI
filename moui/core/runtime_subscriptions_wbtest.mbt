///|
enum ProgramSubscriptionMsg {
  ProgramSubscriptionToggle
  ProgramSubscriptionTick
}

///|
enum ProgramSubscriptionLoopMsg {
  ProgramSubscriptionLoopPulse
}

///|
enum ProgramSubscriptionTurnResumeMsg {
  ProgramSubscriptionTurnResumePulse
  ProgramSubscriptionTurnResumeHostCallback
}

///|
struct ProgramSubscriptionTurnResumeModel {
  pulses : Int
  host_seen_at : Int
}

///|
struct ProgramSubscriptionModel {
  channel : String
  ticks : Int
}

///|
enum ProgramSubscriptionKindMsg {
  ProgramSubscriptionKindToggle
  ProgramSubscriptionKindPulse
}

///|
struct ProgramSubscriptionKindModel {
  use_host : Bool
  pulses : Int
}

///|
test "program subscriptions start reuse cancel and dispatch typed messages" {
  let alpha_dispatch : Ref[((ProgramSubscriptionMsg) -> Unit)?] = Ref(None)
  let beta_dispatch : Ref[((ProgramSubscriptionMsg) -> Unit)?] = Ref(None)
  let cleanup_log : Array[String] = []
  let program = Program::new(
    init=() => ({ channel: "alpha", ticks: 0 }, Effect::none()),
    update=(model, message) => {
      match message {
        ProgramSubscriptionTick =>
          ({ ..model, ticks: model.ticks + 1 }, Effect::none())
        ProgramSubscriptionToggle =>
          (
            {
              ..model,
              channel: if model.channel == "alpha" {
                "beta"
              } else {
                "alpha"
              },
            },
            Effect::none(),
          )
      }
    },
    view=model => runtime_test_label("\{model.channel}:\{model.ticks}"),
    subscriptions=model => {
      Subscription::timer(key="timer:\{model.channel}", label=model.channel, start=dispatch => {
        if model.channel == "alpha" {
          alpha_dispatch.val = Some(dispatch)
        } else {
          beta_dispatch.val = Some(dispatch)
        }
        Some(() => cleanup_log.push(model.channel))
      })
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "alpha:0"))
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.subscription_plan_count, content="1")
  assert_true(
    initial.last_subscription_plan_summary.root_kind ==
    SubscriptionPlanKind::SubscriptionPlanSource,
  )
  inspect(initial.last_subscription_plan_summary.source_count, content="1")
  inspect(
    initial.last_subscription_plan_summary.descriptors.length(),
    content="1",
  )
  inspect(
    initial.last_subscription_plan_summary.descriptors[0].key,
    content="timer:alpha",
  )
  inspect(
    initial.last_subscription_plan_summary.descriptors[0].kind,
    content="timer",
  )
  inspect(
    initial.last_subscription_plan_summary.descriptors[0].label,
    content="alpha",
  )
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.started_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key, content="timer:alpha")
  match alpha_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionTick)
    None => fail("expected alpha subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "alpha:1"))
  let reused = runtime.program_runtime_snapshot()
  inspect(reused.dispatched_count, content="1")
  inspect(reused.update_count, content="1")
  inspect(reused.reused_subscription_count, content="1")
  match alpha_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionToggle)
    None => fail("expected alpha subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "beta:1"))
  let switched = runtime.program_runtime_snapshot()
  inspect(switched.active_subscription_count, content="1")
  inspect(switched.dispatched_count, content="2")
  inspect(switched.started_subscription_count, content="2")
  inspect(switched.cancelled_subscription_count, content="1")
  inspect(cleanup_log.join(","), content="alpha")
  match alpha_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionTick)
    None => fail("expected stale alpha subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "beta:1"))
  let after_stale_alpha = runtime.program_runtime_snapshot()
  inspect(after_stale_alpha.dispatched_count, content="2")
  inspect(after_stale_alpha.update_count, content="2")
  inspect(after_stale_alpha.ignored_subscription_dispatch_count, content="1")
  match beta_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionTick)
    None => fail("expected beta subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "beta:2"))
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_dispatched_count, content="3")
  inspect(inspector.program_update_count, content="3")
  inspect(inspector.active_subscription_count, content="1")
  inspect(inspector.reused_subscription_count, content="2")
  inspect(inspector.duplicate_subscription_key_count, content="0")
  inspect(inspector.ignored_subscription_dispatch_count, content="1")
  inspect(inspector.active_subscriptions.length(), content="1")
  inspect(inspector.active_subscriptions[0].key, content="timer:beta")
  inspect(inspector.active_subscriptions[0].kind, content="timer")
  inspect(inspector.active_subscriptions[0].label, content="beta")
  assert_true(
    inspector.subscription_lifecycle.any(entry => {
      entry.key == "timer:alpha" &&
      entry.status == SubscriptionLifecycleStatus::SubscriptionCancelled &&
      entry.cancel_reason ==
      Some(SubscriptionCancelReason::SubscriptionKeyChanged)
    }),
  )
  runtime.destroy()
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.active_subscription_count, content="0")
  inspect(destroyed.cancelled_subscription_count, content="2")
  inspect(cleanup_log.join(","), content="alpha,beta")
  assert_true(
    destroyed.subscription_lifecycle.any(entry => {
      entry.key == "timer:beta" &&
      entry.status == SubscriptionLifecycleStatus::SubscriptionCancelled &&
      entry.cancel_reason ==
      Some(SubscriptionCancelReason::SubscriptionRuntimeDestroyed)
    }),
  )
  match beta_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionTick)
    None => fail("expected stale beta subscription dispatch")
  }
  let after_destroy_dispatch = runtime.program_runtime_snapshot()
  inspect(after_destroy_dispatch.dispatched_count, content="3")
  inspect(after_destroy_dispatch.update_count, content="3")
  inspect(
    after_destroy_dispatch.ignored_subscription_dispatch_count,
    content="2",
  )
  inspect(cleanup_log.join(","), content="alpha,beta")
}

///|
test "program subscriptions restart when source kind changes under same key" {
  let timer_dispatch : Ref[((ProgramSubscriptionKindMsg) -> Unit)?] = Ref(None)
  let host_dispatch : Ref[((ProgramSubscriptionKindMsg) -> Unit)?] = Ref(None)
  let cleanup_log : Array[String] = []
  let program = Program::new(
    init=() => ({ use_host: false, pulses: 0 }, Effect::none()),
    update=(model, message) => {
      match message {
        ProgramSubscriptionKindToggle =>
          ({ ..model, use_host: !model.use_host }, Effect::none())
        ProgramSubscriptionKindPulse =>
          ({ ..model, pulses: model.pulses + 1 }, Effect::none())
      }
    },
    view=model => {
      runtime_test_label(
        if model.use_host {
          "host:\{model.pulses}"
        } else {
          "timer:\{model.pulses}"
        },
      )
    },
    subscriptions=model => {
      if model.use_host {
        Subscription::host_event(key="shared-source", label="Host source", start=dispatch => {
          host_dispatch.val = Some(dispatch)
          Some(() => cleanup_log.push("host"))
        })
      } else {
        Subscription::timer(key="shared-source", label="Timer source", start=dispatch => {
          timer_dispatch.val = Some(dispatch)
          Some(() => cleanup_log.push("timer"))
        })
      }
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "timer:0"))
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscriptions[0].kind, content="timer")
  match timer_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionKindToggle)
    None => fail("expected timer subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "host:0"))
  let switched = runtime.program_runtime_snapshot()
  inspect(switched.started_subscription_count, content="2")
  inspect(switched.reused_subscription_count, content="0")
  inspect(switched.cancelled_subscription_count, content="1")
  inspect(switched.active_subscription_count, content="1")
  inspect(switched.active_subscriptions[0].key, content="shared-source")
  inspect(switched.active_subscriptions[0].kind, content="host-event")
  inspect(cleanup_log.join(","), content="timer")
  assert_true(
    switched.subscription_lifecycle.any(entry => {
      entry.key == "shared-source" &&
      entry.kind == "timer" &&
      entry.status == SubscriptionLifecycleStatus::SubscriptionCancelled &&
      entry.cancel_reason ==
      Some(SubscriptionCancelReason::SubscriptionKindChanged)
    }),
  )
  match timer_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionKindPulse)
    None => fail("expected stale timer subscription dispatch")
  }
  let after_stale_timer = runtime.program_runtime_snapshot()
  inspect(after_stale_timer.ignored_subscription_dispatch_count, content="1")
  assert_true(has_draw_text(runtime.draw_commands(), "host:0"))
  match host_dispatch.val {
    Some(dispatch) => dispatch(ProgramSubscriptionKindPulse)
    None => fail("expected host subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "host:1"))
}

///|
test "program subscriptions queue synchronous start dispatch and report duplicate keys" {
  let start_count = Ref(0)
  let program = Program::new(
    init=() => ({ channel: "instant", ticks: 0 }, Effect::none()),
    update=(model, message) => {
      match message {
        ProgramSubscriptionTick =>
          ({ ..model, ticks: model.ticks + 1 }, Effect::none())
        ProgramSubscriptionToggle => (model, Effect::none())
      }
    },
    view=model => runtime_test_label("\{model.channel}:\{model.ticks}"),
    subscriptions=_model => {
      Subscription::batch([
        Subscription::timer(key="instant", label="Instant", start=dispatch => {
          start_count.val = start_count.val + 1
          dispatch(ProgramSubscriptionTick)
          None
        }),
        Subscription::timer(key="instant", label="Duplicate ignored", start=_dispatch => {
          start_count.val = start_count.val + 1
          None
        }),
      ])
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "instant:1"))
  let snapshot = runtime.program_runtime_snapshot()
  inspect(start_count.val, content="1")
  inspect(snapshot.message_enqueue_count, content="1")
  inspect(snapshot.message_drain_count, content="1")
  inspect(snapshot.pending_message_count, content="0")
  inspect(snapshot.max_pending_message_count, content="1")
  inspect(snapshot.subscription_plan_count, content="2")
  inspect(snapshot.last_subscription_plan_summary.source_count, content="2")
  inspect(
    snapshot.last_subscription_plan_summary.descriptors.length(),
    content="2",
  )
  inspect(
    snapshot.last_subscription_plan_summary.descriptors[0].label,
    content="Instant",
  )
  inspect(
    snapshot.last_subscription_plan_summary.descriptors[1].label,
    content="Duplicate ignored",
  )
  inspect(
    snapshot.last_subscription_plan_summary.duplicate_key_count,
    content="1",
  )
  inspect(
    snapshot.last_subscription_plan_summary.duplicate_keys[0],
    content="instant",
  )
  inspect(snapshot.started_subscription_count, content="1")
  inspect(snapshot.reused_subscription_count, content="1")
  inspect(snapshot.duplicate_subscription_key_count, content="2")
  inspect(snapshot.duplicate_subscription_keys.length(), content="1")
  inspect(snapshot.duplicate_subscription_keys[0], content="instant")
  inspect(snapshot.active_subscription_count, content="1")
  inspect(snapshot.active_subscriptions[0].label, content="Instant")
  inspect(snapshot.dispatched_count, content="1")
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_subscription_plan_count, content="2")
  inspect(
    inspector.last_subscription_plan_summary.duplicate_key_count,
    content="1",
  )
  inspect(
    inspector.last_subscription_plan_summary.duplicate_keys[0],
    content="instant",
  )
  inspect(
    inspector.last_subscription_plan_summary.descriptors[1].key,
    content="instant",
  )
  inspect(inspector.reused_subscription_count, content="1")
  inspect(inspector.duplicate_subscription_key_count, content="2")
  inspect(inspector.duplicate_subscription_keys.length(), content="1")
  inspect(inspector.duplicate_subscription_keys[0], content="instant")
}

///|
test "program bounds synchronous subscription-start loops in one drain turn" {
  let start_count = Ref(0)
  let target = program_message_drain_limit() + 6
  let program = Program::new(
    init=() => (0, Effect::none()),
    update=(model, message) => {
      match message {
        ProgramSubscriptionLoopPulse => {
          let next = model + 1
          let effect = if next < target {
            Effect::send(ProgramSubscriptionLoopPulse)
          } else {
            Effect::none()
          }
          (next, effect)
        }
      }
    },
    view=model => runtime_test_label("Subscription Loop \{model}"),
    subscriptions=_model => {
      Subscription::timer(key="loop-source", label="Loop source", start=dispatch => {
        start_count.val = start_count.val + 1
        dispatch(ProgramSubscriptionLoopPulse)
        None
      })
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=220.0, height=48.0),
  )
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Subscription Loop \{program_message_drain_limit()}",
    ),
  )
  let snapshot = runtime.program_runtime_snapshot()
  inspect(start_count.val, content="1")
  inspect(snapshot.dispatched_count, content="\{program_message_drain_limit()}")
  inspect(
    snapshot.message_enqueue_count,
    content="\{program_message_drain_limit() + 1}",
  )
  inspect(snapshot.message_drain_count, content="1")
  inspect(snapshot.pending_message_count, content="1")
  inspect(snapshot.active_subscription_count, content="1")
  inspect(snapshot.active_subscriptions[0].key, content="loop-source")
}

///|
test "program resumes pending subscription-start messages on next host callback" {
  let start_count = Ref(0)
  let target = program_message_drain_limit() + 6
  let program = Program::new(
    init=() => ({ pulses: 0, host_seen_at: -1 }, Effect::none()),
    update=(model, message) => {
      match message {
        ProgramSubscriptionTurnResumePulse => {
          let next = model.pulses + 1
          let effect = if next < target {
            Effect::send(ProgramSubscriptionTurnResumePulse)
          } else {
            Effect::none()
          }
          ({ ..model, pulses: next }, effect)
        }
        ProgramSubscriptionTurnResumeHostCallback =>
          ({ ..model, host_seen_at: model.pulses }, Effect::none())
      }
    },
    view=model => {
      View::button(
        text="Sub Resume \{model.pulses} host:\{model.host_seen_at}",
        size=Size::new(width=240.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramSubscriptionTurnResumeHostCallback),
      )
    },
    subscriptions=_model => {
      Subscription::timer(key="loop-source", label="Loop source", start=dispatch => {
        start_count.val = start_count.val + 1
        dispatch(ProgramSubscriptionTurnResumePulse)
        None
      })
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=280.0, height=80.0),
  )
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Sub Resume \{program_message_drain_limit()} host:-1",
    ),
  )
  let first_turn = runtime.program_runtime_snapshot()
  inspect(start_count.val, content="1")
  inspect(
    first_turn.dispatched_count,
    content="\{program_message_drain_limit()}",
  )
  inspect(
    first_turn.message_enqueue_count,
    content="\{program_message_drain_limit() + 1}",
  )
  inspect(first_turn.message_drain_count, content="1")
  inspect(first_turn.pending_message_count, content="1")
  inspect(first_turn.active_subscription_count, content="1")

  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Sub Resume \{target} host:\{program_message_drain_limit() + 1}",
    ),
  )
  let second_turn = runtime.program_runtime_snapshot()
  inspect(start_count.val, content="1")
  inspect(second_turn.dispatched_count, content="\{target + 1}")
  inspect(second_turn.update_count, content="\{target + 1}")
  inspect(second_turn.message_enqueue_count, content="\{target + 1}")
  inspect(second_turn.message_drain_count, content="2")
  inspect(second_turn.pending_message_count, content="0")
  inspect(second_turn.active_subscription_count, content="1")
}
