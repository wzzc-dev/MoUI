///|
pub(all) struct TextInputState {
  focused : Bool
  text : String
  caret : Int
  selection : TextRange?
  composition : String?
  composition_cursor : TextRange?
  frame : Rect
  caret_rect : Rect
} derive(Eq, Debug, ToJson)

///|
pub fn TextInputState::none() -> TextInputState {
  {
    focused: false,
    text: "",
    caret: 0,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    caret_rect: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
  }
}
