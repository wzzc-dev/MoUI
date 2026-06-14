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
  let runtime = RuntimeKernel::new_program(
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
  let runtime = RuntimeKernel::new_program(
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
      View::primitive_button_view(
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
  let runtime = RuntimeKernel::new_program(
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
      View::primitive_button_view(
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
  let runtime = RuntimeKernel::new_program(
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
