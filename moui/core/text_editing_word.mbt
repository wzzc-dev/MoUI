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
