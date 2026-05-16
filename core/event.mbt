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
  wheel_delta : Point
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
pub(all) struct TextRange {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct CompositionUpdate {
  text : String
  cursor : TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum TextInputEvent {
  InsertText(String)
  CompositionStart
  CompositionUpdate(CompositionUpdate)
  CompositionEnd(String)
  DeleteRange(TextRange)
  DeleteSurrounding(Int, Int)
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
  TextInput(TextInputEvent)
  Resize(Size)
  Redraw(RedrawReason)
  CloseRequested
} derive(Eq, Debug, ToJson)

///|
pub fn PointerEvent::new(
  position~ : Point,
  phase~ : PointerPhase,
  button? : Int = 0,
  wheel_delta? : Point = Point::new(x=0.0, y=0.0),
) -> PointerEvent {
  { position, phase, button, wheel_delta }
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

///|
pub fn TextRange::new(start~ : Int, end~ : Int) -> TextRange {
  { start, end }
}

///|
pub fn TextRange::collapsed(index : Int) -> TextRange {
  { start: index, end: index }
}

///|
pub fn TextRange::normalized(self : TextRange) -> TextRange {
  if self.start <= self.end {
    self
  } else {
    { start: self.end, end: self.start }
  }
}

///|
pub fn TextRange::is_collapsed(self : TextRange) -> Bool {
  self.start == self.end
}

///|
pub fn CompositionUpdate::new(
  text~ : String,
  cursor? : TextRange? = None,
) -> CompositionUpdate {
  { text, cursor }
}
