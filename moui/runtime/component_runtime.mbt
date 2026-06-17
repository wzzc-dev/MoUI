///|
priv struct ComponentBuildResult {
  child_widget : RuntimeWidget
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
}

///|
fn build_component_child(
  build : (@core.BuildContext) -> RuntimeWidget,
  runtime : RuntimeState,
  component_id : ElementId,
  old_subscriptions : Array[StateSubscription],
  old_effects : Array[ComponentEffect],
) -> ComponentBuildResult {
  for subscription in old_subscriptions {
    subscription.cancel()
  }
  let subscriptions : Array[StateSubscription] = []
  let effects : Array[ComponentEffect] = []
  let context = @core.BuildContext::new(
    component_id~,
    request_component_rebuild=id => runtime.request_component_rebuild(id),
    viewport_size=runtime.size,
    saveable_state=runtime.saveable_state,
    subscriptions~,
    effects~,
    old_effects~,
    environment=runtime.environment,
  )
  let child_widget = build(context)
  ComponentEffect::finish_reuse(
    old_effects,
    reason=ComponentEffectCancelReason::EffectKeyChanged,
  )
  { child_widget, subscriptions, effects }
}
