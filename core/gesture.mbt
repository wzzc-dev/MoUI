///|
pub(all) struct TapGestureResult {
  next_state : ButtonState
  activated : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HitTestEntry {
  element_id : ElementId
  local_position : Point
  frame : Rect
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HitTestResult {
  path : Array[HitTestEntry]
} derive(Eq, Debug, ToJson)

///|
pub fn recognize_button_tap(
  current : ButtonState,
  inside : Bool,
  phase : PointerPhase,
) -> TapGestureResult {
  let next_state = match phase {
    Move =>
      if current == Pressed && inside {
        Pressed
      } else if inside {
        Hovered
      } else {
        Normal
      }
    Down => if inside { Pressed } else { Normal }
    Up => if inside { Hovered } else { Normal }
    Cancel => Normal
  }
  { next_state, activated: phase == Up && inside && current == Pressed }
}
