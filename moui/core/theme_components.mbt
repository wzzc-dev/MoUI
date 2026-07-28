///|
/// Neutral interaction state machine. This is the token-layer state enum used
/// to select a resolved style from a component theme. It is the union of
/// states every component theme needs to resolve
/// (normal/hovered/pressed/focused/disabled/selected/invalid); individual
/// controls only pass the subset they support.
///
/// `InteractionState` stays in `core` (ADR 0017) because it is the neutral
/// gesture/interaction state machine consumed by core's own view-tree,
/// gesture, and semantics layers — it is not control vocabulary. The concrete
/// control theme token structs (`ButtonTheme`, `ControlStateTokens`,
/// `ComponentThemes`, …) moved to `moui/views` as `ControlThemeSet`; this
/// file no longer carries control-specific types.
pub(all) enum InteractionState {
  Normal
  Hovered
  Pressed
  Focused
  Disabled
  Selected
  Invalid
} derive(Eq, Debug, ToJson)

///|
/// Convert a runtime `PressableState` (gesture-driven three-state, defined in
/// `view_style.mbt`) into the token-layer `InteractionState` for component
/// theme resolution. Kept in `core` because both sides are neutral core
/// types; `moui/views` reads this when resolving a `ControlThemeSet`.
pub fn PressableState::to_interaction(self : PressableState) -> InteractionState {
  match self {
    Normal => InteractionState::Normal
    Hovered => InteractionState::Hovered
    Pressed => InteractionState::Pressed
  }
}
