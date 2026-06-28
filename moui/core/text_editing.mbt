///|
pub(all) struct TextCommandResult {
  handled : Bool
  changed : Bool
  clipboard_text : String?
} derive(Eq, Debug, ToJson)

///|
pub fn TextCommandResult::ignored() -> TextCommandResult {
  { handled: false, changed: false, clipboard_text: None }
}

///|
pub fn TextCommandResult::handled(
  changed? : Bool = false,
  clipboard_text? : String? = None,
) -> TextCommandResult {
  { handled: true, changed, clipboard_text }
}

///|
pub(all) enum TextCaretDirection {
  MoveLeft
  MoveRight
  MoveStart
  MoveEnd
}

///|
pub(all) struct TextCaretMoveResult {
  caret : Int
  selection : TextRange?
}

///|
pub fn active_text_selection(selection : TextRange?) -> TextRange? {
  match selection {
    Some(selection) => {
      let normalized = selection.normalized()
      if normalized.is_collapsed() {
        None
      } else {
        Some(normalized)
      }
    }
    None => None
  }
}

///|
fn text_selection_anchor(caret : Int, selection : TextRange?) -> Int {
  match selection {
    Some(selection) =>
      if caret == selection.start {
        selection.end
      } else {
        selection.start
      }
    None => caret
  }
}

///|
pub fn move_text_caret(
  text : String,
  caret : Int,
  selection : TextRange?,
  direction : TextCaretDirection,
  extend~ : Bool,
) -> TextCaretMoveResult {
  let boundaries = TextGraphemeBoundaries::new(text~)
  let length = boundaries.length()
  let caret = boundaries.clamp_index(caret)
  if extend {
    let anchor = boundaries.nearest_boundary(
      text_selection_anchor(caret, selection),
    )
    let next = move_text_caret_index(text, caret, direction)
    {
      caret: next,
      selection: if next == anchor {
        None
      } else {
        Some(TextRange::new(start=anchor, end=next))
      },
    }
  } else {
    match active_text_selection(selection) {
      Some(selection) => {
        let selection = normalize_grapheme_range(boundaries, selection)
        match direction {
          MoveLeft => { caret: selection.start, selection: None }
          MoveRight => { caret: selection.end, selection: None }
          MoveStart => { caret: 0, selection: None }
          MoveEnd => { caret: length, selection: None }
        }
      }
      None =>
        {
          caret: move_text_caret_index(text, caret, direction),
          selection: None,
        }
    }
  }
}

///|
fn move_text_caret_index(
  text : String,
  caret : Int,
  direction : TextCaretDirection,
) -> Int {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  match direction {
    MoveLeft => TextGraphemeBoundaries::new(text~).previous_boundary(caret)
    MoveRight => TextGraphemeBoundaries::new(text~).next_boundary(caret)
    MoveStart => 0
    MoveEnd => length
  }
}

///|
fn text_length(text : String) -> Int {
  text.to_array().length()
}

///|
pub fn selected_text(text : String, selection : TextRange?) -> String {
  match active_text_selection(selection) {
    Some(selection) => {
      let chars = text.to_array()
      let range = normalize_grapheme_range(
        TextGraphemeBoundaries::new(text~),
        selection,
      )
      let start = clamp_int(range.start, 0, chars.length())
      let end = clamp_int(range.end, start, chars.length())
      String::from_array(chars[start:end])
    }
    None => ""
  }
}

///|
pub fn replace_text_range(
  text : String,
  range : TextRange,
  replacement : String,
) -> String {
  let chars = text.to_array()
  let normalized = range.normalized()
  let range = normalize_grapheme_range(
    TextGraphemeBoundaries::new(text~),
    normalized,
  )
  let start = clamp_int(range.start, 0, chars.length())
  let end = clamp_int(range.end, start, chars.length())
  let replacement_chars = replacement.to_array()
  String::from_array(chars[:start] + replacement_chars + chars[end:])
}

///|
pub fn surrounding_delete_range(
  text : String,
  caret : Int,
  before : Int,
  after : Int,
) -> TextRange {
  let length = text_length(text)
  let before = max_int(0, before)
  let after = max_int(0, after)
  let range = delete_grapheme_range(
    TextGraphemeBoundaries::new(text~),
    caret,
    before,
    after,
  )
  TextRange::new(
    start=clamp_int(range.start, 0, length),
    end=clamp_int(range.end, 0, length),
  )
}

///|
pub fn text_input_grapheme_selection(
  boundaries : TextGraphemeBoundaries,
  selection : TextRange?,
) -> TextRange? {
  match selection {
    Some(selection) => {
      let start = boundaries.nearest_boundary(selection.start)
      let end = boundaries.nearest_boundary(selection.end)
      if start == end {
        None
      } else {
        Some(TextRange::new(start~, end~))
      }
    }
    None => None
  }
}

///|
pub fn composition_start_index(
  text : String,
  caret : Int,
  selection : TextRange?,
) -> Int {
  match active_text_selection(selection) {
    Some(selection) =>
      normalize_grapheme_range(TextGraphemeBoundaries::new(text~), selection).start
    None => TextGraphemeBoundaries::new(text~).nearest_boundary(caret)
  }
}

///|
pub fn composition_cursor_offset(
  control : TextControlStateContext,
  composition : String,
) -> Int {
  let length = text_length(composition)
  match control.composition_cursor {
    Some(cursor) => {
      let normalized = cursor.normalized()
      TextGraphemeBoundaries::new(text=composition).nearest_boundary(
        clamp_int(normalized.end, 0, length),
      )
    }
    None => length
  }
}

///|
pub fn is_select_all_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "a" || event.key == "A") &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
pub fn is_undo_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "z" || event.key == "Z") &&
  !event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
pub fn is_redo_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (
    (event.modifiers.shift && (event.key == "z" || event.key == "Z")) ||
    (!event.modifiers.shift && (event.key == "y" || event.key == "Y"))
  ) &&
  (event.modifiers.meta || event.modifiers.control)
}
