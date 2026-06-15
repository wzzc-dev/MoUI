///|
struct ComponentEffect {
  key : String
  cleanup : (() -> Unit)?
  cleanup_with_reason : ((ComponentEffectCancelReason) -> Unit)?
  mut reused : Bool
}

///|
pub(all) enum ComponentEffectCancelReason {
  EffectKeyChanged
  EffectUnmounted
  EffectRuntimeDestroyed
} derive(Eq, Debug, ToJson)

///|
fn ComponentEffect::new(
  key~ : String,
  cleanup? : (() -> Unit)? = None,
  cleanup_with_reason? : ((ComponentEffectCancelReason) -> Unit)? = None,
) -> ComponentEffect {
  { key, cleanup, cleanup_with_reason, reused: false }
}

///|
fn ComponentEffect::cancel_with_reason(
  self : ComponentEffect,
  reason : ComponentEffectCancelReason,
) -> Unit {
  match self.cleanup_with_reason {
    Some(cleanup) => cleanup(reason)
    None => ()
  }
  match self.cleanup {
    Some(cleanup) => cleanup()
    None => ()
  }
}

///|
pub fn ComponentEffect::finish_reuse(
  old_effects : Array[ComponentEffect],
  reason? : ComponentEffectCancelReason = ComponentEffectCancelReason::EffectKeyChanged,
  cancel_reused? : Bool = false,
) -> Unit {
  for effect in old_effects {
    if cancel_reused || !effect.reused {
      effect.cancel_with_reason(reason)
    }
    effect.reused = false
  }
}

///|
pub fn BuildContext::run_effect(
  self : BuildContext,
  key~ : String,
  effect : () -> (() -> Unit)?,
) -> Unit {
  match self.take_old_effect(key) {
    Some(existing) => {
      existing.reused = true
      self.effects.push(existing)
    }
    None => self.effects.push(ComponentEffect::new(key~, cleanup=effect()))
  }
}

///|
pub fn BuildContext::run_effect_with_reason(
  self : BuildContext,
  key~ : String,
  effect : () -> ((ComponentEffectCancelReason) -> Unit)?,
) -> Unit {
  match self.take_old_effect(key) {
    Some(existing) => {
      existing.reused = true
      self.effects.push(existing)
    }
    None =>
      self.effects.push(
        ComponentEffect::new(key~, cleanup_with_reason=effect()),
      )
  }
}

///|
fn cancel_component_effects(
  effects : Array[ComponentEffect],
  reason? : ComponentEffectCancelReason = ComponentEffectCancelReason::EffectUnmounted,
) -> Unit {
  ComponentEffect::finish_reuse(effects, reason~, cancel_reused=true)
}
