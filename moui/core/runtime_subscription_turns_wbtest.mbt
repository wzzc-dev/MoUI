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
  let runtime = RuntimeKernel::new_program(
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
      View::primitive_button_view(
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
  let runtime = RuntimeKernel::new_program(
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
