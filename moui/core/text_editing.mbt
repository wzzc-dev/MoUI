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
/// A codepoint position whose flanking codepoints are ASCII (or absent)
/// and do not form a CR-LF glue pair is always a grapheme cluster
/// boundary: ASCII codepoints neither extend a preceding cluster nor begin
/// one that a preceding cluster extends.
fn grapheme_trivial_boundary(before : Char?, at : Char?) -> Bool {
  let ascii_before = match before {
    None => true
    Some(ch) => ch.to_int() < 128
  }
  let ascii_at = match at {
    None => true
    Some(ch) => ch.to_int() < 128
  }
  let cr_lf_glue = match (before, at) {
    (Some('\r'), Some('\n')) => true
    _ => false
  }
  ascii_before && ascii_at && !cr_lf_glue
}

///|
/// Result of one allocation-free forward scan for two codepoint
/// positions: total codepoint length, the UTF-16 offsets of the clamped
/// positions, and the codepoints flanking them (enough to prove both sit
/// on trivial grapheme boundaries without materializing the boundary
/// table).
priv struct TextRangeScan {
  start : Int32
  end : Int32
  start_offset : Int32
  end_offset : Int32
  before_start : Char?
  at_start : Char?
  before_end : Char?
  at_end : Char?
}

///|
fn scan_text_for_range(
  text : String,
  start~ : Int32,
  end~ : Int32,
) -> TextRangeScan {
  let want_start = max_int(0, start)
  let want_end = max_int(0, end)
  let mut index = 0
  let mut offset = 0
  let mut found_start = false
  let mut found_end = false
  let mut start_offset = 0
  let mut end_offset = 0
  let mut before_start : Char? = None
  let mut at_start : Char? = None
  let mut before_end : Char? = None
  let mut at_end : Char? = None
  let mut previous : Char? = None
  for ch in text {
    if !found_start && index == want_start {
      found_start = true
      start_offset = offset
      before_start = previous
      at_start = Some(ch)
    }
    if !found_end && index == want_end {
      found_end = true
      end_offset = offset
      before_end = previous
      at_end = Some(ch)
    }
    previous = Some(ch)
    offset = offset + ch.utf16_len()
    index = index + 1
    // Both endpoints resolved: the scan can stop. Callers that need the
    // total length only use it in the not-found fallback paths (they pass
    // `text.char_length()` there), so truncating `index` here is safe and
    // keeps an early-document caret from scanning the whole document.
    if found_start && found_end {
      break
    }
  }
  if !found_start {
    start_offset = offset
    before_start = previous
    at_start = None
  }
  if !found_end {
    end_offset = offset
    before_end = previous
    at_end = None
  }
  {
    start: clamp_int(want_start, 0, index),
    end: clamp_int(want_end, 0, index),
    start_offset,
    end_offset,
    before_start,
    at_start,
    before_end,
    at_end,
  }
}

///|
/// Normalizes a range to grapheme boundaries, skipping the full boundary
/// table when both endpoints already sit on trivial boundaries.
fn normalize_grapheme_range_fast(text : String, range : TextRange) -> TextRange {
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
    TextRange::new(start=scan.start, end=scan.end)
  } else {
    normalize_grapheme_range(TextGraphemeBoundaries::new(text~), normalized)
  }
}

