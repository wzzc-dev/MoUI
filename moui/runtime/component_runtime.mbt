///|
priv struct ComponentBuildResult {
  child_erased_view_node : ErasedViewNode
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
}

///|
fn build_component_child(
  build : (@core.ComponentContext) -> ErasedViewNode,
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
  let context = @core.ComponentContext::from_runtime({
    component_id,
    request_component_rebuild: id => runtime.request_component_rebuild(id),
    viewport_size: runtime.size,
    saveable_state: runtime.saveable_state,
    subscriptions,
    effects,
    old_effects,
    environment: runtime.environment,
  })
  let child_erased_view_node = build(context)
  ComponentEffect::finish_reuse(
    old_effects,
    reason=ComponentEffectCancelReason::EffectKeyChanged,
  )
  { child_erased_view_node, subscriptions, effects }
}
