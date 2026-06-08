///|
test "app runtime dispatches events and draws" {
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Click",
      size: Size::new(width=100.0, height=50.0),
      font: FontSpec::new(size=16.0, weight=600),
      foreground: Color::black(),
      background: Brush::solid(Color::gray()),
      hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
      pressed_background: Brush::solid(Color::blue()),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: None,
    }),
    size=Size::new(width=120.0, height=80.0),
  )
  inspect(runtime.draw_commands().length(), content="3")
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  assert_true(runtime.size() == Size::new(width=240.0, height=160.0))
  inspect(runtime.dirty_count(), content="1")
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
      ),
    ),
  )
  inspect(runtime.needs_redraw(), content="true")
  ignore(runtime.draw_commands())
  inspect(runtime.dirty_count(), content="0")
}

///|
test "app runtime component watches state through public API" {
  let count = State::new(0)
  let runtime = AppRuntime::new_component(
    root=Component::new(ctx => {
      ViewSpec::TextSpec({
        key: None,
        text: "Count \{ctx.watch(count)}",
        size: Size::new(width=100.0, height=24.0),
        font: FontSpec::new(size=16.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  guard runtime.draw_commands() is [_, DrawText({ text: "Count 0", .. })] else {
    fail("expected initial component text")
  }
  count.set(1)
  inspect(runtime.needs_rebuild(), content="true")
  guard runtime.draw_commands() is [_, DrawText({ text: "Count 1", .. })] else {
    fail("expected rebuilt component text")
  }
  inspect(count.slot.listeners.length(), content="1")
}

///|
test "build context viewport size updates after resize" {
  let runtime = AppRuntime::new_component(
    root=Component::new(ctx => {
      let size = ctx.viewport_size()
      ViewSpec::TextSpec({
        key: None,
        text: "\{size.width}x\{size.height}",
        size: Size::new(width=140.0, height=24.0),
        font: FontSpec::new(size=16.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  guard runtime.draw_commands() is [_, DrawText({ text: "120x40", .. })] else {
    fail("expected initial viewport text")
  }
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  guard runtime.draw_commands() is [_, DrawText({ text: "240x160", .. })] else {
    fail("expected resized viewport text")
  }
}

///|
test "searchbar paints vector icons instead of font fallback glyphs" {
  let query = State::new("abc")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::SearchBarSpec({
      key: None,
      query: query.binding(),
      placeholder: "Search",
      font: FontSpec::new(size=14.0, weight=400),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: Brush::solid(Color::white()),
      border: None,
      focused_border: None,
      cursor_color: Color::blue(),
      corner_radius: 8.0,
      on_submit: None,
      on_clear: None,
    }),
    size=Size::new(width=240.0, height=44.0),
  )
  let commands = runtime.draw_commands()
  assert_false(has_draw_text(commands, "?"))
  assert_true(commands.any(command => command is DrawCommand::DrawPath(_)))
  assert_true(
    commands.any(command => command is DrawCommand::StrokeRoundedRect(_, _, _)),
  )
}

///|
test "app runtime updates root and environment through public API" {
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::TextSpec({
      key: None,
      text: "A",
      size: Size::new(width=40.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  runtime.set_root_spec(
    ViewSpec::TextSpec({
      key: None,
      text: "B",
      size: Size::new(width=40.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
  )
  guard runtime.draw_commands() is [_, DrawText({ text: "B", .. })] else {
    fail("expected replacement root text")
  }
  let environment = Environment::default()
    .with_text_scale(1.25)
    .with_locale("zh-CN")
  runtime.set_environment(environment)
  inspect(runtime.environment().text_scale, content="1.25")
  inspect(runtime.environment().locale, content="zh-CN")
  inspect(runtime.needs_redraw(), content="true")
}

///|
fn has_draw_text(commands : Array[DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn draw_text_frame(commands : Array[DrawCommand], text : String) -> Rect? {
  for command in commands {
    match command {
      DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn draw_text_index(commands : Array[DrawCommand], text : String) -> Int {
  for index, command in commands {
    match command {
      DrawCommand::DrawText({ text: value, .. }) =>
        if value == text {
          return index
        }
      _ => ()
    }
  }
  -1
}

///|
enum ProgramSimpleMsg {
  ProgramSimpleIncrement
}

///|
test "program simple updates model and rebuilds view" {
  let program = Program::simple(
    init=0,
    update=(model, message) => {
      match message {
        ProgramSimpleIncrement => model + 1
      }
    },
    view=model => {
      View::button(
        text="Count \{model}",
        size=Size::new(width=120.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramSimpleIncrement),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 0"))
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
  assert_true(has_draw_text(runtime.draw_commands(), "Count 1"))
}

///|
test "button press batches paint without build or layout flush" {
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Press",
      size: Size::new(width=100.0, height=44.0),
      font: FontSpec::new(size=16.0),
      foreground: Color::black(),
      background: Brush::solid(Color::gray()),
      hovered_background: Brush::solid(Color::gray()),
      pressed_background: Brush::solid(Color::blue()),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: None,
    }),
    size=Size::new(width=120.0, height=60.0),
  )
  inspect(runtime.state.rebuild_pass_count, content="0")
  inspect(runtime.state.layout_pass_count, content="1")
  inspect(runtime.state.paint_pass_count, content="1")
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.needs_rebuild(), content="false")
  inspect(runtime.needs_layout(), content="false")
  inspect(runtime.needs_paint(), content="true")
  inspect(runtime.state.dirty_build_elements.length(), content="0")
  inspect(runtime.state.dirty_layout_elements.length(), content="0")
  inspect(runtime.state.dirty_paint_elements.length(), content="1")
  inspect(runtime.state.rebuild_pass_count, content="0")
  inspect(runtime.state.layout_pass_count, content="1")
  inspect(runtime.state.paint_pass_count, content="1")
  ignore(runtime.draw_commands())
  inspect(runtime.state.rebuild_pass_count, content="0")
  inspect(runtime.state.layout_pass_count, content="1")
  inspect(runtime.state.paint_pass_count, content="2")
  inspect(runtime.state.dirty_paint_elements.length(), content="0")
}

///|
test "program button update waits for draw frame flush" {
  let program = Program::simple(
    init=0,
    update=(model, message) => {
      match message {
        ProgramSimpleIncrement => model + 1
      }
    },
    view=model => {
      View::button(
        text="Count \{model}",
        size=Size::new(width=120.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramSimpleIncrement),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 0"))
  let rebuild_passes = runtime.state.rebuild_pass_count
  let layout_passes = runtime.state.layout_pass_count
  let paint_passes = runtime.state.paint_pass_count
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
  inspect(runtime.needs_rebuild(), content="true")
  inspect(runtime.state.rebuild_pass_count, content="\{rebuild_passes}")
  inspect(runtime.state.layout_pass_count, content="\{layout_passes}")
  inspect(runtime.state.paint_pass_count, content="\{paint_passes}")
  inspect(runtime.state.dirty_build_elements.length(), content="1")
  inspect(runtime.state.dirty_layout_elements.length(), content="1")
  inspect(runtime.state.dirty_paint_elements.length(), content="1")
  assert_true(has_draw_text(runtime.draw_commands(), "Count 1"))
  assert_true(runtime.state.rebuild_pass_count > rebuild_passes)
  assert_true(runtime.state.layout_pass_count > layout_passes)
  assert_true(runtime.state.paint_pass_count > paint_passes)
}

///|
test "program simple with environment rebuilds from viewport and environment" {
  let program : Program[Int, Unit] = Program::simple_with_environment(
    init=0,
    update=(model, _message) => model,
    view=(model, env) => {
      let viewport = env.viewport_size()
      let environment = env.environment()
      runtime_test_label(
        "Env \{model}: \{viewport.width}x\{viewport.height} \{environment.locale}",
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=120.0, height=40.0),
    environment=Environment::default().with_locale("en-US"),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Env 0: 120x40 en-US"))
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  assert_true(has_draw_text(runtime.draw_commands(), "Env 0: 240x160 en-US"))
  runtime.set_environment(runtime.environment().with_locale("zh-CN"))
  assert_true(has_draw_text(runtime.draw_commands(), "Env 0: 240x160 zh-CN"))
}

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

///|
test "subscription descriptors and map preserve feature composition" {
  let child_dispatch : Ref[((String) -> Unit)?] = Ref(None)
  let child = Subscription::batch([
    Subscription::none(),
    Subscription::timer(key="child-tick", label="Child tick", start=dispatch => {
      child_dispatch.val = Some(dispatch)
      None
    }),
  ])
  let parent = child.map(message => "parent:" + message)
  let plan = parent.plan_summary()
  assert_true(plan.root_kind == SubscriptionPlanKind::SubscriptionPlanBatch)
  inspect(plan.batch_count, content="1")
  inspect(plan.none_count, content="1")
  inspect(plan.source_count, content="1")
  inspect(plan.duplicate_key_count, content="0")
  inspect(plan.max_depth, content="2")
  inspect(plan.descriptors.length(), content="1")
  inspect(plan.descriptors[0].key, content="child-tick")
  inspect(plan.descriptors[0].kind, content="timer")
  inspect(plan.descriptors[0].label, content="Child tick")
  let descriptors = parent.descriptors()
  inspect(descriptors.length(), content="1")
  inspect(descriptors[0].key, content="child-tick")
  inspect(descriptors[0].kind, content="timer")
  inspect(descriptors[0].label, content="Child tick")
  let program = Program::new(
    init=() => ("waiting", Effect::none()),
    update=(_model, message) => (message, Effect::none()),
    view=model => runtime_test_label(model),
    subscriptions=_model => parent,
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "waiting"))
  let snapshot = runtime.program_runtime_snapshot()
  inspect(
    snapshot.last_subscription_plan_summary.descriptors.length(),
    content="1",
  )
  inspect(
    snapshot.last_subscription_plan_summary.descriptors[0].key,
    content="child-tick",
  )
  inspect(snapshot.active_subscriptions.length(), content="1")
  inspect(snapshot.active_subscriptions[0].key, content="child-tick")
  match child_dispatch.val {
    Some(dispatch) => dispatch("pulse")
    None => fail("expected child dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "parent:pulse"))
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(
    inspector.last_subscription_plan_summary.descriptors.length(),
    content="1",
  )
  inspect(
    inspector.last_subscription_plan_summary.descriptors[0].label,
    content="Child tick",
  )
  inspect(inspector.active_subscriptions[0].label, content="Child tick")
}

///|
enum ChildMappedSubscriptionMsg {
  ChildMappedSubscriptionStop
  ChildMappedSubscriptionPulse
}

///|
enum ParentMappedSubscriptionMsg {
  ParentMappedSubscriptionChild(ChildMappedSubscriptionMsg)
}

///|
struct ParentMappedSubscriptionModel {
  active : Bool
  pulses : Int
}

///|
test "mapped child subscriptions cancel and ignore stale dispatches" {
  let child_dispatch : Ref[((ChildMappedSubscriptionMsg) -> Unit)?] = Ref(None)
  let cleanup_log : Array[String] = []
  let program = Program::new(
    init=() => ({ active: true, pulses: 0 }, Effect::none()),
    update=(model, message) => {
      match message {
        ParentMappedSubscriptionChild(child_message) =>
          match child_message {
            ChildMappedSubscriptionPulse =>
              ({ ..model, pulses: model.pulses + 1 }, Effect::none())
            ChildMappedSubscriptionStop =>
              ({ ..model, active: false }, Effect::none())
          }
      }
    },
    view=model => {
      runtime_test_label("active:\{model.active} pulses:\{model.pulses}")
    },
    subscriptions=model => {
      if model.active {
        Subscription::timer(
          key="child-mapped:tick",
          label="Child mapped tick",
          start=dispatch => {
            child_dispatch.val = Some(dispatch)
            Some(() => cleanup_log.push("child"))
          },
        ).map(message => ParentMappedSubscriptionChild(message))
      } else {
        Subscription::none()
      }
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "active:true pulses:0"))
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.started_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key, content="child-mapped:tick")
  inspect(initial.active_subscriptions[0].kind, content="timer")
  inspect(initial.active_subscriptions[0].label, content="Child mapped tick")
  assert_true(
    initial.subscription_lifecycle.any(entry => {
      entry.key == "child-mapped:tick" &&
      entry.kind == "timer" &&
      entry.label == "Child mapped tick" &&
      entry.status == SubscriptionLifecycleStatus::SubscriptionActive
    }),
  )
  match child_dispatch.val {
    Some(dispatch) => dispatch(ChildMappedSubscriptionPulse)
    None => fail("expected mapped child subscription dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "active:true pulses:1"))
  let reused = runtime.program_runtime_snapshot()
  inspect(reused.dispatched_count, content="1")
  inspect(reused.update_count, content="1")
  inspect(reused.reused_subscription_count, content="1")
  inspect(cleanup_log.length(), content="0")
  match child_dispatch.val {
    Some(dispatch) => dispatch(ChildMappedSubscriptionStop)
    None => fail("expected mapped child stop dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "active:false pulses:1"))
  let cancelled = runtime.program_runtime_snapshot()
  inspect(cancelled.dispatched_count, content="2")
  inspect(cancelled.update_count, content="2")
  inspect(cancelled.active_subscription_count, content="0")
  inspect(cancelled.cancelled_subscription_count, content="1")
  inspect(cleanup_log.join(","), content="child")
  assert_true(
    cancelled.subscription_lifecycle.any(entry => {
      entry.key == "child-mapped:tick" &&
      entry.kind == "timer" &&
      entry.status == SubscriptionLifecycleStatus::SubscriptionCancelled &&
      entry.cancel_reason ==
      Some(SubscriptionCancelReason::SubscriptionKeyChanged)
    }),
  )
  match child_dispatch.val {
    Some(dispatch) => dispatch(ChildMappedSubscriptionPulse)
    None => fail("expected stale mapped child subscription dispatch")
  }
  let stale = runtime.program_runtime_snapshot()
  inspect(stale.dispatched_count, content="2")
  inspect(stale.update_count, content="2")
  inspect(stale.ignored_subscription_dispatch_count, content="1")
  assert_true(has_draw_text(runtime.draw_commands(), "active:false pulses:1"))
}

///|
test "subscription source helpers standardize diagnostic kinds" {
  let subscription : Subscription[String] = Subscription::batch([
    Subscription::timer(key="timer:refresh", label="Refresh timer", start=_dispatch => {
      None
    }),
    Subscription::animation_tick(key="animation:frame", label="Frame tick", start=_dispatch => {
      None
    }),
    Subscription::window_event(key="window:resize", label="Window resize", start=_dispatch => {
      None
    }),
    Subscription::host_event(key="host:event", label="Host event", start=_dispatch => {
      None
    }),
    Subscription::route_event(key="route:deep-link", label="Deep link", start=_dispatch => {
      None
    }),
    Subscription::service_completion(
      key="host-service:completion:7",
      label="Host completion",
      start=_dispatch => None,
    ),
  ])
  let summary = subscription.plan_summary()
  inspect(summary.source_count, content="6")
  inspect(summary.descriptors[0].kind, content="timer")
  inspect(summary.descriptors[1].kind, content="animation")
  inspect(summary.descriptors[2].kind, content="window-event")
  inspect(summary.descriptors[3].kind, content="host-event")
  inspect(summary.descriptors[4].kind, content="route-event")
  inspect(summary.descriptors[5].kind, content="host-service")
  let mapped = subscription.map(message => "parent:" + message)
  let mapped_summary = mapped.plan_summary()
  inspect(mapped_summary.descriptors[0].label, content="Refresh timer")
  inspect(
    mapped_summary.descriptors[5].key,
    content="host-service:completion:7",
  )
}

///|
test "program snapshots aggregate active subscription kinds" {
  let program = Program::new(
    init=() => ("ready", Effect::none()),
    update=(_model, message) => (message, Effect::none()),
    view=model => runtime_test_label(model),
    subscriptions=_model => {
      Subscription::batch([
        Subscription::timer(key="timer:refresh", label="Refresh timer", start=_dispatch => {
          None
        }),
        Subscription::timer(key="timer:clock", label="Clock timer", start=_dispatch => {
          None
        }),
        Subscription::host_event(key="host:theme", label="Host theme", start=_dispatch => {
          None
        }),
        Subscription::service_completion(
          key="host-service:completion:42",
          label="Host completion",
          start=_dispatch => None,
        ),
      ])
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=180.0, height=48.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "ready"))
  let snapshot = runtime.program_runtime_snapshot()
  inspect(snapshot.active_subscription_count, content="4")
  inspect(snapshot.active_subscription_kind_counts.length(), content="3")
  inspect(snapshot.active_subscription_kind_counts[0].kind, content="timer")
  inspect(snapshot.active_subscription_kind_counts[0].count, content="2")
  inspect(
    snapshot.active_subscription_kind_counts[1].kind,
    content="host-event",
  )
  inspect(snapshot.active_subscription_kind_counts[1].count, content="1")
  inspect(
    snapshot.active_subscription_kind_counts[2].kind,
    content="host-service",
  )
  inspect(snapshot.active_subscription_kind_counts[2].count, content="1")
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.active_subscription_kind_counts.length(), content="3")
  inspect(inspector.active_subscription_kind_counts[0].kind, content="timer")
  inspect(inspector.active_subscription_kind_counts[0].count, content="2")
}

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

///|
enum ChildEffectMsg {
  ChildEffectStart
  ChildEffectSent(String)
  ChildEffectDispatched(String)
}

///|
enum ParentEffectMsg {
  ParentChild(ChildEffectMsg)
}

///|
struct ParentEffectModel {
  child : String
  log : Array[String]
}

///|
test "program child effects map into parent messages" {
  let program = Program::new(
    init=() => ({ child: "idle", log: [] }, Effect::none()),
    update=(model, message) => {
      match message {
        ParentChild(child_message) => {
          let (child, effect) = update_child_effect(model.child, child_message)
          ({ ..model, child, }, effect.map(message => ParentChild(message)))
        }
      }
    },
    view=model => {
      View::flex(
        children=[
          child_effect_view(model.child).map(message => ParentChild(message)),
          runtime_test_label("Log " + model.log.join(",")),
        ],
        axis=Axis::Vertical,
        spacing=4.0,
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=220.0, height=96.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Child idle"))
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
  assert_true(has_draw_text(runtime.draw_commands(), "Child dispatched"))
  let snapshot = runtime.program_runtime_snapshot()
  inspect(snapshot.effect_send_count, content="1")
  inspect(snapshot.effect_dispatch_count, content="0")
  inspect(snapshot.effect_run_count, content="1")
  assert_true(
    snapshot.last_scheduled_effect_summary.root_kind ==
    EffectPlanKind::EffectPlanBatch,
  )
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors.length(),
    content="1",
  )
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors[0].key,
    content="child-effect:follow-up",
  )
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors[0].kind,
    content="child-task",
  )
  inspect(
    snapshot.last_scheduled_effect_summary.descriptors[0].label,
    content="Child follow-up",
  )
}

///|
enum ChildTaskEffectMsg {
  ChildTaskEffectStart
  ChildTaskEffectFinished(String)
}

///|
enum ParentTaskEffectMsg {
  ParentTaskEffectChild(ChildTaskEffectMsg)
}

///|
struct ParentTaskEffectModel {
  child : String
}

///|
test "mapped child service tasks complete through parent messages" {
  let child_dispatch : Ref[((ChildTaskEffectMsg) -> Unit)?] = Ref(None)
  let cleanup_count = Ref(0)
  let program = Program::new(
    init=() => ({ child: "idle" }, Effect::none()),
    update=(_model, message) => {
      match message {
        ParentTaskEffectChild(child_message) =>
          match child_message {
            ChildTaskEffectStart => {
              let effect = Effect::service_task(
                key="child-task:load",
                label="Child load",
                start=dispatch => {
                  child_dispatch.val = Some(dispatch)
                  Some(() => cleanup_count.val = cleanup_count.val + 1)
                },
              )
              (
                { child: "loading" },
                effect.map(message => ParentTaskEffectChild(message)),
              )
            }
            ChildTaskEffectFinished(value) => ({ child: value }, Effect::none())
          }
      }
    },
    view=model => {
      child_task_effect_view(model.child).map(message => {
        ParentTaskEffectChild(message)
      })
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=220.0, height=96.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Child idle"))
  runtime_wbtest_click(runtime, x=20.0, y=20.0)
  assert_true(has_draw_text(runtime.draw_commands(), "Child loading"))
  let started = runtime.program_runtime_snapshot()
  inspect(started.effect_task_count, content="1")
  inspect(started.active_effect_task_count, content="1")
  inspect(started.started_effect_task_count, content="1")
  inspect(started.completed_effect_task_count, content="0")
  inspect(started.active_effect_tasks[0].key, content="child-task:load")
  inspect(started.active_effect_tasks[0].kind, content="service")
  inspect(started.active_effect_tasks[0].label, content="Child load")
  assert_true(
    started.last_scheduled_effect_summary.root_kind ==
    EffectPlanKind::EffectPlanTask,
  )
  inspect(started.last_scheduled_effect_summary.task_count, content="1")
  inspect(
    started.last_scheduled_effect_summary.descriptors[0].key,
    content="child-task:load",
  )
  inspect(
    started.last_scheduled_effect_summary.descriptors[0].kind,
    content="service",
  )
  match child_dispatch.val {
    Some(dispatch) => dispatch(ChildTaskEffectFinished("loaded"))
    None => fail("expected mapped child task dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "Child loaded"))
  let completed = runtime.program_runtime_snapshot()
  inspect(completed.dispatched_count, content="2")
  inspect(completed.update_count, content="2")
  inspect(completed.active_effect_task_count, content="0")
  inspect(completed.completed_effect_task_count, content="1")
  inspect(completed.cancelled_effect_task_count, content="0")
  inspect(cleanup_count.val, content="0")
  assert_true(
    completed.effect_task_lifecycle.any(entry => {
      entry.key == "child-task:load" &&
      entry.kind == "service" &&
      entry.label == "Child load" &&
      entry.status == EffectTaskLifecycleStatus::EffectTaskCompleted
    }),
  )
  match child_dispatch.val {
    Some(dispatch) => dispatch(ChildTaskEffectFinished("late"))
    None => fail("expected stale mapped child task dispatch")
  }
  let stale = runtime.program_runtime_snapshot()
  inspect(stale.dispatched_count, content="2")
  inspect(stale.update_count, content="2")
  inspect(stale.ignored_effect_task_dispatch_count, content="1")
  assert_true(has_draw_text(runtime.draw_commands(), "Child loaded"))
}

///|
fn update_child_effect(
  child : String,
  message : ChildEffectMsg,
) -> (String, Effect[ChildEffectMsg]) {
  match message {
    ChildEffectStart =>
      (
        "running",
        Effect::batch([
          Effect::send(ChildEffectSent("sent")),
          Effect::run(
            key="child-effect:follow-up",
            kind="child-task",
            label="Child follow-up",
            run=dispatch => dispatch(ChildEffectDispatched("dispatched")),
          ),
        ]),
      )
    ChildEffectSent(value) => ("\{child}+\{value}", Effect::none())
    ChildEffectDispatched(value) => (value, Effect::none())
  }
}

///|
fn child_effect_view(child : String) -> View[ChildEffectMsg] {
  View::button(
    text="Child \{child}",
    size=Size::new(width=160.0, height=44.0),
    font=FontSpec::new(size=16.0),
    foreground=Color::black(),
    background=Brush::solid(Color::gray()),
    hovered_background=Brush::solid(Color::gray()),
    pressed_background=Brush::solid(Color::blue()),
    on_click=Some(ChildEffectStart),
  )
}

///|
fn child_task_effect_view(child : String) -> View[ChildTaskEffectMsg] {
  View::button(
    text="Child \{child}",
    size=Size::new(width=160.0, height=44.0),
    font=FontSpec::new(size=16.0),
    foreground=Color::black(),
    background=Brush::solid(Color::gray()),
    hovered_background=Brush::solid(Color::gray()),
    pressed_background=Brush::solid(Color::blue()),
    on_click=Some(ChildTaskEffectStart),
  )
}

///|
struct ControlledTextModel {
  draft : String
  query : String
  cleared : Bool
}

///|
enum ControlledTextMsg {
  ControlledDraftChanged(String)
  ControlledQueryChanged(String)
  ControlledSearchCleared
}

///|
fn ControlledTextModel::update(
  self : ControlledTextModel,
  message : ControlledTextMsg,
) -> ControlledTextModel {
  match message {
    ControlledDraftChanged(value) => { ..self, draft: value }
    ControlledQueryChanged(value) => { ..self, query: value }
    ControlledSearchCleared => { ..self, cleared: true }
  }
}

///|
fn ControlledTextModel::view(
  self : ControlledTextModel,
) -> View[ControlledTextMsg] {
  View::flex(
    children=[
      runtime_test_label("Draft: \{self.draft}"),
      View::controlled_text_field(
        value=self.draft,
        on_input=value => ControlledDraftChanged(value),
        placeholder="Draft",
        size=Size::new(width=240.0, height=32.0),
        font=FontSpec::new(size=14.0),
        foreground=Color::black(),
        placeholder_color=Color::gray(),
        background=Brush::solid(Color::white()),
        border=None,
        focused_border=None,
        cursor_color=Color::blue(),
      ),
      runtime_test_label("Query: \{self.query} cleared \{self.cleared}"),
      View::controlled_search_bar(
        query=self.query,
        on_input=value => ControlledQueryChanged(value),
        placeholder="Search",
        font=FontSpec::new(size=14.0),
        foreground=Color::black(),
        placeholder_color=Color::gray(),
        background=Brush::solid(Color::white()),
        border=None,
        focused_border=None,
        cursor_color=Color::blue(),
        corner_radius=8.0,
        on_clear=Some(ControlledSearchCleared),
      ),
    ],
    axis=Axis::Vertical,
    spacing=4.0,
    cross_axis_alignment=CrossStart,
  )
}

///|
test "program controlled text field and searchbar update model" {
  let program = Program::simple(
    init={ draft: "", query: "abc", cleared: false },
    update=(model, message) => model.update(message),
    view=model => model.view(),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=320.0, height=180.0),
  )
  runtime_wbtest_click(runtime, x=10.0, y=34.0)
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("Hi")))
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hi"))
  runtime_wbtest_click(runtime, x=10.0, y=100.0)
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("z")))
  assert_true(
    has_draw_text(runtime.draw_commands(), "Query: abcz cleared false"),
  )
  runtime_wbtest_click(runtime, x=222.0, y=110.0)
  assert_true(has_draw_text(runtime.draw_commands(), "Query:  cleared true"))
}

///|
test "program controlled text field rebuilds after focused text commands" {
  let program = Program::simple(
    init={ draft: "Hello", query: "abc", cleared: false },
    update=(model, message) => model.update(message),
    view=model => model.view(),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=320.0, height=180.0),
  )
  runtime_wbtest_click(runtime, x=10.0, y=34.0)
  let pasted = runtime.dispatch_focused_text_command(
    Paste,
    paste_text=Some("!"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hello!"))
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hello"))
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hello!"))
}

///|
enum ControlledChoiceMsg {
  ControlledChecked(Bool)
  ControlledPicked(String)
  ControlledDated(DateValue)
}

///|
test "controlled checkbox picker and datepicker emit new value messages" {
  let enabled_program = Program::simple(
    init=false,
    update=(_model, message) => {
      match message {
        ControlledChecked(value) => value
        _ => false
      }
    },
    view=enabled => {
      View::flex(
        children=[
          runtime_test_label("Enabled: \{enabled}"),
          View::controlled_checkbox(
            label="Enabled",
            checked=enabled,
            on_change=value => ControlledChecked(value),
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            check_color=Color::blue(),
            size=Size::new(width=20.0, height=32.0),
          ),
        ],
        axis=Axis::Vertical,
        spacing=4.0,
        cross_axis_alignment=CrossStart,
      )
    },
  )
  let enabled_runtime = AppRuntime::new_program(
    program=enabled_program,
    size=Size::new(width=240.0, height=100.0),
  )
  runtime_wbtest_click(enabled_runtime, x=10.0, y=36.0)
  assert_true(has_draw_text(enabled_runtime.draw_commands(), "Enabled: true"))

  let items = [
    PickerItem::{ id: "alpha", label: "Alpha" },
    PickerItem::{ id: "beta", label: "Beta" },
  ]
  let picker_program = Program::simple(
    init="alpha",
    update=(model, message) => {
      match message {
        ControlledPicked(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_picker(
            items~,
            selected~,
            on_select=value => ControlledPicked(value),
            placeholder="Select",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
            max_height=120.0,
          ),
        ],
        axis=Axis::Vertical,
      )
    },
  )
  let picker_runtime = AppRuntime::new_program(
    program=picker_program,
    size=Size::new(width=240.0, height=180.0),
  )
  runtime_wbtest_click(picker_runtime, x=10.0, y=10.0)
  runtime_wbtest_click(picker_runtime, x=10.0, y=90.0)
  assert_true(has_draw_text(picker_runtime.draw_commands(), "Beta"))

  let stacked_items = [
    PickerItem::{ id: "beta", label: "Beta" },
    PickerItem::{ id: "alpha", label: "Alpha" },
  ]
  let stacked_popup_program = Program::simple(
    init="alpha",
    update=(model, message) => {
      match message {
        ControlledPicked(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_picker(
            items=stacked_items,
            selected~,
            on_select=value => ControlledPicked(value),
            placeholder="Select",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
            max_height=120.0,
          ),
          View::controlled_datepicker(
            selected=DateValue::new(year=2026, month=5, day=21),
            on_select=value => ControlledDated(value),
            mode=DatePickerMode::Date,
            placeholder="Date",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
          ),
        ],
        axis=Axis::Vertical,
        spacing=0.0,
      )
    },
  )
  let stacked_runtime = AppRuntime::new_program(
    program=stacked_popup_program,
    size=Size::new(width=320.0, height=220.0),
  )
  runtime_wbtest_click(stacked_runtime, x=10.0, y=10.0)
  let stacked_open = stacked_runtime.draw_commands()
  assert_true(
    draw_text_index(stacked_open, "Beta") >
    draw_text_index(stacked_open, "2026-5-21"),
  )
  runtime_wbtest_click_draw_text(stacked_runtime, "Beta")
  let stacked_selected = stacked_runtime.draw_commands()
  assert_true(has_draw_text(stacked_selected, "Beta"))
  assert_false(has_draw_text(stacked_selected, "2026年5月"))

  let date_program = Program::simple(
    init=DateValue::new(year=2026, month=5, day=21),
    update=(model, message) => {
      match message {
        ControlledDated(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_datepicker(
            selected~,
            on_select=value => ControlledDated(value),
            mode=DatePickerMode::Date,
            placeholder="Date",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
          ),
        ],
        axis=Axis::Vertical,
      )
    },
  )
  let date_runtime = AppRuntime::new_program(
    program=date_program,
    size=Size::new(width=320.0, height=240.0),
  )
  runtime_wbtest_click(date_runtime, x=10.0, y=10.0)
  let open_date_commands = date_runtime.draw_commands()
  assert_true(has_draw_text(open_date_commands, "2026年5月"))
  assert_false(
    has_draw_text(open_date_commands, "{view_date.year}年{view_date.month}月"),
  )
  assert_false(has_draw_text(open_date_commands, "{day}"))
  guard draw_text_frame(open_date_commands, "五") is Some(friday_frame) else {
    fail("expected Friday header frame")
  }
  guard draw_text_frame(open_date_commands, "1") is Some(day_one_frame) else {
    fail("expected first day frame")
  }
  let day_one_center_x = day_one_frame.origin.x + day_one_frame.size.width / 2.0
  assert_true(day_one_center_x >= friday_frame.origin.x)
  assert_true(
    day_one_center_x <= friday_frame.origin.x + friday_frame.size.width,
  )
  runtime_wbtest_click_draw_text(date_runtime, "1")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-1"))
}

///|
test "controlled datepicker ignores dates outside min max range" {
  let date_program = Program::simple(
    init=DateValue::new(year=2026, month=5, day=21),
    update=(model, message) => {
      match message {
        ControlledDated(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_datepicker(
            selected~,
            on_select=value => ControlledDated(value),
            mode=DatePickerMode::Date,
            placeholder="Date",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
            min_date=Some(DateValue::new(year=2026, month=5, day=10)),
            max_date=Some(DateValue::new(year=2026, month=5, day=31)),
          ),
        ],
        axis=Axis::Vertical,
      )
    },
  )
  let date_runtime = AppRuntime::new_program(
    program=date_program,
    size=Size::new(width=320.0, height=240.0),
  )
  runtime_wbtest_click(date_runtime, x=10.0, y=10.0)
  runtime_wbtest_click_draw_text(date_runtime, "1")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-21"))
  runtime_wbtest_click_draw_text(date_runtime, "10")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-10"))
}

///|
fn[Msg] runtime_test_label(text : String) -> View[Msg] {
  View::text(
    text~,
    size=Size::new(width=320.0, height=24.0),
    font=FontSpec::new(size=14.0),
    color=Color::black(),
  )
}

///|
fn runtime_wbtest_click(runtime : AppRuntime, x~ : Double, y~ : Double) -> Unit {
  let position = Point::new(x~, y~)
  runtime.dispatch_event(
    AppEvent::Pointer(PointerEvent::new(position~, phase=PointerPhase::Down)),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(PointerEvent::new(position~, phase=PointerPhase::Up)),
  )
}

///|
fn runtime_wbtest_click_draw_text(
  runtime : AppRuntime,
  text : String,
) -> Unit raise {
  guard draw_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  runtime_wbtest_click(
    runtime,
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
}
