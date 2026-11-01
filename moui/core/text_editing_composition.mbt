///|
pub(all) struct TextCommandResult {
  handled : Bool
  changed : Bool
  clipboard_text : String?
} derive(Eq, Debug, ToJson)

///|
pub extend TextCommandResult with Debug::{to_repr}

///|
pub extend TextCommandResult with Eq::{not_equal, equal}

///|
pub extend TextCommandResult with ToJson::{to_json}

///|
pub fn TextCommandResult::ignored() -> TextCommandResult {
  { handled: false, changed: false, clipboard_text: None, }
}

///|
pub fn TextCommandResult::handled(
  changed~ : Bool = false,
  clipboard_text~ : String? = None,
) -> TextCommandResult {
  { handled: true, changed, clipboard_text, }
}

///|
pub fn selected_text(text : String, selection : TextRange?) -> String {
  match active_text_selection(selection) {
    Some(selection) => {
      let normalized = normalize_grapheme_range_fast(text, selection)
      let scan = scan_text_for_range(
        text,
        start=normalized.start,
        end=normalized.end,
      )
      let endpoints_trivial = grapheme_trivial_boundary(
          scan.before_start,
          scan.at_start,
        ) &&
        grapheme_trivial_boundary(scan.before_end, scan.at_end)
      if endpoints_trivial {
        text.exact_view(start=scan.start_offset, end=scan.end_offset).to_owned()
      } else {
        text_substring_by_char_range(
          text,
          normalized.start,
          normalized.end,
          length=text.char_length(),
        )
      }
    }
    None => ""
  }
}

///|
/// Replace a grapheme-normalized range in one document scan: returns the
/// next text, the deleted slice, and the normalized start — no char-array
/// or boundary-table copies.
pub fn replace_text_range_edit(
  text~ : String,
  range : TextRange,
  replacement : String,
) -> (String, String, Int32) {
  let normalized = range.normalized()
  let scan = scan_text_for_range(
    text,
    start=normalized.start,
    end=normalized.end,
  )
  let endpoints_trivial = grapheme_trivial_boundary(
      scan.before_start,
      scan.at_start,
    ) &&
    grapheme_trivial_boundary(scan.before_end, scan.at_end)
  if endpoints_trivial {
    let next_text = text.exact_view(start=0, end=scan.start_offset).to_owned() +
      replacement +
      text.exact_view(start=scan.end_offset, end=text.length()).to_owned()
    let deleted = text
      .exact_view(start=scan.start_offset, end=scan.end_offset)
      .to_owned()
    (next_text, deleted, scan.start)
  } else {
    let range = normalize_grapheme_range(
      TextGraphemeBoundaries::new(text~),
      normalized,
    )
    let length = text.char_length()
    let next_text = text_substring_by_char_range(text, 0, range.start, length~) +
      replacement +
      text_substring_by_char_range(text, range.end, length, length~)
    let deleted = text_substring_by_char_range(
      text,
      range.start,
      range.end,
      length~,
    )
    (next_text, deleted, range.start)
  }
}

///|
pub fn replace_text_range(
  text : String,
  range : TextRange,
  replacement : String,
) -> String {
  replace_text_range_edit(text~, range, replacement).0
}

///|
fn text_substring_by_char_range(
  text : String,
  start : Int32,
  end : Int32,
  length~ : Int32,
) -> String {
  let start = clamp_int(start, 0, length)
  let end = clamp_int(end, start, length)
  let utf16_length = text.length()
  let start_offset = if start == length {
    utf16_length
  } else {
    text.offset_of_nth_char(start).unwrap_or(utf16_length)
  }
  let end_offset = if end == length {
    utf16_length
  } else {
    text.offset_of_nth_char(end).unwrap_or(utf16_length)
  }
  text.exact_view(start=start_offset, end=end_offset).to_owned()
}

