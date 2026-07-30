///|
/// `View::apply_modifier` is the shared entry point that wraps a child view
/// with any modifier. It delegates to `modifier_view` which creates a
/// `ModifierViewNode` wrapping the child with an `AnyModifier[Msg]` vtable.
fn[Msg] View::apply_modifier(
  self : View[Msg],
  modifier : AnyModifier[Msg],
) -> View[Msg] {
  modifier_view(self, modifier)
}

///|
/// Returns the first child size from a layout context, or zero if empty.
/// Used by modifier layout closures.
fn first_modifier_child_size(sizes : Array[Size]) -> Size {
  match sizes {
    [size, ..] => size
    [] => Size::new(width=0.0, height=0.0)
  }
}

///|
/// Map a `ViewStateContext` to a `PressableState` for gesture recognition.
fn view_state_to_pressable_state(state : ViewStateContext) -> PressableState {
  if state.pressed {
    PressableState::Pressed
  } else if state.hovered {
    PressableState::Hovered
  } else {
    PressableState::Normal
  }
}

///|
/// Map a `PressableState` back to a `ViewStateContext` for gesture feedback.
fn pressable_state_to_view_state(
  state : ViewStateContext,
  pressable_state : PressableState,
) -> ViewStateContext {
  match pressable_state {
    PressableState::Normal => { ..state, hovered: false, pressed: false }
    PressableState::Hovered => { ..state, hovered: true, pressed: false }
    PressableState::Pressed => { ..state, hovered: true, pressed: true }
  }
}
