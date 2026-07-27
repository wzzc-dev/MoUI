///|
pub struct ComponentContext {
  priv request_component_rebuild : () -> Unit
  priv scope_saveable_key : (String) -> String
  priv viewport_size : Size
  priv saveable_state : SaveableStateStore
  priv subscriptions : Array[StateSubscription]
  priv effects : Array[ComponentEffect]
  priv old_effects : Array[ComponentEffect]
  priv environment : Environment
}

///|
pub(all) struct ComponentRuntimeContextInput {
  request_component_rebuild : () -> Unit
  scope_saveable_key : (String) -> String
  viewport_size : Size
  saveable_state : SaveableStateStore
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
  old_effects : Array[ComponentEffect]
  environment : Environment
}

///|
pub fn ComponentContext::from_runtime(
  input : ComponentRuntimeContextInput,
) -> ComponentContext {
  {
    request_component_rebuild: input.request_component_rebuild,
    scope_saveable_key: input.scope_saveable_key,
    viewport_size: input.viewport_size,
    saveable_state: input.saveable_state,
    subscriptions: input.subscriptions,
    effects: input.effects,
    old_effects: input.old_effects,
    environment: input.environment,
  }
}

///|
pub fn[T] ComponentContext::watch(
  self : ComponentContext,
  state : State[T],
) -> T {
  let subscription = state.subscribe(() => (self.request_component_rebuild)())
  self.subscriptions.push(subscription)
  state.get()
}

///|
pub fn[T] ComponentContext::watch_derived(
  self : ComponentContext,
  state : DerivedState[T],
) -> T {
  for subscription in state.subscribe(() => (self.request_component_rebuild)()) {
    self.subscriptions.push(subscription)
  }
  state.get()
}

///|
pub fn[T] ComponentContext::binding(
  self : ComponentContext,
  state : State[T],
) -> Binding[T] {
  let subscription = state.subscribe(() => (self.request_component_rebuild)())
  self.subscriptions.push(subscription)
  state.binding()
}

///|
pub fn ComponentContext::view_environment(
  self : ComponentContext,
) -> ViewEnvironment {
  ViewEnvironment::new(
    viewport_size=self.viewport_size(),
    environment=self.environment,
  )
}

///|
pub fn ComponentContext::on_update(
  self : ComponentContext,
  key~ : String,
  deps~ : Array[String],
  effect : () -> (() -> Unit)?,
) -> Unit {
  let deps_key = deps.join("|")
  self.run_effect(key="update:\{key}:\{deps_key}", effect)
}

///|
pub fn ComponentContext::on_update_with_reason(
  self : ComponentContext,
  key~ : String,
  deps~ : Array[String],
  effect : () -> ((ComponentEffectCancelReason) -> Unit)?,
) -> Unit {
  let deps_key = deps.join("|")
  self.run_effect_with_reason(key="update:\{key}:\{deps_key}", effect)
}

///|
pub fn ComponentContext::on_mount(
  self : ComponentContext,
  key~ : String,
  effect : () -> Unit,
) -> Unit {
  self.run_effect(key="mount:\{key}", () => {
    effect()
    None
  })
}

///|
pub fn ComponentContext::on_unmount_with_reason(
  self : ComponentContext,
  key~ : String,
  cleanup : (ComponentEffectCancelReason) -> Unit,
) -> Unit {
  self.run_effect_with_reason(key="dispose:\{key}", () => Some(cleanup))
}

///|
pub fn ComponentContext::on_unmount(
  self : ComponentContext,
  key~ : String,
  cleanup : () -> Unit,
) -> Unit {
  self.on_dispose(key~, cleanup)
}

///|
pub fn ComponentContext::on_dispose(
  self : ComponentContext,
  key~ : String,
  cleanup : () -> Unit,
) -> Unit {
  self.run_effect(key="dispose:\{key}", () => Some(cleanup))
}

///|
fn ComponentContext::take_old_effect(
  self : ComponentContext,
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
pub fn ComponentContext::environment(self : ComponentContext) -> Environment {
  self.environment
}

///|
pub fn ComponentContext::theme(self : ComponentContext) -> Theme {
  self.environment.theme
}

///|
pub fn ComponentContext::color_scheme(self : ComponentContext) -> ColorScheme {
  self.environment.color_scheme()
}

///|
pub fn ComponentContext::scale_factor(self : ComponentContext) -> Double {
  self.environment.scale_factor
}

///|
pub fn ComponentContext::viewport_size(self : ComponentContext) -> Size {
  self.viewport_size
}

///|
pub fn ComponentContext::text_scale(self : ComponentContext) -> Double {
  self.environment.text_scale
}

///|
pub fn ComponentContext::locale(self : ComponentContext) -> String {
  self.environment.locale
}

///|
pub fn ComponentContext::layout_direction(
  self : ComponentContext,
) -> LayoutDirection {
  self.environment.layout_direction
}

///|
pub fn ComponentContext::accessibility_contrast(
  self : ComponentContext,
) -> AccessibilityContrast {
  self.environment.accessibility_contrast
}

///|
pub fn ComponentContext::reduced_motion(self : ComponentContext) -> Bool {
  self.environment.reduced_motion
}

///|
pub fn ComponentContext::content_size_category(
  self : ComponentContext,
) -> ContentSizeCategory {
  self.environment.content_size_category
}

///|
pub fn ComponentContext::enabled(self : ComponentContext) -> Bool {
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
