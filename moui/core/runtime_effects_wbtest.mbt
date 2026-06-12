///|
enum ProgramEffectMsg {
  ProgramEffectStart
  ProgramEffectBoot(String)
  ProgramEffectFinished(String)
}

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
test "effect plan summary describes nested effect structure" {
  let effect : Effect[String] = Effect::batch([
    Effect::send("first"),
    Effect::batch([
      Effect::none(),
      Effect::host_service(key="host:load", label="Load host data", run=_dispatch => {
        ()
      }),
    ]),
  ])
  let summary = effect.plan_summary()
  assert_true(summary.root_kind == EffectPlanKind::EffectPlanBatch)
  inspect(summary.batch_count, content="2")
  inspect(summary.none_count, content="1")
  inspect(summary.send_count, content="1")
  inspect(summary.dispatch_count, content="0")
  inspect(summary.run_count, content="1")
  inspect(summary.task_count, content="0")
  inspect(summary.scheduled_count, content="2")
  inspect(summary.max_depth, content="3")
  inspect(summary.descriptors.length(), content="1")
  inspect(summary.descriptors[0].key, content="host:load")
  inspect(summary.descriptors[0].kind, content="host-service")
  inspect(summary.descriptors[0].label, content="Load host data")
  let mapped = effect.map(message => "parent:" + message)
  let mapped_summary = mapped.plan_summary()
  inspect(mapped_summary.descriptors.length(), content="1")
  inspect(mapped_summary.descriptors[0].key, content="host:load")
}

///|
test "effect plan summary reports duplicate structured effect keys" {
  let effect : Effect[String] = Effect::batch([
    Effect::host_service(key="host:sync", label="Sync host data", run=_dispatch => {
      ()
    }),
    Effect::batch([
      Effect::host_service(key="host:sync", label="Duplicate sync", run=_dispatch => {
        ()
      }),
      Effect::run(
        key="animation:tick",
        kind="animation",
        label="Animation tick",
        run=_dispatch => (),
      ),
    ]),
  ])
  let summary = effect.plan_summary()
  inspect(summary.descriptors.length(), content="3")
  inspect(summary.duplicate_descriptor_key_count, content="1")
  inspect(summary.duplicate_descriptor_keys.length(), content="1")
  inspect(summary.duplicate_descriptor_keys[0], content="host:sync")
  let nested = match effect {
    Effect::Batch([_, child]) => child.plan_summary()
    _ => fail("expected nested effect batch")
  }
  inspect(nested.descriptors.length(), content="2")
  inspect(nested.duplicate_descriptor_key_count, content="0")
  inspect(nested.duplicate_descriptor_keys.length(), content="0")
}

///|
test "program runtime aggregates duplicate structured effect keys" {
  let program = Program::new(
    init=() => {
      let effect : Effect[String] = Effect::batch([
        Effect::host_service(key="host:sync", label="Sync host data", run=_dispatch => {
          ()
        }),
        Effect::host_service(key="host:sync", label="Duplicate sync", run=_dispatch => {
          ()
        }),
      ])
      ("idle", effect)
    },
    update=(model, _message) => (model, Effect::none()),
    view=model => runtime_test_label(model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=48.0),
  )
  let program_snapshot = runtime.program_runtime_snapshot()
  inspect(program_snapshot.effect_plan_count, content="1")
  inspect(program_snapshot.effect_count, content="2")
  inspect(program_snapshot.effect_dispatch_count, content="0")
  inspect(program_snapshot.effect_run_count, content="2")
  inspect(program_snapshot.duplicate_effect_descriptor_key_count, content="1")
  inspect(
    program_snapshot.duplicate_effect_descriptor_keys.length(),
    content="1",
  )
  inspect(
    program_snapshot.duplicate_effect_descriptor_keys[0],
    content="host:sync",
  )
  inspect(program_snapshot.last_effect_summary.run_count, content="2")
  inspect(
    program_snapshot.last_effect_summary.duplicate_descriptor_key_count,
    content="1",
  )
  inspect(
    program_snapshot.last_effect_summary.duplicate_descriptor_keys[0],
    content="host:sync",
  )
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_effect_run_count, content="2")
  inspect(inspector.duplicate_effect_descriptor_key_count, content="1")
  inspect(inspector.duplicate_effect_descriptor_keys.length(), content="1")
  inspect(inspector.duplicate_effect_descriptor_keys[0], content="host:sync")
  inspect(inspector.last_effect_summary.descriptors.length(), content="2")
  inspect(
    inspector.last_effect_summary.duplicate_descriptor_keys[0],
    content="host:sync",
  )
}

