///|
priv struct ComponentBuildResult {
  child_view_node : &RuntimeViewNode
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
}

///|
fn build_component_child(
  view_node : &RuntimeViewNode,
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
    request_component_rebuild: () => {
      runtime.request_component_rebuild(component_id)
    },
    scope_saveable_key: key => "\{component_id.value()}:\{key}",
    viewport_size: runtime.size,
    saveable_state: runtime.saveable_state,
    subscriptions,
    effects,
    old_effects,
    environment: runtime.environment,
  })
  let child_view_node = match view_node.build_child(context) {
    Some(child) => child
    None => empty_runtime_view_node()
  }
  ComponentEffect::finish_reuse(
    old_effects,
    reason=ComponentEffectCancelReason::EffectKeyChanged,
  )
  { child_view_node, subscriptions, effects }
}
