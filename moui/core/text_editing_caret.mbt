///|
pub(all) enum TextCaretDirection {
  MoveLeft
  MoveRight
  MoveStart
  MoveEnd
}

///|
pub(all) struct TextCaretMoveResult {
  caret : Int32
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
fn text_selection_anchor(caret : Int32, selection : TextRange?) -> Int32 {
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
  caret : Int32,
  selection : TextRange?,
  direction : TextCaretDirection,
  extend_selection~ : Bool,
) -> TextCaretMoveResult {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  if extend_selection {
    let anchor = nearest_boundary_fast(
      text,
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
        let selection = normalize_grapheme_range_fast(text, selection)
        match direction {
          MoveLeft => { caret: selection.start, selection: None, }
          MoveRight => { caret: selection.end, selection: None, }
          MoveStart => { caret: 0, selection: None, }
          MoveEnd => { caret: length, selection: None, }
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
/// Returns cp(caret-2) … cp(caret+1) when every window codepoint is
/// ASCII, or None to signal the general fallback. A caret move only
/// depends on the cluster rules at these five codepoints: break
/// decisions reference the flanking pair and, for RI/Extend/Indic
/// context, runs that would place a non-ASCII codepoint inside the
/// window themselves.
fn ascii_window_around_caret(
  text : String,
  caret~ : Int32,
) -> (Char?, Char?, Char?, Char?)? {
  let mut index = 0
  let mut minus_two : Char? = None
  let mut minus_one : Char? = None
  let mut at : Char? = None
  let mut plus_one : Char? = None
  for ch in text {
    if index >= caret - 2 && index <= caret + 1 && ch.to_int() >= 128 {
      return None
    }
    if index == caret - 2 {
      minus_two = Some(ch)
    } else if index == caret - 1 {
      minus_one = Some(ch)
    } else if index == caret {
      at = Some(ch)
    } else if index == caret + 1 {
      plus_one = Some(ch)
      return Some((minus_two, minus_one, at, plus_one))
    }
    index = index + 1
  }
  Some((minus_two, minus_one, at, plus_one))
}

///|
fn local_ascii_caret_move(
  text : String,
  caret : Int32,
  direction : TextCaretDirection,
  length~ : Int32,
) -> Int32? {
  match ascii_window_around_caret(text, caret~) {
    None => None
    Some((minus_two, minus_one, at, plus_one)) =>
      match direction {
        MoveLeft =>
          if caret <= 0 {
            Some(0)
          } else {
            // CR-LF is one cluster: stepping left out of the pair returns
            // to the CR, not onto the glued LF.
            match (minus_two, minus_one) {
              (Some('\r'), Some('\n')) => Some(caret - 2)
              _ => Some(caret - 1)
            }
          }
        MoveRight =>
          if caret >= length {
            Some(length)
          } else {
            match (at, plus_one) {
              (Some('\r'), Some('\n')) => Some(caret + 2)
              _ => Some(caret + 1)
            }
          }
        MoveStart => Some(0)
        MoveEnd => Some(length)
      }
  }
}

///|
fn move_text_caret_index(
  text : String,
  caret : Int32,
  direction : TextCaretDirection,
) -> Int32 {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  match local_ascii_caret_move(text, caret, direction, length~) {
    Some(next) => next
    None => {
      let boundaries = TextGraphemeBoundaries::new(text~)
      let caret = boundaries.clamp_index(caret)
      match direction {
        MoveLeft => boundaries.previous_boundary(caret)
        MoveRight => boundaries.next_boundary(caret)
        MoveStart => 0
        MoveEnd => boundaries.length()
      }
    }
  }
}

///|
fn text_length(text : String) -> Int32 {
  text.char_length()
}

///|
pub fn surrounding_delete_range(
  text : String,
  caret : Int32,
  before : Int32,
  after : Int32,
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
