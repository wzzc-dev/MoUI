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
test "effect plan summary describes nested effect structure" {
  let effect : Effect[String] = Effect::batch([
    Effect::send("first"),
    Effect::batch([
      Effect::none(),
      Effect::run(
        key="host:load",
        kind="host-service",
        label="Load host data",
        run=_dispatch => (),
      ),
    ]),
  ])
  let summary = effect.plan_summary()
  assert_true(summary.root_kind == EffectPlanKind::EffectPlanBatch)
  inspect(summary.batch_count, content="2")
  inspect(summary.none_count, content="1")
  inspect(summary.send_count, content="1")
  inspect(summary.dispatch_count, content="0")
  inspect(summary.run_count, content="1")
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
    Effect::run(key="host:sync", kind="host-service", label="Sync host data", run=_dispatch => {
      ()
    }),
    Effect::batch([
      Effect::run(
        key="host:sync",
        kind="host-service",
        label="Duplicate sync",
        run=_dispatch => (),
      ),
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
  let nested = match effect {
    Effect::Batch([_, child]) => child.plan_summary()
    _ => fail("expected nested effect batch")
  }
  inspect(nested.descriptors.length(), content="2")
  inspect(nested.duplicate_descriptor_key_count, content="0")
}

///|
test "program runtime aggregates duplicate structured effect keys" {
  let program = Program::new(
    init=() => {
      let effect : Effect[String] = Effect::batch([
        Effect::run(
          key="host:sync",
          kind="host-service",
          label="Sync host data",
          run=_dispatch => (),
        ),
        Effect::run(
          key="host:sync",
          kind="host-service",
          label="Duplicate sync",
          run=_dispatch => (),
        ),
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
  inspect(program_snapshot.last_effect_summary.run_count, content="2")
  inspect(
    program_snapshot.last_effect_summary.duplicate_descriptor_key_count,
    content="1",
  )
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_effect_run_count, content="2")
  inspect(inspector.duplicate_effect_descriptor_key_count, content="1")
  inspect(inspector.last_effect_summary.descriptors.length(), content="2")
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
test "subscription descriptors and map preserve feature composition" {
  let child_dispatch : Ref[((String) -> Unit)?] = Ref(None)
  let child = Subscription::batch([
    Subscription::none(),
    Subscription::run(key="child-tick", kind="timer", label="Child tick", start=dispatch => {
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
  match child_dispatch.val {
    Some(dispatch) => dispatch("pulse")
    None => fail("expected child dispatch")
  }
  assert_true(has_draw_text(runtime.draw_commands(), "parent:pulse"))
}

///|
enum ProgramSubscriptionMsg {
  ProgramSubscriptionToggle
  ProgramSubscriptionTick
}

///|
struct ProgramSubscriptionModel {
  channel : String
  ticks : Int
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
      Subscription::run(
        key="timer:\{model.channel}",
        kind="timer",
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
        Subscription::listen(key="instant", kind="timer", label="Instant", start=dispatch => {
          start_count.val = start_count.val + 1
          dispatch(ProgramSubscriptionTick)
          None
        }),
        Subscription::listen(
          key="instant",
          kind="timer",
          label="Duplicate ignored",
          start=_dispatch => {
            start_count.val = start_count.val + 1
            None
          },
        ),
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
    snapshot.last_subscription_plan_summary.duplicate_key_count,
    content="1",
  )
  inspect(snapshot.started_subscription_count, content="1")
  inspect(snapshot.reused_subscription_count, content="1")
  inspect(snapshot.duplicate_subscription_key_count, content="2")
  inspect(snapshot.active_subscription_count, content="1")
  inspect(snapshot.active_subscriptions[0].label, content="Instant")
  inspect(snapshot.dispatched_count, content="1")
  let inspector = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(inspector.program_subscription_plan_count, content="2")
  inspect(
    inspector.last_subscription_plan_summary.duplicate_key_count,
    content="1",
  )
  inspect(inspector.reused_subscription_count, content="1")
  inspect(inspector.duplicate_subscription_key_count, content="2")
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
          Effect::dispatch(dispatch => {
            dispatch(ChildEffectDispatched("dispatched"))
          }),
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
  runtime_wbtest_click(date_runtime, x=300.0, y=148.0)
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
  runtime_wbtest_click(date_runtime, x=300.0, y=148.0)
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-21"))
  runtime_wbtest_click(date_runtime, x=70.0, y=220.0)
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