///|
test "text editing range helpers preserve unicode scalar offsets" {
  let source = "a🤣b"
  inspect(
    selected_text(source, Some(TextRange::new(start=1, end=2))),
    content="🤣",
  )
  inspect(
    replace_text_range(source, TextRange::new(start=1, end=2), "尾"),
    content="a尾b",
  )
  inspect(
    replace_text_range(source, TextRange::collapsed(3), "!"),
    content="a🤣b!",
  )
}

///|
pub fn composition_start_index(
  text : String,
  caret : Int32,
  selection : TextRange?,
) -> Int32 {
  match active_text_selection(selection) {
    Some(selection) => normalize_grapheme_range_fast(text, selection).start
    None => nearest_boundary_fast(text, caret)
  }
}

///|
pub fn composition_cursor_offset(
  control : TextControlStateContext,
  composition : String,
) -> Int32 {
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
pub fn is_copy_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "c" || event.key == "C") &&
  !event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
pub fn is_cut_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "x" || event.key == "X") &&
  !event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
pub fn is_paste_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "v" || event.key == "V") &&
  !event.modifiers.shift &&
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

///|
/// Baselines that always build the full boundary table, so the localized
/// fast paths can be cross-checked on every position of tricky documents.
fn full_boundary_replace(
  text : String,
  range : TextRange,
  replacement : String,
) -> String {
  let normalized = range.normalized()
  let range = normalize_grapheme_range(
    TextGraphemeBoundaries::new(text~),
    normalized,
  )
  let length = text_length(text)
  text_substring_by_char_range(text, 0, range.start, length~) +
  replacement +
  text_substring_by_char_range(text, range.end, length, length~)
}

///|
fn full_boundary_move(
  text : String,
  caret : Int32,
  direction : TextCaretDirection,
) -> Int32 {
  let boundaries = TextGraphemeBoundaries::new(text~)
  let length = boundaries.length()
  let caret = boundaries.clamp_index(caret)
  match direction {
    MoveLeft => boundaries.previous_boundary(caret)
    MoveRight => boundaries.next_boundary(caret)
    MoveStart => 0
    MoveEnd => length
  }
}

///|
fn full_boundary_selected(text : String, selection : TextRange) -> String {
  let length = text_length(text)
  let range = normalize_grapheme_range(
    TextGraphemeBoundaries::new(text~),
    selection,
  )
  text_substring_by_char_range(text, range.start, range.end, length~)
}

///|
test "localized editing paths match the full boundary implementation" {
  let samples = [
    "", "a", "hello world", "a🤣b", "e\u{301} x é\u{300}y", "🇨🇳🇺🇸 flags",
    "👨‍👩‍👧 family ok", "한글 syllable", "a\r\nb\r\nc", "plain\nlines\nhere\n",
    "中文 mixed with latin",
  ]
  let directions = [MoveLeft, MoveRight, MoveStart, MoveEnd]
  for text in samples {
    let length = text.char_length()
    for caret in 0..<=(length + 1) {
      for direction in directions {
        assert_eq(
          move_text_caret_index(text, caret, direction),
          full_boundary_move(text, caret, direction),
        )
      }
      for end in [caret, caret + 1, caret + 2, caret + 5, length] {
        let range = TextRange::new(start=caret, end~)
        assert_eq(
          replace_text_range(text, range, "X"),
          full_boundary_replace(text, range, "X"),
        )
        assert_eq(
          replace_text_range_edit(text~, range, "尾Y").1,
          text_substring_by_char_range(
            text,
            normalize_grapheme_range(
              TextGraphemeBoundaries::new(text~),
              range.normalized(),
            ).start,
            normalize_grapheme_range(
              TextGraphemeBoundaries::new(text~),
              range.normalized(),
            ).end,
            length~,
          ),
        )
        assert_eq(
          selected_text(text, Some(range)),
          full_boundary_selected(text, range.normalized()),
        )
      }
      assert_eq(
        composition_start_index(text, caret, None),
        TextGraphemeBoundaries::new(text~).nearest_boundary(
          clamp_int(caret, 0, length),
        ),
      )
    }
  }
}
