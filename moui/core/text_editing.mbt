///|
pub(all) struct TextCommandResult {
  handled : Bool
  changed : Bool
  clipboard_text : String?
} derive(Eq, Debug, ToJson)

///|
priv enum TextCaretDirection {
  MoveLeft
  MoveRight
  MoveStart
  MoveEnd
}

///|
priv struct TextCaretMoveResult {
  caret : Int
  selection : TextRange?
}

///|
fn active_text_selection(selection : TextRange?) -> TextRange? {
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
fn move_text_caret(
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
