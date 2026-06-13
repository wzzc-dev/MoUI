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
