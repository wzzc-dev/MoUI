///|
enum ProgramEffectLoopMsg {
  ProgramEffectLoopPulse
}

///|
enum ProgramTurnResumeMsg {
  ProgramTurnResumePulse
  ProgramTurnResumeHostCallback
}

///|
enum ProgramEffectRunTurnResumeMsg {
  ProgramEffectRunTurnResumePulse
  ProgramEffectRunTurnResumeHostCallback
}

///|
struct ProgramTurnResumeModel {
  pulses : Int
  host_seen_at : Int
  started : Bool
}

///|
struct ProgramEffectRunTurnResumeModel {
  pulses : Int
  host_seen_at : Int
  started : Bool
}

///|
test "program bounds synchronous effect self loops in one drain turn" {
  let target = program_message_drain_limit() + 6
  let program = Program::new(
    init=() => (0, Effect::none()),
    update=(model, message) => {
      match message {
        ProgramEffectLoopPulse => {
          let next = model + 1
          let effect = if next < target {
            Effect::send(ProgramEffectLoopPulse)
          } else {
            Effect::none()
          }
          (next, effect)
        }
      }
    },
    view=model => {
      View::primitive_button_view(
        text="Loop \{model}",
        size=Size::new(width=140.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramEffectLoopPulse),
      )
    },
  )
  let runtime = RuntimeKernel::new_program(
    program~,
    size=Size::new(width=180.0, height=80.0),
  )
  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Loop \{program_message_drain_limit()}",
    ),
  )
  let snapshot = runtime.program_runtime_snapshot()
  inspect(snapshot.dispatched_count, content="\{program_message_drain_limit()}")
  inspect(snapshot.update_count, content="\{program_message_drain_limit()}")
  inspect(
    snapshot.message_enqueue_count,
    content="\{program_message_drain_limit() + 1}",
  )
  inspect(snapshot.message_drain_count, content="1")
  inspect(snapshot.pending_message_count, content="1")
}

///|
test "program resumes pending self-loop messages on next host callback" {
  let target = program_message_drain_limit() + 6
  let program = Program::new(
    init=() => {
      let initial : ProgramTurnResumeModel = {
        pulses: 0,
        host_seen_at: -1,
        started: false,
      }
      (initial, Effect::none())
    },
    update=(model, message) => {
      match message {
        ProgramTurnResumePulse => {
          let next = model.pulses + 1
          let effect = if next < target {
            Effect::send(ProgramTurnResumePulse)
          } else {
            Effect::none()
          }
          ({ ..model, pulses: next, started: true }, effect)
        }
        ProgramTurnResumeHostCallback =>
          ({ ..model, host_seen_at: model.pulses }, Effect::none())
      }
    },
    view=model => {
      View::primitive_button_view(
        text="Resume \{model.pulses} host:\{model.host_seen_at}",
        size=Size::new(width=220.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(
          if model.started {
            ProgramTurnResumeHostCallback
          } else {
            ProgramTurnResumePulse
          },
        ),
      )
    },
  )
  let runtime = RuntimeKernel::new_program(
    program~,
    size=Size::new(width=260.0, height=80.0),
  )
  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Resume \{program_message_drain_limit()} host:-1",
    ),
  )
  let first_turn = runtime.program_runtime_snapshot()
  inspect(
    first_turn.dispatched_count,
    content="\{program_message_drain_limit()}",
  )
  inspect(first_turn.message_drain_count, content="1")
  inspect(first_turn.pending_message_count, content="1")

  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Resume \{target} host:\{program_message_drain_limit() + 1}",
    ),
  )
  let second_turn = runtime.program_runtime_snapshot()
  inspect(second_turn.dispatched_count, content="\{target + 1}")
  inspect(second_turn.update_count, content="\{target + 1}")
  inspect(second_turn.message_enqueue_count, content="\{target + 1}")
  inspect(second_turn.message_drain_count, content="2")
  inspect(second_turn.pending_message_count, content="0")
}

///|
test "program resumes pending structured effect-run messages on next host callback" {
  let target = program_message_drain_limit() + 6
  let program = Program::new(
    init=() => {
      let initial : ProgramEffectRunTurnResumeModel = {
        pulses: 0,
        host_seen_at: -1,
        started: false,
      }
      (initial, Effect::none())
    },
    update=(model, message) => {
      match message {
        ProgramEffectRunTurnResumePulse => {
          let next = model.pulses + 1
          let effect = if next < target {
            Effect::run(
              key="effect:structured-loop",
              kind="turn-test",
              label="Structured loop",
              run=dispatch => dispatch(ProgramEffectRunTurnResumePulse),
            )
          } else {
            Effect::none()
          }
          ({ ..model, pulses: next, started: true }, effect)
        }
        ProgramEffectRunTurnResumeHostCallback =>
          ({ ..model, host_seen_at: model.pulses }, Effect::none())
      }
    },
    view=model => {
      View::primitive_button_view(
        text="Run Resume \{model.pulses} host:\{model.host_seen_at}",
        size=Size::new(width=260.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(
          if model.started {
            ProgramEffectRunTurnResumeHostCallback
          } else {
            ProgramEffectRunTurnResumePulse
          },
        ),
      )
    },
  )
  let runtime = RuntimeKernel::new_program(
    program~,
    size=Size::new(width=300.0, height=80.0),
  )
  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Run Resume \{program_message_drain_limit()} host:-1",
    ),
  )
  let first_turn = runtime.program_runtime_snapshot()
  inspect(
    first_turn.dispatched_count,
    content="\{program_message_drain_limit()}",
  )
  inspect(
    first_turn.effect_run_count,
    content="\{program_message_drain_limit()}",
  )
  inspect(
    first_turn.message_enqueue_count,
    content="\{program_message_drain_limit() + 1}",
  )
  inspect(first_turn.message_drain_count, content="1")
  inspect(first_turn.pending_message_count, content="1")

  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(
    has_draw_text(
      runtime.draw_commands(),
      "Run Resume \{target} host:\{program_message_drain_limit() + 1}",
    ),
  )
  let second_turn = runtime.program_runtime_snapshot()
  inspect(second_turn.dispatched_count, content="\{target + 1}")
  inspect(second_turn.update_count, content="\{target + 1}")
  inspect(second_turn.effect_run_count, content="\{target - 1}")
  inspect(second_turn.message_enqueue_count, content="\{target + 1}")
  inspect(second_turn.message_drain_count, content="2")
  inspect(second_turn.pending_message_count, content="0")
}
