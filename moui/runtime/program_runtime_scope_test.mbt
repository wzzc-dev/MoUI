///|
priv enum ScopeLifecycleTestMsg {
  ToggleRightSubscription
  LeftDelta(Int32)
  RightDelta(Int32)
}

///|
priv struct ScopeLifecycleTestModel {
  left : Int32
  right : Int32
  right_subscription_enabled : Bool
}

///|
fn scope_lifecycle_left_read(model : ScopeLifecycleTestModel) -> Int32 {
  model.left
}

///|
fn scope_lifecycle_left_write(
  child : Int32,
  model : ScopeLifecycleTestModel,
) -> ScopeLifecycleTestModel {
  { ..model, left: child, }
}

///|
fn scope_lifecycle_right_read(model : ScopeLifecycleTestModel) -> Int32 {
  model.right
}

///|
fn scope_lifecycle_right_write(
  child : Int32,
  model : ScopeLifecycleTestModel,
) -> ScopeLifecycleTestModel {
  { ..model, right: child, }
}

///|
fn scope_lifecycle_initial_model() -> ScopeLifecycleTestModel {
  { left: 0, right: 0, right_subscription_enabled: true, }
}

///|
fn scope_lifecycle_view(
  _model : ScopeLifecycleTestModel,
) -> @core.View[ScopeLifecycleTestMsg] {
  runtime_test_rect(
    width=100.0,
    height=100.0,
    color=@core.Color::blue(),
    on_tap=Some(ToggleRightSubscription),
  )
}

///|
fn scope_lifecycle_update(
  model : ScopeLifecycleTestModel,
  message : ScopeLifecycleTestMsg,
) -> (ScopeLifecycleTestModel, @core.Effect[ScopeLifecycleTestMsg]) {
  let next = match message {
    ToggleRightSubscription => { ..model, right_subscription_enabled: false, }
    LeftDelta(delta) => { ..model, left: model.left + delta, }
    RightDelta(delta) => { ..model, right: model.right + delta, }
  }
  (next, @core.Effect::none())
}

///|
fn scope_lifecycle_tick_feature(
  label : String,
  started : Array[String],
  cleaned : Array[String],
  dispatch_out : Ref[((Int32) -> Unit)?],
) -> @core.Feature[Int32, Int32] {
  @core.Feature::new(
    init=() => (0, @core.Effect::none()),
    update=(model, message) => (model + message, @core.Effect::none()),
    view=_model => @views.empty(),
    subscriptions=_model => {
      @core.Subscription::timer(key="tick", start=dispatch => {
        started.push(label)
        dispatch_out.val = Some(dispatch)
        Some(() => cleaned.push(label))
      })
    },
  )
}

///|
fn scope_lifecycle_task_feature(
  label : String,
  started : Array[String],
  cleaned : Array[String],
  dispatch_out : Ref[((Int32) -> Unit)?],
) -> @core.Feature[Int32, Int32] {
  @core.Feature::new(
    init=() => {
      (
        0,
        @core.Effect::task(key="load", start=dispatch => {
          started.push(label)
          dispatch_out.val = Some(dispatch)
          Some(() => cleaned.push(label))
        }),
      )
    },
    update=(model, message) => (model + message, @core.Effect::none()),
    view=_model => @views.empty(),
  )
}

