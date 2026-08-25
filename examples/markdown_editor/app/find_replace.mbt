///|
fn markdown_editor_find_matches(
  source : String,
  query : String,
  options? : MarkdownEditorFindOptions = MarkdownEditorFindOptions::default(),
) -> Array[@text.TextRange] {
  let matches : Array[@text.TextRange] = []
  if query == "" {
    return matches
  }
  if options.regex {
    return markdown_editor_regex_find_matches(source, query, options)
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
      markdown_editor_query_match_at_utf16(
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
          markdown_editor_whole_word_boundary(previous_char, next_char) {
          matches.push(
            @text.TextRange::new(start=index, end=index + query_length),
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
fn markdown_editor_regex_find_matches(
  source : String,
  query : String,
  options : MarkdownEditorFindOptions,
) -> Array[@text.TextRange] {
  let matches : Array[@text.TextRange] = []
  match markdown_editor_compile_regex(query, options.case_sensitive) {
    Some(regex) => {
      let source_length = markdown_editor_text_length(source)
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
          markdown_editor_regex_whole_word_boundary(
            source, source_length, start, end,
          ) {
          matches.push(@text.TextRange::new(start~, end~))
        }
      }
    }
    None => ()
  }
  matches
}

///|
fn markdown_editor_compile_regex(
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
fn markdown_editor_regex_whole_word_boundary(
  source : String,
  source_length : Int,
  start : Int,
  end : Int,
) -> Bool {
  let before = if start <= 0 {
    None
  } else {
    source.get_char(
      markdown_editor_utf16_offset_for_char_index(
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
      markdown_editor_utf16_offset_for_char_index(source, source_length, end),
    )
  }
  markdown_editor_whole_word_boundary(before, after)
}

///|
fn markdown_editor_query_match_at_utf16(
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
fn markdown_editor_whole_word_boundary(before : Char?, after : Char?) -> Bool {
  let before_ok = match before {
    Some(ch) => !markdown_editor_ascii_word_char(ch)
    None => true
  }
  let after_ok = match after {
    Some(ch) => !markdown_editor_ascii_word_char(ch)
    None => true
  }
  before_ok && after_ok
}

///|
priv struct MarkdownEditorFindSeed {
  query : String
  range : @text.TextRange
}

///|
fn markdown_editor_find_query_from_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  guard selection.selection is Some(range) else { return None }
  let normalized = range.normalized()
  if normalized.start == normalized.end {
    return None
  }
  let selected = markdown_editor_substring(
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
fn markdown_editor_find_seed_from_caret_word(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorFindSeed? {
  match selection.selection {
    Some(range) => {
      let normalized = range.normalized()
      if normalized.start != normalized.end {
        return None
      }
    }
    None => ()
  }
  let source_length = markdown_editor_text_length(source)
  if source_length == 0 {
    return None
  }
  let caret = markdown_editor_clamp_int(selection.caret, 0, source_length)
  let (anchor, anchor_offset) = if caret < source_length {
    let offset = markdown_editor_utf16_offset_for_char_index(
      source, source_length, caret,
    )
    match source.get_char(offset) {
      Some(ch) if markdown_editor_ascii_word_char(ch) => (caret, offset)
      _ =>
        if caret > 0 {
          let previous_offset = markdown_editor_utf16_offset_for_char_index(
            source,
            source_length,
            caret - 1,
          )
          match source.get_char(previous_offset) {
            Some(ch) if markdown_editor_ascii_word_char(ch) =>
              (caret - 1, previous_offset)
            _ => return None
          }
        } else {
          return None
        }
    }
  } else if caret > 0 {
    let previous_offset = markdown_editor_utf16_offset_for_char_index(
      source,
      source_length,
      caret - 1,
    )
    match source.get_char(previous_offset) {
      Some(ch) if markdown_editor_ascii_word_char(ch) =>
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
      Some(ch) if markdown_editor_ascii_word_char(ch) => {
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
      Some(ch) if markdown_editor_ascii_word_char(ch) => {
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
      query: source.sub(start=start_offset, end=end_offset).to_owned(),
      range: @text.TextRange::new(start~, end~),
    })
  }
}

///|
fn markdown_editor_utf16_offset_for_char_index(
  source : String,
  char_length : Int,
  index : Int,
) -> Int {
  let index = markdown_editor_clamp_int(index, 0, char_length)
  if index == char_length {
    source.length()
  } else {
    source.offset_of_nth_char(index).unwrap_or(source.length())
  }
}

///|
fn markdown_editor_find_next_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
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
fn markdown_editor_find_previous_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
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
fn markdown_editor_find_active_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
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
fn markdown_editor_find_live_update_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
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
  markdown_editor_find_next_index(matches, selection)
}

///|
fn markdown_editor_replace_source_range(
  source : String,
  range : @text.TextRange,
  replacement : String,
) -> String {
  let normalized = range.normalized()
  markdown_editor_substring(source, 0, normalized.start) +
  replacement +
  markdown_editor_substring(
    source,
    normalized.end,
    markdown_editor_text_length(source),
  )
}

///|
fn MarkdownEditorApp::refresh_find_matches(
  self : MarkdownEditorApp,
) -> Array[@text.TextRange] {
  let query = self.find_query
  let matches : Array[@text.TextRange] = if query == "" {
    []
  } else {
    markdown_editor_find_matches(
      self.document,
      query,
      options=self.find_options,
    )
  }
  self.find_matches = matches
  matches
}

///|
fn MarkdownEditorApp::refresh_find_matches_if_visible(
  self : MarkdownEditorApp,
) -> Unit {
  if self.find_visible {
    ignore(self.refresh_find_matches())
  }
}

///|
fn markdown_editor_replacement_selection(
  start : Int,
  end : Int,
) -> @text.TextRange? {
  if start == end {
    None
  } else {
    Some(@text.TextRange::new(start~, end~))
  }
}

///|
fn markdown_editor_next_match_after_replacement(
  matches : Array[@text.TextRange],
  replaced_start : Int,
  replacement_end : Int,
) -> @text.TextRange? {
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
fn markdown_editor_replace_all_matches(
  source : String,
  matches : Array[@text.TextRange],
  replacement : String,
) -> String {
  let builder = StringBuilder()
  let source_length = markdown_editor_text_length(source)
  let utf16_length = source.length()
  let mut char_index = 0
  let mut utf16_offset = 0
  for range in matches {
    let normalized = range.normalized()
    let start = markdown_editor_clamp_int(
      normalized.start,
      char_index,
      source_length,
    )
    let start_offset = markdown_editor_advance_source_offset(
      source, utf16_length, char_index, utf16_offset, start,
    )
    builder.write_string(
      source.sub(start=utf16_offset, end=start_offset).to_owned(),
    )
    builder.write_string(replacement)
    let end = markdown_editor_clamp_int(normalized.end, start, source_length)
    let end_offset = markdown_editor_advance_source_offset(
      source, utf16_length, start, start_offset, end,
    )
    char_index = end
    utf16_offset = end_offset
  }
  builder.write_string(
    source.sub(start=utf16_offset, end=utf16_length).to_owned(),
  )
  builder.to_string()
}

///|
fn markdown_editor_advance_source_offset(
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
fn markdown_editor_find_status_label(
  query : String,
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
  options? : MarkdownEditorFindOptions = MarkdownEditorFindOptions::default(),
) -> String {
  if query == "" {
    "Ready"
  } else if options.regex &&
    markdown_editor_compile_regex(query, options.case_sensitive) is None {
    "Invalid regex"
  } else if matches.length() == 0 {
    "No match"
  } else {
    let active = markdown_editor_find_active_index(matches, selection)
    let visible_index = if active >= 0 { active + 1 } else { 0 }
    visible_index.to_string() + "/" + matches.length().to_string()
  }
}
