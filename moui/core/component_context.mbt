///|
pub struct BuildContext {
  priv runtime : RuntimeState
  priv component_id : ElementId
  priv subscriptions : Array[StateSubscription]
  priv effects : Array[ComponentEffect]
  priv old_effects : Array[ComponentEffect]
  priv environment : Environment
}

///|
priv struct Component {
  build : (BuildContext) -> ViewSpec
}

///|
priv struct ComponentBuildResult {
  child_spec : ViewSpec
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
}

///|
fn Component::new(build : (BuildContext) -> ViewSpec) -> Component {
  { build, }
}

///|
pub fn[T] BuildContext::watch(self : BuildContext, state : State[T]) -> T {
  let component_id = self.component_id
  let subscription = state.subscribe(() => {
    self.runtime.request_component_rebuild(component_id)
  })
  self.subscriptions.push(subscription)
  state.get()
}

///|
pub fn[T] BuildContext::watch_derived(
  self : BuildContext,
  state : DerivedState[T],
) -> T {
  let component_id = self.component_id
  for
    subscription in state.subscribe(() => {
      self.runtime.request_component_rebuild(component_id)
    }) {
    self.subscriptions.push(subscription)
  }
  state.get()
}

///|
pub fn[T] BuildContext::binding(
  self : BuildContext,
  state : State[T],
) -> Binding[T] {
  let component_id = self.component_id
  let subscription = state.subscribe(() => {
    self.runtime.request_component_rebuild(component_id)
  })
  self.subscriptions.push(subscription)
  state.binding()
}

///|
pub fn BuildContext::view_environment(self : BuildContext) -> ViewEnvironment {
  ViewEnvironment::new(
    viewport_size=self.viewport_size(),
    environment=self.environment,
  )
}

///|
pub fn BuildContext::on_update(
  self : BuildContext,
  key~ : String,
  deps~ : Array[String],
  effect : () -> (() -> Unit)?,
) -> Unit {
  let deps_key = deps.join("|")
  self.run_effect(key="update:\{key}:\{deps_key}", effect)
}

///|
pub fn BuildContext::on_update_with_reason(
  self : BuildContext,
  key~ : String,
  deps~ : Array[String],
  effect : () -> ((ComponentEffectCancelReason) -> Unit)?,
) -> Unit {
  let deps_key = deps.join("|")
  self.run_effect_with_reason(key="update:\{key}:\{deps_key}", effect)
}

///|
pub fn BuildContext::on_mount(
  self : BuildContext,
  key~ : String,
  effect : () -> Unit,
) -> Unit {
  self.run_effect(key="mount:\{key}", () => {
    effect()
    None
  })
}

///|
pub fn BuildContext::on_unmount_with_reason(
  self : BuildContext,
  key~ : String,
  cleanup : (ComponentEffectCancelReason) -> Unit,
) -> Unit {
  self.run_effect_with_reason(key="dispose:\{key}", () => Some(cleanup))
}

///|
pub fn BuildContext::on_unmount(
  self : BuildContext,
  key~ : String,
  cleanup : () -> Unit,
) -> Unit {
  self.on_dispose(key~, cleanup)
}

///|
pub fn BuildContext::on_dispose(
  self : BuildContext,
  key~ : String,
  cleanup : () -> Unit,
) -> Unit {
  self.run_effect(key="dispose:\{key}", () => Some(cleanup))
}

///|
fn BuildContext::take_old_effect(
  self : BuildContext,
  key : String,
) -> ComponentEffect? {
  for effect in self.old_effects {
    if !effect.reused && effect.key == key {
      return Some(effect)
    }
  }
  None
}

///|
pub fn BuildContext::environment(self : BuildContext) -> Environment {
  self.environment
}

///|
pub fn BuildContext::theme(self : BuildContext) -> Theme {
  self.environment.theme
}

///|
pub fn BuildContext::color_scheme(self : BuildContext) -> ColorScheme {
  self.environment.color_scheme
}

///|
pub fn BuildContext::scale_factor(self : BuildContext) -> Double {
  self.environment.scale_factor
}

///|
pub fn BuildContext::viewport_size(self : BuildContext) -> Size {
  self.runtime.size
}

///|
pub fn BuildContext::text_scale(self : BuildContext) -> Double {
  self.environment.text_scale
}

///|
pub fn BuildContext::locale(self : BuildContext) -> String {
  self.environment.locale
}

///|
pub fn BuildContext::layout_direction(self : BuildContext) -> LayoutDirection {
  self.environment.layout_direction
}

///|
pub fn BuildContext::accessibility_contrast(
  self : BuildContext,
) -> AccessibilityContrast {
  self.environment.accessibility_contrast
}

///|
pub fn BuildContext::reduced_motion(self : BuildContext) -> Bool {
  self.environment.reduced_motion
}

///|
pub fn BuildContext::content_size_category(
  self : BuildContext,
) -> ContentSizeCategory {
  self.environment.content_size_category
}

///|
pub fn BuildContext::enabled(self : BuildContext) -> Bool {
  self.environment.enabled
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
  let context = BuildContext::{
    runtime,
    component_id,
    subscriptions,
    effects,
    old_effects,
    environment: runtime.environment,
  }
  let child_spec = (component.build)(context)
  for effect in old_effects {
    if !effect.reused {
      effect.cancel_with_reason(ComponentEffectCancelReason::EffectKeyChanged)
    }
    effect.reused = false
  }
  { child_spec, subscriptions, effects }
}
