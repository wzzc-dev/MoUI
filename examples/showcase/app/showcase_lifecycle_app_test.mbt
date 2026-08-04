///|
test "platform timer subscription survives hidden workspace" {
  let source = @services.TimerSource::new(start=(_interval, _dispatch) => None)
  let platform = @platform.Model::new(timer_running=true, route="host-services")
  let model = { ..ShowcaseModel::new(route="components/welcome"), platform, }
  let plan = @runtime.subscription_plan_summary(
    model.subscriptions(timer_source=Some(source)),
  )
  assert_true(plan.source_count() >= 1)
}

///|
test "canvas route declares animation timer subscription" {
  let source = @services.TimerSource::new(start=(_interval, _dispatch) => None)
  let model = ShowcaseModel::new(route="platform/canvas")
  let plan = @runtime.subscription_plan_summary(
    model.subscriptions(timer_source=Some(source)),
  )
  assert_true(plan.source_count() >= 1)
  inspect(model.platform.route(), content="canvas")
  // Without a timer source, canvas cannot animate.
  let bare = ShowcaseModel::new(route="platform/canvas")
  let bare_plan = @runtime.subscription_plan_summary(bare.subscriptions())
  inspect(bare_plan.source_count(), content="0")
}

///|
test "platform effect maps through root" {
  let model = ShowcaseModel::new(route="platform/host-services")
  let (_, effect) = model.update_with_effect(
    PlatformMsg(@platform.Msg::WriteClipboard),
  )
  let summary = @runtime.effect_plan_summary(effect)
  inspect(summary.task_count(), content="1")
}