///|
/// The grapheme boundary nearest `index`, skipping the full boundary
/// table when the clamped position sits on a trivial boundary.
fn nearest_boundary_fast(text : String, index : Int32) -> Int32 {
  let scan = scan_text_for_range(text, start=index, end=index)
  if grapheme_trivial_boundary(scan.before_start, scan.at_start) {
    scan.start
  } else {
    TextGraphemeBoundaries::new(text~).nearest_boundary(scan.start)
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
/// What a double-click treats as one selectable unit around a codepoint.
/// `JoinWord` and `JoinBlank` extend over neighbours of the same class;
/// `Alone` is a one-grapheme word, which is how UAX#29 segments Han, kana and
/// Hangul.
priv enum TextWordCharClass {
  JoinWord
  JoinBlank
  Alone
}

///|
/// Codepoints that stand alone: Han, kana, Hangul and the punctuation, symbol,
/// control and pictograph blocks they are written with. This is a bounded block
/// list, not a generated UAX#29 table — see `docs/text-system.md` for exactly
/// what is left out.
fn text_word_alone_char(ch : Char) -> Bool {
  ch
  is ('\u4E00'..<='\u9FFF'
  | '\u3400'..<='\u4DBF'
  | '\uF900'..<='\uFAFF'
  | '\u3041'..<='\u309F'
  | '\u30A0'..<='\u30FF'
  | '\uAC00'..<='\uD7A3'
  | '\u1100'..<='\u11FF'
  | '\u2010'..<='\u2027'
  | '\u202A'..<='\u205E'
  | '\u2060'..<='\u206F'
  | '\u2E00'..<='\u2E7F'
  | '\u3001'..<='\u303F'
  | '\uFE10'..<='\uFE19'
  | '\uFE30'..<='\uFE6F'
  | '\uFF01'..<='\uFF20'
  | '\uFF3B'..<='\uFF40'
  | '\uFF5B'..<='\uFF65'
  | '\u00A1'
  | '\u00A7'
  | '\u00AB'
  | '\u00AD'
  | '\u00B6'
  | '\u00B7'
  | '\u00BB'
  | '\u00BF'
  | '\u200B'..<='\u200F'
  | '\u{1F000}'..<='\u{1FAFF}')
}

///|
fn text_word_char_class(ch : Char) -> TextWordCharClass {
  if ch.is_whitespace() {
    JoinBlank
  } else if ch.is_ascii() {
    if ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_' {
      JoinWord
    } else {
      Alone
    }
  } else if text_word_alone_char(ch) || ch.is_control() {
    Alone
  } else {
    JoinWord
  }
}

///|
/// Only two same-class joiners extend a word: a singleton (Han, kana, Hangul,
/// punctuation, control) always stands alone, even next to its own class.
fn text_word_classes_join(
  before : TextWordCharClass,
  after : TextWordCharClass,
) -> Bool {
  match (before, after) {
    (JoinWord, JoinWord) | (JoinBlank, JoinBlank) => true
    _ => false
  }
}

///|
/// `[start, end)` of the run containing char index `target`, in one pass with
/// no allocation. A run closes whenever the class changes or either side is a
/// singleton, so `你好` yields two runs and `ab--cd` three.
fn text_word_run_bounds(text : String, target : Int32) -> (Int32, Int32) {
  let mut i : Int32 = 0
  let mut previous : TextWordCharClass? = None
  let mut start : Int32 = 0
  let mut end : Int32 = -1
  let mut inside = false
  for ch in text {
    let class = text_word_char_class(ch)
    let opens_run = match previous {
      None => true
      Some(previous) => !text_word_classes_join(previous, class)
    }
    if opens_run {
      if inside {
        end = i
        break
      } else {
        start = i
      }
    }
    if i == target {
      inside = true
    }
    previous = Some(class)
    i = i + 1
  }
  (start, if end < 0 { text_length(text) } else { end })
}

///|
/// The word a double-click selects at char index `index`: a maximal run of
/// same-class codepoints, or one grapheme when the class is `Alone`. `index` is
/// clamped, the result is grapheme-safe (a ZWJ sequence is never cut) and only
/// empty text returns an empty range.
pub fn text_word_range_at(text : String, index : Int32) -> TextRange {
  let length = text_length(text)
  if length == 0 {
    return TextRange::new(start=0, end=0)
  }
  let (start, end) = text_word_run_bounds(text, clamp_int(index, 0, length - 1))
  normalize_grapheme_range_fast(text, TextRange::new(start~, end~))
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
