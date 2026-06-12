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
