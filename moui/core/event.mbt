///|
/// Pointer interaction phase. `Move`/`Down`/`Up`/`Cancel` are produced by host
/// backends from raw input. `Exit` is a synthetic, runtime-only phase: the
/// runtime emits it to the previously hovered element when the pointer leaves
/// its bounds (host backends never produce it). Views use it to clear hover
/// state that they otherwise could not, because a normal `Move` outside the
/// element is never delivered to it by hit-testing.
pub(all) enum PointerPhase {
  Move
  Down
  Up
  Cancel
  Exit
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PointerEvent {
  position : Point
  phase : PointerPhase
  button : Int
  wheel_delta : Point
  time_ms : Double
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
struct CompositionUpdate {
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
pub(all) enum DragDropPhase {
  Entered
  Moved
  Dropped
  Left
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DragDropEvent {
  phase : DragDropPhase
  paths : Array[String]
  position : Point?
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
  FrameTick(Frame)
  Pointer(PointerEvent)
  Keyboard(KeyboardEvent)
  TextInput(TextInputEvent)
  DragDrop(DragDropEvent)
  PlatformView(String, PlatformViewEvent)
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
  time_ms? : Double = 0.0,
) -> PointerEvent {
  { position, phase, button, wheel_delta, time_ms }
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

///|
pub fn CompositionUpdate::text(self : CompositionUpdate) -> String {
  self.text
}

///|
pub fn CompositionUpdate::cursor(self : CompositionUpdate) -> TextRange? {
  self.cursor
}

///|
pub fn DragDropEvent::new(
  phase~ : DragDropPhase,
  paths? : Array[String] = [],
  position? : Point? = None,
) -> DragDropEvent {
  { phase, paths, position }
}
