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
pub(all) struct KeyModifiers {
  shift : Bool
  control : Bool
  alt : Bool
  meta : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct KeyboardEvent {
  key : String
  text : String?
  pressed : Bool
  repeat : Bool
  modifiers : KeyModifiers
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

///|
pub fn KeyModifiers::none() -> KeyModifiers {
  { shift: false, control: false, alt: false, meta: false }
}

///|
pub fn KeyModifiers::new(
  shift? : Bool = false,
  control? : Bool = false,
  alt? : Bool = false,
  meta? : Bool = false,
) -> KeyModifiers {
  { shift, control, alt, meta }
}

///|
pub fn KeyboardEvent::new(
  key~ : String,
  pressed? : Bool = true,
  text? : String? = None,
  repeat? : Bool = false,
  modifiers? : KeyModifiers = KeyModifiers::none(),
) -> KeyboardEvent {
  { key, text, pressed, repeat, modifiers }
}
