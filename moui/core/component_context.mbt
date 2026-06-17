///|
pub struct BuildContext {
  priv component_id : ElementId
  priv request_component_rebuild : (ElementId) -> Unit
  priv viewport_size : Size
  priv saveable_state : SaveableStateStore
  priv subscriptions : Array[StateSubscription]
  priv effects : Array[ComponentEffect]
  priv old_effects : Array[ComponentEffect]
  priv environment : Environment
}

///|
pub fn BuildContext::new_for_runtime(
  component_id~ : ElementId,
  request_component_rebuild~ : (ElementId) -> Unit,
  viewport_size~ : Size,
  saveable_state~ : SaveableStateStore,
  subscriptions~ : Array[StateSubscription],
  effects~ : Array[ComponentEffect],
  old_effects~ : Array[ComponentEffect],
  environment~ : Environment,
) -> BuildContext {
  {
    component_id,
    request_component_rebuild,
    viewport_size,
    saveable_state,
    subscriptions,
    effects,
    old_effects,
    environment,
  }
}

///|
pub fn[T] BuildContext::watch(self : BuildContext, state : State[T]) -> T {
  let component_id = self.component_id
  let subscription = state.subscribe(() => {
    (self.request_component_rebuild)(component_id)
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
      (self.request_component_rebuild)(component_id)
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
    (self.request_component_rebuild)(component_id)
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
  self.viewport_size
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
struct ViewEnvironment {
  viewport_size : Size
  environment : Environment
}

///|
pub fn ViewEnvironment::new(
  viewport_size~ : Size,
  environment~ : Environment,
) -> ViewEnvironment {
  { viewport_size, environment }
}

///|
pub fn ViewEnvironment::viewport_size(self : ViewEnvironment) -> Size {
  self.viewport_size
}

///|
pub fn ViewEnvironment::environment(self : ViewEnvironment) -> Environment {
  self.environment
}
