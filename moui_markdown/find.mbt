///|
/// Markdown find/replace domain, extracted from MoMark's app layer so any
/// MoUI Markdown surface (MoUI Studio `.md` panels, embedders) shares the
/// same matching semantics.
///
/// All ranges are character indices (not UTF-16 offsets), matching
/// `MarkdownEditorSelection`.

///|
/// Find/replace options. Defaults are case-insensitive substring matching.
pub struct MarkdownFindOptions {
  case_sensitive : Bool
  whole_word : Bool
  regex : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend MarkdownFindOptions with Eq::{equal, not_equal}

///|
pub extend MarkdownFindOptions with Debug::{to_repr}

///|
pub extend MarkdownFindOptions with ToJson::{to_json}

///|
pub fn MarkdownFindOptions::default() -> MarkdownFindOptions {
  { case_sensitive: false, whole_word: false, regex: false, }
}

///|
/// A find query seeded from the caret word: `query` is the text, `range`
/// the selection to activate once the find bar opens.
pub(all) struct MarkdownFindSeed {
  query : String
  range : @core.TextRange
} derive(Eq, Debug, ToJson)

///|
pub extend MarkdownFindSeed with Debug::{to_repr}

///|
pub extend MarkdownFindSeed with Eq::{equal, not_equal}

///|
pub extend MarkdownFindSeed with ToJson::{to_json}

///|
/// All matches of `query` in `source`, in document order.
pub fn markdown_find_matches(
  source : String,
  query : String,
  options? : MarkdownFindOptions = MarkdownFindOptions::default(),
) -> Array[@core.TextRange] {
  let matches : Array[@core.TextRange] = []
  if query == "" {
    return matches
  }
  if options.regex {
    return markdown_find_regex_matches(source, query, options)
  }
  let query_chars = if options.case_sensitive {
    query.to_array()
  } else {
    query.to_lower().to_array()
  }
  let query_length = query_chars.length()
  if query_length == 0 {
    return matches
  }
  let source_utf16_length = source.length()
  let mut offset = 0
  let mut index = 0
  let mut previous_char : Char? = None
  while offset < source_utf16_length {
    match
      markdown_find_query_match_at_utf16(
        source,
        source_utf16_length,
        offset,
        query_chars,
        case_sensitive=options.case_sensitive,
      ) {
      Some((end_offset, last_char)) => {
        let next_char = if end_offset < source_utf16_length {
          source.get_char(end_offset)
        } else {
          None
        }
        if !options.whole_word ||
          markdown_find_whole_word_boundary(previous_char, next_char) {
          matches.push(
            @core.TextRange::new(start=index, end=index + query_length),
          )
          offset = end_offset
          index = index + query_length
          previous_char = Some(last_char)
          continue
        }
      }
      None => ()
    }
    match source.get_char(offset) {
      Some(ch) => {
        offset = offset + ch.utf16_len()
        index = index + 1
        previous_char = Some(ch)
      }
      None => break
    }
  }
  matches
}

///|
fn markdown_find_regex_matches(
  source : String,
  query : String,
  options : MarkdownFindOptions,
) -> Array[@core.TextRange] {
  let matches : Array[@core.TextRange] = []
  match markdown_find_compile_regex(query, options.case_sensitive) {
    Some(regex) => {
      let source_length = @richtext.markdown_editor_text_length(source)
      for found in regex.find(source) {
        let start = found.before().char_length()
        let end = start + found.content().char_length()
        // Zero-width matches do not have a useful selection/replacement range
        // in the current editor flow, so leave them out until that interaction
        // has an explicit cursor policy.
        if start == end {
          continue
        }
        if !options.whole_word ||
          markdown_find_regex_whole_word_boundary(
            source, source_length, start, end,
          ) {
          matches.push(@core.TextRange::new(start~, end~))
        }
      }
    }
    None => ()
  }
  matches
}

///|
/// Compile `query` into a regex, wrapping case-insensitively when needed.
/// Returns `None` for invalid patterns.
pub fn markdown_find_compile_regex(
  query : String,
  case_sensitive : Bool,
) -> Regex? {
  let pattern = if case_sensitive { query } else { "(?i:" + query + ")" }
  try Regex(pattern) catch {
    _ => None
  } noraise {
    regex => Some(regex)
  }
}

///|
fn markdown_find_regex_whole_word_boundary(
  source : String,
  source_length : Int,
  start : Int,
  end : Int,
) -> Bool {
  let before = if start <= 0 {
    None
  } else {
    source.get_char(
      markdown_find_utf16_offset_for_char_index(
        source,
        source_length,
        start - 1,
      ),
    )
  }
  let after = if end >= source_length {
    None
  } else {
    source.get_char(
      markdown_find_utf16_offset_for_char_index(source, source_length, end),
    )
  }
  markdown_find_whole_word_boundary(before, after)
}

///|
fn markdown_find_query_match_at_utf16(
  source : String,
  source_utf16_length : Int,
  offset : Int,
  query : Array[Char],
  case_sensitive~ : Bool,
) -> (Int, Char)? {
  let mut cursor = offset
  let mut last_char = query[0]
  for expected in query {
    if cursor >= source_utf16_length {
      return None
    }
    match source.get_char(cursor) {
      Some(ch) => {
        let actual = if case_sensitive { ch } else { ch.to_ascii_lowercase() }
        if actual != expected {
          return None
        }
        last_char = ch
        cursor = cursor + ch.utf16_len()
      }
      None => return None
    }
  }
  Some((cursor, last_char))
}

///|
fn markdown_find_whole_word_boundary(before : Char?, after : Char?) -> Bool {
  let before_ok = match before {
    Some(ch) => !@richtext.markdown_editor_ascii_word_char(ch)
    None => true
  }
  let after_ok = match after {
    Some(ch) => !@richtext.markdown_editor_ascii_word_char(ch)
    None => true
  }
  before_ok && after_ok
}

///|
fn markdown_find_utf16_offset_for_char_index(
  source : String,
  char_length : Int,
  index : Int,
) -> Int {
  let index = @richtext.markdown_editor_clamp_int(index, 0, char_length)
  if index == char_length {
    source.length()
  } else {
    source.offset_of_nth_char(index).unwrap_or(source.length())
  }
}

///|
/// The query to seed when the find bar opens over a non-empty single-line
/// selection.
pub fn markdown_find_query_from_selection(
  source : String,
  selection : @richtext.MarkdownEditorSelection,
) -> String? {
  guard selection.selection is Some(range) else { return None }
  let normalized = range.normalized()
  if normalized.start == normalized.end {
    return None
  }
  let selected = @richtext.markdown_editor_substring(
    source,
    normalized.start,
    normalized.end,
  )
  if selected == "" || selected.contains("\n") {
    None
  } else {
    Some(selected)
  }
}

///|
/// The find seed around a collapsed caret: the ASCII word under or directly
/// before the caret. Returns `None` when the caret is not on a word.
pub fn markdown_find_seed_from_caret_word(
  source : String,
  selection : @richtext.MarkdownEditorSelection,
) -> MarkdownFindSeed? {
  match selection.selection {
    Some(range) => {
      let normalized = range.normalized()
      if normalized.start != normalized.end {
        return None
      }
    }
    None => ()
  }
  let source_length = @richtext.markdown_editor_text_length(source)
  if source_length == 0 {
    return None
  }
  let caret = @richtext.markdown_editor_clamp_int(
    selection.caret,
    0,
    source_length,
  )
  let (anchor, anchor_offset) = if caret < source_length {
    let offset = markdown_find_utf16_offset_for_char_index(
      source, source_length, caret,
    )
    match source.get_char(offset) {
      Some(ch) if @richtext.markdown_editor_ascii_word_char(ch) =>
        (caret, offset)
      _ =>
        if caret > 0 {
          let previous_offset = markdown_find_utf16_offset_for_char_index(
            source,
            source_length,
            caret - 1,
          )
          match source.get_char(previous_offset) {
            Some(ch) if @richtext.markdown_editor_ascii_word_char(ch) =>
              (caret - 1, previous_offset)
            _ => return None
          }
        } else {
          return None
        }
    }
  } else if caret > 0 {
    let previous_offset = markdown_find_utf16_offset_for_char_index(
      source,
      source_length,
      caret - 1,
    )
    match source.get_char(previous_offset) {
      Some(ch) if @richtext.markdown_editor_ascii_word_char(ch) =>
        (caret - 1, previous_offset)
      _ => return None
    }
  } else {
    return None
  }
  let mut start = anchor
  let mut start_offset = anchor_offset
  while start > 0 && start_offset > 0 {
    let previous_offset = start_offset - 1
    match source.get_char(previous_offset) {
      Some(ch) if @richtext.markdown_editor_ascii_word_char(ch) => {
        start = start - 1
        start_offset = previous_offset
      }
      _ => break
    }
  }
  let mut end = anchor + 1
  let mut end_offset = anchor_offset + 1
  let source_utf16_length = source.length()
  while end < source_length && end_offset < source_utf16_length {
    match source.get_char(end_offset) {
      Some(ch) if @richtext.markdown_editor_ascii_word_char(ch) => {
        end = end + 1
        end_offset = end_offset + 1
      }
      _ => break
    }
  }
  if start == end {
    None
  } else {
    Some({
      query: source.exact_view(start=start_offset, end=end_offset).to_owned(),
      range: @core.TextRange::new(start~, end~),
    })
  }
}

///|
/// Index of the next match at or after the selection end, wrapping to the
/// first match.
pub fn markdown_find_next_index(
  matches : Array[@core.TextRange],
  selection : @richtext.MarkdownEditorSelection,
) -> Int {
  if matches.length() == 0 {
    return -1
  }
  let anchor = match selection.selection {
    Some(range) => range.normalized().end
    None => selection.caret
  }
  for index in 0..<matches.length() {
    if matches[index].start >= anchor {
      return index
    }
  }
  0
}

///|
/// Index of the previous match ending at or before the selection start,
/// wrapping to the last match.
pub fn markdown_find_previous_index(
  matches : Array[@core.TextRange],
  selection : @richtext.MarkdownEditorSelection,
) -> Int {
  if matches.length() == 0 {
    return -1
  }
  let anchor = match selection.selection {
    Some(range) => range.normalized().start
    None => selection.caret
  }
  let mut index = matches.length() - 1
  while index >= 0 {
    if matches[index].end <= anchor {
      return index
    }
    index = index - 1
  }
  matches.length() - 1
}

///|
/// Index of the match exactly equal to the current selection, or -1.
pub fn markdown_find_active_index(
  matches : Array[@core.TextRange],
  selection : @richtext.MarkdownEditorSelection,
) -> Int {
  guard selection.selection is Some(range) else { return -1 }
  let active = range.normalized()
  for index in 0..<matches.length() {
    if matches[index].start == active.start && matches[index].end == active.end {
      return index
    }
  }
  -1
}

///|
/// Index to keep active across a live find refresh: the match starting at
/// the current selection start (stable while the end changes), else the
/// next match.
pub fn markdown_find_live_update_index(
  matches : Array[@core.TextRange],
  selection : @richtext.MarkdownEditorSelection,
) -> Int {
  if matches.length() == 0 {
    return -1
  }
  match selection.selection {
    Some(range) => {
      let active = range.normalized()
      for index in 0..<matches.length() {
        if matches[index].start == active.start {
          return index
        }
      }
    }
    None => ()
  }
  markdown_find_next_index(matches, selection)
}

///|
/// Replace one character-index range with `replacement`.
pub fn markdown_replace_source_range(
  source : String,
  range : @core.TextRange,
  replacement : String,
) -> String {
  let normalized = range.normalized()
  @richtext.markdown_editor_substring(source, 0, normalized.start) +
  replacement +
  @richtext.markdown_editor_substring(
    source,
    normalized.end,
    @richtext.markdown_editor_text_length(source),
  )
}

///|
/// The match to activate after replacing `[replaced_start, replacement_end)`:
/// the first match at/after the replacement, else the first one before it.
pub fn markdown_next_match_after_replacement(
  matches : Array[@core.TextRange],
  replaced_start : Int,
  replacement_end : Int,
) -> @core.TextRange? {
  for range in matches {
    let normalized = range.normalized()
    if normalized.start >= replacement_end {
      return Some(normalized)
    }
  }
  for range in matches {
    let normalized = range.normalized()
    if normalized.end <= replaced_start {
      return Some(normalized)
    }
  }
  None
}

///|
/// Replace all matches in a single pass. Matches must be sorted and
/// non-overlapping; out-of-order/ranges past the end are clamped and skipped.
pub fn markdown_replace_all_matches(
  source : String,
  matches : Array[@core.TextRange],
  replacement : String,
) -> String {
  let builder = StringBuilder()
  let source_length = @richtext.markdown_editor_text_length(source)
  let utf16_length = source.length()
  let mut char_index = 0
  let mut utf16_offset = 0
  for range in matches {
    let normalized = range.normalized()
    let start = @richtext.markdown_editor_clamp_int(
      normalized.start,
      char_index,
      source_length,
    )
    let start_offset = markdown_find_advance_source_offset(
      source, utf16_length, char_index, utf16_offset, start,
    )
    builder.write_string(
      source.exact_view(start=utf16_offset, end=start_offset).to_owned(),
    )
    builder.write_string(replacement)
    let end = @richtext.markdown_editor_clamp_int(
      normalized.end,
      start,
      source_length,
    )
    let end_offset = markdown_find_advance_source_offset(
      source, utf16_length, start, start_offset, end,
    )
    char_index = end
    utf16_offset = end_offset
  }
  builder.write_string(
    source.exact_view(start=utf16_offset, end=utf16_length).to_owned(),
  )
  builder.to_string()
}

///|
fn markdown_find_advance_source_offset(
  source : String,
  utf16_length : Int,
  from_index : Int,
  from_offset : Int,
  target_index : Int,
) -> Int {
  let mut index = from_index
  let mut offset = from_offset
  while index < target_index && offset < utf16_length {
    match source.get_char(offset) {
      Some(ch) => {
        offset = offset + ch.utf16_len()
        index = index + 1
      }
      None => return utf16_length
    }
  }
  offset
}

///|
/// The find-bar status label: "Ready", "Invalid regex", "No match", or the
/// active match position ("n/m").
pub fn markdown_find_status_label(
  query : String,
  matches : Array[@core.TextRange],
  selection : @richtext.MarkdownEditorSelection,
  options? : MarkdownFindOptions = MarkdownFindOptions::default(),
) -> String {
  if query == "" {
    "Ready"
  } else if options.regex &&
    markdown_find_compile_regex(query, options.case_sensitive) is None {
    "Invalid regex"
  } else if matches.length() == 0 {
    "No match"
  } else {
    let active = markdown_find_active_index(matches, selection)
    let visible_index = if active >= 0 { active + 1 } else { 0 }
    visible_index.to_string() + "/" + matches.length().to_string()
  }
}
