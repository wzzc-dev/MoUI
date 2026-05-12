///|
pub(all) enum PointerPhase {
  Move
  Down
  Up
  Cancel
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PointerEvent {
  position : Point
  phase : PointerPhase
  button : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct KeyboardEvent {
  key : String
  pressed : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RedrawReason {
  Initial
  Input
  Resize
  Explicit
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AppEvent {
  Pointer(PointerEvent)
  Keyboard(KeyboardEvent)
  Resize(Size)
  Redraw(RedrawReason)
  CloseRequested
} derive(Eq, Debug, ToJson)

///|
pub fn PointerEvent::new(
  position~ : Point,
  phase~ : PointerPhase,
  button? : Int = 0,
) -> PointerEvent {
  { position, phase, button }
}
