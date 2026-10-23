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
pub extend PointerPhase with Debug::{to_repr}

///|
pub extend PointerPhase with Eq::{not_equal, equal}

///|
pub extend PointerPhase with ToJson::{to_json}

///|
/// `id` distinguishes simultaneous pointers. `0` is the primary stream: mouse,
/// pen, trackpad, and any host that does not report a finger identity. Secondary
/// fingers carry the host's own finger id, so a view can tell a two-finger
/// gesture apart from two independent one-finger drags.
///
/// `pressure` is normalized to `0.0..=1.0`. `1.0` means "the host gives no
/// pressure signal", which is the value for mouse and touchpad input on every
/// platform MoUI currently supports; views must treat it as a full press rather
/// than checking for `> 0.0`.
pub(all) struct PointerEvent {
  position : Point
  phase : PointerPhase
  button : Int32
  wheel_delta : Point
  modifiers : KeyModifiers
  id : Int32
  pressure : Double
} derive(Eq, Debug, ToJson)

///|
pub extend PointerEvent with Debug::{to_repr}

///|
pub extend PointerEvent with Eq::{not_equal, equal}

///|
pub extend PointerEvent with ToJson::{to_json}

///|
pub(all) struct KeyModifiers {
  shift : Bool
  control : Bool
  alt : Bool
  meta : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend KeyModifiers with Debug::{to_repr}

///|
pub extend KeyModifiers with Eq::{not_equal, equal}

///|
pub extend KeyModifiers with ToJson::{to_json}

///|
pub(all) struct KeyboardEvent {
  key : String
  text : String?
  pressed : Bool
  repeat : Bool
  modifiers : KeyModifiers
} derive(Eq, Debug, ToJson)

///|
pub extend KeyboardEvent with Debug::{to_repr}

///|
pub extend KeyboardEvent with Eq::{not_equal, equal}

///|
pub extend KeyboardEvent with ToJson::{to_json}

///|
pub(all) struct TextRange {
  start : Int32
  end : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend TextRange with Debug::{to_repr}

///|
pub extend TextRange with Eq::{not_equal, equal}

///|
pub extend TextRange with ToJson::{to_json}

///|
struct CompositionUpdate {
  text : String
  cursor : TextRange?
} derive(Eq, Debug, ToJson)

///|
pub extend CompositionUpdate with Debug::{to_repr}

///|
pub extend CompositionUpdate with Eq::{not_equal, equal}

///|
pub extend CompositionUpdate with ToJson::{to_json}

///|
pub(all) enum TextInputEvent {
  InsertText(String)
  ReplaceText(TextRange, String)
  SetSelection(TextRange)
  CompositionStart
  CompositionUpdate(CompositionUpdate)
  CompositionEnd(String)
  DeleteRange(TextRange)
  DeleteSurrounding(Int32, Int32)
} derive(Eq, Debug, ToJson)

///|
pub extend TextInputEvent with Debug::{to_repr}

///|
pub extend TextInputEvent with Eq::{not_equal, equal}

///|
pub extend TextInputEvent with ToJson::{to_json}

///|
pub(all) enum DragDropPhase {
  Entered
  Moved
  Dropped
  Left
} derive(Eq, Debug, ToJson)

///|
pub extend DragDropPhase with Debug::{to_repr}

///|
pub extend DragDropPhase with Eq::{not_equal, equal}

///|
pub extend DragDropPhase with ToJson::{to_json}

///|
pub(all) struct DragDropEvent {
  phase : DragDropPhase
  paths : Array[String]
  position : Point?
} derive(Eq, Debug, ToJson)

///|
pub extend DragDropEvent with Debug::{to_repr}

///|
pub extend DragDropEvent with Eq::{not_equal, equal}

///|
pub extend DragDropEvent with ToJson::{to_json}

///|
pub(all) enum RedrawReason {
  Initial
  Input
  Resize
  Explicit
} derive(Eq, Debug, ToJson)

///|
pub extend RedrawReason with Debug::{to_repr}

///|
pub extend RedrawReason with Eq::{not_equal, equal}

///|
pub extend RedrawReason with ToJson::{to_json}

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
pub extend AppEvent with Debug::{to_repr}

///|
pub extend AppEvent with Eq::{not_equal, equal}

///|
pub extend AppEvent with ToJson::{to_json}

///|
pub fn PointerEvent::new(
  position~ : Point,
  phase~ : PointerPhase,
  button~ : Int32 = 0,
  wheel_delta~ : Point = Point::new(x=0.0, y=0.0),
  modifiers~ : KeyModifiers = KeyModifiers::none(),
  id~ : Int32 = 0,
  pressure~ : Double = 1.0,
) -> PointerEvent {
  { position, phase, button, wheel_delta, modifiers, id, pressure, }
}

///|
pub fn KeyModifiers::none() -> KeyModifiers {
  { shift: false, control: false, alt: false, meta: false, }
}

///|
pub fn KeyModifiers::new(
  shift~ : Bool = false,
  control~ : Bool = false,
  alt~ : Bool = false,
  meta~ : Bool = false,
) -> KeyModifiers {
  { shift, control, alt, meta, }
}

///|
pub fn KeyboardEvent::new(
  key~ : String,
  pressed~ : Bool = true,
  text~ : String? = None,
  repeat~ : Bool = false,
  modifiers~ : KeyModifiers = KeyModifiers::none(),
) -> KeyboardEvent {
  { key, text, pressed, repeat, modifiers, }
}

///|
pub fn TextRange::new(start~ : Int32, end~ : Int32) -> TextRange {
  { start, end, }
}

///|
pub fn TextRange::collapsed(index : Int32) -> TextRange {
  { start: index, end: index, }
}

///|
pub fn TextRange::normalized(self : TextRange) -> TextRange {
  if self.start <= self.end {
    self
  } else {
    { start: self.end, end: self.start, }
  }
}

///|
pub fn TextRange::is_collapsed(self : TextRange) -> Bool {
  self.start == self.end
}

///|
pub fn CompositionUpdate::new(
  text~ : String,
  cursor~ : TextRange? = None,
) -> CompositionUpdate {
  { text, cursor, }
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
  paths~ : Array[String] = [],
  position~ : Point? = None,
) -> DragDropEvent {
  { phase, paths, position, }
}