///|
test "program initial effects run before first view build" {
  let program = Program::new(
    init=() => {
      (
        "booting",
        Effect::batch([
          Effect::send(ProgramEffectBoot("sent")),
          Effect::dispatch(dispatch => {
            dispatch(ProgramEffectFinished("dispatched"))
          }),
        ]),
      )
    },
    update=(model, message) => {
      match message {
        ProgramEffectStart => ("running", Effect::none())
        ProgramEffectBoot(value) => ("\{model}+\{value}", Effect::none())
        ProgramEffectFinished(value) => ("\{model}+\{value}", Effect::none())
      }
    },
    view=model => runtime_test_label("Boot " + model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=220.0, height=72.0),
  )
  assert_true(
    has_draw_text(runtime.draw_commands(), "Boot booting+sent+dispatched"),
  )
  let program_snapshot = runtime.program_runtime_snapshot()
  inspect(program_snapshot.dispatched_count, content="2")
  inspect(program_snapshot.update_count, content="2")
  inspect(program_snapshot.message_enqueue_count, content="2")
  inspect(program_snapshot.message_drain_count, content="2")
  inspect(program_snapshot.pending_message_count, content="0")
  inspect(program_snapshot.max_pending_message_count, content="1")
  inspect(program_snapshot.effect_plan_count, content="3")
  inspect(program_snapshot.effect_count, content="2")
  inspect(program_snapshot.effect_batch_count, content="1")
  inspect(program_snapshot.effect_send_count, content="1")
  inspect(program_snapshot.effect_dispatch_count, content="1")
  inspect(program_snapshot.effect_run_count, content="0")
  inspect(program_snapshot.effect_task_count, content="0")
  inspect(program_snapshot.duplicate_effect_descriptor_key_count, content="0")
  inspect(program_snapshot.effect_none_count, content="2")
  assert_true(
    program_snapshot.last_effect_summary.root_kind ==
    EffectPlanKind::EffectPlanBatch,
  )
  inspect(program_snapshot.last_effect_summary.scheduled_count, content="2")
  assert_true(
    program_snapshot.last_scheduled_effect_summary.root_kind ==
    EffectPlanKind::EffectPlanBatch,
  )
  inspect(
    program_snapshot.last_scheduled_effect_summary.scheduled_count,
    content="2",
  )
}

