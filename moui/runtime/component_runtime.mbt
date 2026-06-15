///|
priv struct Component {
  build : (@core.BuildContext) -> ViewSpec
}

///|
priv struct ComponentBuildResult {
  child_spec : ViewSpec
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
}

///|
fn Component::new(build : (@core.BuildContext) -> ViewSpec) -> Component {
  { build, }
}

///|
fn build_component_spec(
  component : Component,
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
  let context = @core.BuildContext::new_for_runtime(
    component_id~,
    request_component_rebuild=id => runtime.request_component_rebuild(id),
    viewport_size=runtime.size,
    saveable_state=runtime.saveable_state,
    subscriptions~,
    effects~,
    old_effects~,
    environment=runtime.environment,
  )
  let child_spec = (component.build)(context)
  ComponentEffect::finish_reuse(
    old_effects,
    reason=ComponentEffectCancelReason::EffectKeyChanged,
  )
  { child_spec, subscriptions, effects }
}