///|
test "feature scopes isolate subscriptions and preserve cancel semantics" {
  let started : Array[String] = []
  let cleaned : Array[String] = []
  let left_dispatch : Ref[((Int32) -> Unit)?] = Ref(None)
  let right_dispatch : Ref[((Int32) -> Unit)?] = Ref(None)
  let left = scope_lifecycle_tick_feature(
    "left", started, cleaned, left_dispatch,
  ).scope(
    scope_id="left",
    read=scope_lifecycle_left_read,
    write=scope_lifecycle_left_write,
    wrap=message => LeftDelta(message),
  )
  let right = scope_lifecycle_tick_feature(
    "right", started, cleaned, right_dispatch,
  ).scope(
    scope_id="right",
    read=scope_lifecycle_right_read,
    write=scope_lifecycle_right_write,
    wrap=message => RightDelta(message),
  )
  let program = @core.Program::new(
    init=() => (scope_lifecycle_initial_model(), @core.Effect::none()),
    update=scope_lifecycle_update,
    view=scope_lifecycle_view,
    subscriptions=model => {
      let left_subscription = left.subscriptions(model)
      if model.right_subscription_enabled {
        @core.Subscription::batch([
          left_subscription,
          right.subscriptions(model),
        ])
      } else {
        left_subscription
      }
    },
  )
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_eq(started, ["left", "right"])
  let active = runtime.program_runtime_snapshot()
  assert_eq(active.active_subscription_count(), 2)
  assert_eq(active.duplicate_subscription_key_count(), 0)
  assert_eq(active.active_subscriptions().map(descriptor => descriptor.key()), [
    "left/tick", "right/tick",
  ])
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(position=@core.Point::new(x=5.0, y=5.0), phase=Up),
    ),
  )
  assert_eq(cleaned, ["right"])
  let removed = runtime.program_runtime_snapshot()
  assert_eq(removed.active_subscription_count(), 1)
  assert_eq(removed.cancelled_subscription_count(), 1)
  assert_eq(
    removed.active_subscriptions().map(descriptor => descriptor.key()),
    ["left/tick"],
  )
  match right_dispatch.val {
    Some(dispatch) => dispatch(7)
    None => fail("expected the right subscription dispatcher")
  }
  let stale = runtime.program_runtime_snapshot()
  assert_eq(stale.ignored_subscription_dispatch_count(), 1)
  assert_eq(stale.active_subscription_count(), 1)
}

///|
test "feature scopes keep identical effect task keys independent" {
  let started : Array[String] = []
  let cleaned : Array[String] = []
  let left_dispatch : Ref[((Int32) -> Unit)?] = Ref(None)
  let right_dispatch : Ref[((Int32) -> Unit)?] = Ref(None)
  let left = scope_lifecycle_task_feature(
    "left", started, cleaned, left_dispatch,
  ).scope(
    scope_id="left",
    read=scope_lifecycle_left_read,
    write=scope_lifecycle_left_write,
    wrap=message => LeftDelta(message),
  )
  let right = scope_lifecycle_task_feature(
    "right", started, cleaned, right_dispatch,
  ).scope(
    scope_id="right",
    read=scope_lifecycle_right_read,
    write=scope_lifecycle_right_write,
    wrap=message => RightDelta(message),
  )
  let program = @core.Program::new(
    init=() => {
      let (_, left_effect) = left.init()
      let (_, right_effect) = right.init()
      (
        scope_lifecycle_initial_model(),
        @core.Effect::batch([left_effect, right_effect]),
      )
    },
    update=scope_lifecycle_update,
    view=scope_lifecycle_view,
  )
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_eq(started, ["left", "right"])
  let active = runtime.program_runtime_snapshot()
  assert_eq(active.active_effect_task_count(), 2)
  assert_eq(active.superseded_effect_task_key_count(), 0)
  assert_eq(active.active_effect_tasks().map(descriptor => descriptor.key()), [
    "left/load", "right/load",
  ])
  match left_dispatch.val {
    Some(dispatch) => dispatch(1)
    None => fail("expected the left effect task dispatcher")
  }
  let completed = runtime.program_runtime_snapshot()
  assert_eq(completed.completed_effect_task_count(), 1)
  assert_eq(completed.active_effect_task_count(), 1)
  match left_dispatch.val {
    Some(dispatch) => dispatch(1)
    None => fail("expected the completed effect task dispatcher")
  }
  let stale = runtime.program_runtime_snapshot()
  assert_eq(stale.ignored_effect_task_dispatch_count(), 1)
  assert_eq(stale.active_effect_task_count(), 1)
  runtime.destroy()
  let destroyed = runtime.program_runtime_snapshot()
  assert_eq(destroyed.active_effect_task_count(), 0)
  assert_eq(destroyed.cancelled_effect_task_count(), 1)
  assert_eq(cleaned, ["right"])
}