///|
test "program effects can dispatch typed follow-up messages" {
  let program = Program::new(
    init=() => ("idle", Effect::none()),
    update=(_model, message) => {
      match message {
        ProgramEffectStart =>
          (
            "running",
            Effect::run(
              key="effect:program-follow-up",
              kind="task",
              label="Program follow-up",
              run=dispatch => {
                dispatch(ProgramEffectBoot("queued"))
                dispatch(ProgramEffectFinished("done"))
              },
            ),
          )
        ProgramEffectBoot(value) => (value, Effect::none())
        ProgramEffectFinished(value) => (value, Effect::none())
      }
    },
    view=model => {
      View::button(
        text=model,
        size=Size::new(width=120.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramEffectStart),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "idle"))
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "done"))
  let snapshot = runtime.program_runtime_snapshot()
  inspect(snapshot.dispatched_count, content="3")
  inspect(snapshot.update_count, content="3")
  inspect(snapshot.message_enqueue_count, content="3")
  inspect(snapshot.message_drain_count, content="1")
  inspect(snapshot.pending_message_count, content="0")
  inspect(snapshot.max_pending_message_count, content="2")
  inspect(snapshot.effect_dispatch_count, content="0")
  inspect(snapshot.effect_run_count, content="1")
  inspect(snapshot.effect_task_count, content="0")
  assert_true(
    snapshot.last_scheduled_effect_summary.root_kind ==
    EffectPlanKind::EffectPlanRun,
  )
  inspect(snapshot.last_scheduled_effect_summary.scheduled_count, content="1")
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors.length(),
    content="1",
  )
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors[0].key,
    content="effect:program-follow-up",
  )
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors[0].kind,
    content="task",
  )
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
      View::button(
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
  let runtime = AppRuntime::new_program(
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
      View::button(
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
  let runtime = AppRuntime::new_program(
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
      View::button(
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
  let runtime = AppRuntime::new_program(
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

///|
test "program ignores effect dispatches after runtime destroy" {
  let anonymous_dispatch : Ref[((ProgramEffectMsg) -> Unit)?] = Ref(None)
  let structured_dispatch : Ref[((ProgramEffectMsg) -> Unit)?] = Ref(None)
  let program = Program::new(
    init=() => {
      (
        "idle",
        Effect::batch([
          Effect::dispatch(dispatch => anonymous_dispatch.val = Some(dispatch)),
          Effect::run(
            key="effect:late-structured",
            kind="late-callback",
            label="Late structured callback",
            run=dispatch => structured_dispatch.val = Some(dispatch),
          ),
        ]),
      )
    },
    update=(_model, message) => {
      match message {
        ProgramEffectStart => ("started", Effect::none())
        ProgramEffectBoot(value) => (value, Effect::none())
        ProgramEffectFinished(value) => (value, Effect::none())
      }
    },
    view=model => runtime_test_label(model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.effect_dispatch_count, content="1")
  inspect(initial.effect_run_count, content="1")
  inspect(initial.message_enqueue_count, content="0")
  inspect(initial.ignored_program_dispatch_count, content="0")
  runtime.destroy()
  match anonymous_dispatch.val {
    Some(dispatch) => dispatch(ProgramEffectBoot("late-anonymous"))
    None => fail("expected anonymous effect dispatch")
  }
  match structured_dispatch.val {
    Some(dispatch) => dispatch(ProgramEffectFinished("late-structured"))
    None => fail("expected structured effect dispatch")
  }
  let ignored = runtime.program_runtime_snapshot()
  inspect(ignored.dispatched_count, content="0")
  inspect(ignored.update_count, content="0")
  inspect(ignored.message_enqueue_count, content="0")
  inspect(ignored.ignored_program_dispatch_count, content="2")
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_dispatched_count, content="0")
  inspect(inspector.ignored_program_dispatch_count, content="2")
}

///|
enum ProgramTaskMsg {
  ProgramTaskReplace
  ProgramTaskFinished(String)
}

///|
test "program effect tasks complete on first dispatch and ignore stale dispatches" {
  let task_dispatch : Ref[((ProgramTaskMsg) -> Unit)?] = Ref(None)
  let cleanup_count = Ref(0)
  let program = Program::new(
    init=() => {
      (
        "pending",
        Effect::service_task(key="task:load", label="Load task", start=dispatch => {
          task_dispatch.val = Some(dispatch)
          Some(() => cleanup_count.val = cleanup_count.val + 1)
        }),
      )
    },
    update=(model, message) => {
      match message {
        ProgramTaskFinished(value) => (value, Effect::none())
        ProgramTaskReplace => (model, Effect::none())
      }
    },
    view=model => runtime_test_label(model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "pending"))
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.effect_task_count, content="1")
  inspect(initial.active_effect_task_count, content="1")
  inspect(initial.started_effect_task_count, content="1")
  inspect(initial.completed_effect_task_count, content="0")
  inspect(initial.cancelled_effect_task_count, content="0")
  inspect(initial.active_effect_tasks[0].key, content="task:load")
  inspect(initial.active_effect_tasks[0].kind, content="service")
  inspect(initial.active_effect_tasks[0].label, content="Load task")
  assert_true(
    initial.last_scheduled_effect_summary.root_kind ==
    EffectPlanKind::EffectPlanTask,
  )
  inspect(initial.last_scheduled_effect_summary.task_count, content="1")
  inspect(
    initial.last_scheduled_effect_summary.descriptors[0].key,
    content="task:load",
  )
  inspect(
    initial.last_scheduled_effect_summary.descriptors[0].kind,
    content="service",
  )
  match task_dispatch.val {
    Some(dispatch) => dispatch(ProgramTaskFinished("done"))
    None => fail("expected task dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "done"))
  let completed = runtime.program_runtime_snapshot()
  inspect(completed.dispatched_count, content="1")
  inspect(completed.update_count, content="1")
  inspect(completed.active_effect_task_count, content="0")
  inspect(completed.completed_effect_task_count, content="1")
  inspect(completed.cancelled_effect_task_count, content="0")
  inspect(cleanup_count.val, content="0")
  assert_true(
    completed.effect_task_lifecycle.any(entry => {
      entry.key == "task:load" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCompleted
    }),
  )
  match task_dispatch.val {
    Some(dispatch) => dispatch(ProgramTaskFinished("late"))
    None => fail("expected stale task dispatch")
  }
  let stale = runtime.program_runtime_snapshot()
  inspect(stale.dispatched_count, content="1")
  inspect(stale.update_count, content="1")
  inspect(stale.ignored_effect_task_dispatch_count, content="1")
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_effect_task_count, content="1")
  inspect(inspector.active_effect_task_count, content="0")
  inspect(inspector.completed_effect_task_count, content="1")
}

///|
test "program effect tasks ignore synchronous second dispatch before first message drains" {
  let cleanup_count = Ref(0)
  let program = Program::new(
    init=() => {
      (
        "pending",
        Effect::task(
          key="task:sync-double",
          kind="custom-sync",
          label="Sync double",
          start=dispatch => {
            dispatch(ProgramTaskFinished("first"))
            dispatch(ProgramTaskFinished("second"))
            Some(() => cleanup_count.val = cleanup_count.val + 1)
          },
        ),
      )
    },
    update=(_model, message) => {
      match message {
        ProgramTaskFinished(value) => (value, Effect::none())
        ProgramTaskReplace => ("replace", Effect::none())
      }
    },
    view=model => runtime_test_label(model),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "first"))
  let snapshot = runtime.program_runtime_snapshot()
  inspect(snapshot.dispatched_count, content="1")
  inspect(snapshot.update_count, content="1")
  inspect(snapshot.message_enqueue_count, content="1")
  inspect(snapshot.ignored_effect_task_dispatch_count, content="1")
  inspect(snapshot.active_effect_task_count, content="0")
  inspect(snapshot.completed_effect_task_count, content="1")
  inspect(snapshot.cancelled_effect_task_count, content="0")
  inspect(cleanup_count.val, content="0")
  assert_true(
    snapshot.effect_task_lifecycle.any(entry => {
      entry.key == "task:sync-double" &&
      entry.kind == "custom-sync" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCompleted
    }),
  )
}

///|
test "program effect tasks cancel by key change and runtime destroy" {
  let first_dispatch : Ref[((ProgramTaskMsg) -> Unit)?] = Ref(None)
  let second_dispatch : Ref[((ProgramTaskMsg) -> Unit)?] = Ref(None)
  let cleanup_log : Array[String] = []
  let start_task = (
    label : String,
    dispatch_ref : Ref[((ProgramTaskMsg) -> Unit)?],
  ) => {
    Effect::service_task(key="task:replaceable", label~, start=dispatch => {
      dispatch_ref.val = Some(dispatch)
      Some(() => cleanup_log.push(label))
    })
  }
  let program = Program::new(
    init=() => ("first", start_task("first", first_dispatch)),
    update=(_model, message) => {
      match message {
        ProgramTaskReplace => ("second", start_task("second", second_dispatch))
        ProgramTaskFinished(value) => (value, Effect::none())
      }
    },
    view=model => {
      View::button(
        text=model,
        size=Size::new(width=140.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramTaskReplace),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=80.0),
  )
  inspect(
    runtime.program_runtime_snapshot().active_effect_task_count,
    content="1",
  )
  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(has_draw_text(runtime.draw_commands(), "second"))
  let replaced = runtime.program_runtime_snapshot()
  inspect(replaced.started_effect_task_count, content="2")
  inspect(replaced.cancelled_effect_task_count, content="1")
  inspect(replaced.active_effect_task_count, content="1")
  inspect(cleanup_log.join(","), content="first")
  assert_true(
    replaced.effect_task_lifecycle.any(entry => {
      entry.key == "task:replaceable" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCancelled &&
      entry.cancel_reason == Some(EffectTaskCancelReason::EffectTaskKeyChanged)
    }),
  )
  match first_dispatch.val {
    Some(dispatch) => dispatch(ProgramTaskFinished("stale-first"))
    None => fail("expected first task dispatch")
  }
  inspect(
    runtime.program_runtime_snapshot().ignored_effect_task_dispatch_count,
    content="1",
  )
  runtime.destroy()
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.active_effect_task_count, content="0")
  inspect(destroyed.cancelled_effect_task_count, content="2")
  inspect(cleanup_log.join(","), content="first,second")
  assert_true(
    destroyed.effect_task_lifecycle.any(entry => {
      entry.key == "task:replaceable" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCancelled &&
      entry.cancel_reason ==
      Some(EffectTaskCancelReason::EffectTaskRuntimeDestroyed)
    }),
  )
  match second_dispatch.val {
    Some(dispatch) => dispatch(ProgramTaskFinished("stale-second"))
    None => fail("expected second task dispatch")
  }
  inspect(
    runtime.program_runtime_snapshot().ignored_effect_task_dispatch_count,
    content="2",
  )
}

///|
test "program effect task replacement reports same-key kind changes" {
  let first_dispatch : Ref[((ProgramTaskMsg) -> Unit)?] = Ref(None)
  let second_dispatch : Ref[((ProgramTaskMsg) -> Unit)?] = Ref(None)
  let cleanup_log : Array[String] = []
  let service_task = Effect::service_task(
    key="task:shared-loader",
    label="Service load",
    start=dispatch => {
      first_dispatch.val = Some(dispatch)
      Some(() => cleanup_log.push("service"))
    },
  )
  let custom_task = Effect::task(
    key="task:shared-loader",
    kind="custom-load",
    label="Custom load",
    start=dispatch => {
      second_dispatch.val = Some(dispatch)
      Some(() => cleanup_log.push("custom"))
    },
  )
  let program = Program::new(
    init=() => ("service", service_task),
    update=(_model, message) => {
      match message {
        ProgramTaskReplace => ("custom", custom_task)
        ProgramTaskFinished(value) => (value, Effect::none())
      }
    },
    view=model => {
      View::button(
        text=model,
        size=Size::new(width=140.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramTaskReplace),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=80.0),
  )
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_effect_tasks[0].kind, content="service")
  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(has_draw_text(runtime.draw_commands(), "custom"))
  let replaced = runtime.program_runtime_snapshot()
  inspect(replaced.started_effect_task_count, content="2")
  inspect(replaced.cancelled_effect_task_count, content="1")
  inspect(replaced.active_effect_tasks[0].kind, content="custom-load")
  inspect(cleanup_log.join(","), content="service")
  assert_true(
    replaced.effect_task_lifecycle.any(entry => {
      entry.key == "task:shared-loader" &&
      entry.kind == "service" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCancelled &&
      entry.cancel_reason == Some(EffectTaskCancelReason::EffectTaskKindChanged)
    }),
  )
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  assert_true(
    inspector.effect_task_lifecycle.any(entry => {
      entry.key == "task:shared-loader" &&
      entry.kind == "service" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCancelled &&
      entry.cancel_reason == Some(EffectTaskCancelReason::EffectTaskKindChanged)
    }),
  )
  match first_dispatch.val {
    Some(dispatch) => dispatch(ProgramTaskFinished("stale-service"))
    None => fail("expected first task dispatch")
  }
  inspect(
    runtime.program_runtime_snapshot().ignored_effect_task_dispatch_count,
    content="1",
  )
}
