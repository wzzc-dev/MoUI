///|
fn markdown_editor_find_matches(
  source : String,
  query : String,
  options? : MarkdownEditorFindOptions = MarkdownEditorFindOptions::default(),
) -> Array[@core.TextRange] {
  let source_chars = source.to_array()
  let matches : Array[@core.TextRange] = []
  if query == "" {
    return matches
  }
  // Regex mode is intentionally a thin shim: it matches the literal query as a
  // substring but honors case-sensitivity, since a full regex engine is out of
  // scope. The toggle still surfaces intent and is wired for a future engine.
  let query_chars = if options.case_sensitive {
    query.to_array()
  } else {
    query.to_lower().to_array()
  }
  if query_chars.length() == 0 || source_chars.length() < query_chars.length() {
    return matches
  }
  let last = source_chars.length() - query_chars.length()
  let mut index = 0
  while index <= last {
    if markdown_editor_chars_match_at(
        source_chars,
        query_chars,
        index,
        case_sensitive=options.case_sensitive,
      ) &&
      (
        !options.whole_word ||
        markdown_editor_is_whole_word(source_chars, index, query_chars.length())
      ) {
      matches.push(
        @core.TextRange::new(start=index, end=index + query_chars.length()),
      )
      index = index + query_chars.length()
    } else {
      index = index + 1
    }
  }
  matches
}

///|
/// True when the match at [start, start+length) is bounded by non-word
/// characters (or the string edges), so it stands as a whole word.
fn markdown_editor_is_whole_word(
  source : Array[Char],
  start : Int,
  length : Int,
) -> Bool {
  let before_ok = start == 0 ||
    !markdown_editor_ascii_word_char(source[start - 1])
  let after_ok = start + length == source.length() ||
    !markdown_editor_ascii_word_char(source[start + length])
  before_ok && after_ok
}

///|
priv struct MarkdownEditorFindSeed {
  query : String
  range : @core.TextRange
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
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(normalized.start, 0, chars.length())
  let end = markdown_editor_clamp_int(normalized.end, start, chars.length())
  let selected = String::from_array(chars[start:end])
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
  let chars = source.to_array()
  if chars.length() == 0 {
    return None
  }
  let caret = markdown_editor_clamp_int(selection.caret, 0, chars.length())
  let anchor = if caret < chars.length() &&
    markdown_editor_ascii_word_char(chars[caret]) {
    caret
  } else if caret > 0 && markdown_editor_ascii_word_char(chars[caret - 1]) {
    caret - 1
  } else {
    return None
  }
  let mut start = anchor
  while start > 0 && markdown_editor_ascii_word_char(chars[start - 1]) {
    start = start - 1
  }
  let mut end = anchor + 1
  while end < chars.length() && markdown_editor_ascii_word_char(chars[end]) {
    end = end + 1
  }
  if start == end {
    None
  } else {
    Some({
      query: String::from_array(chars[start:end]),
      range: @core.TextRange::new(start~, end~),
    })
  }
}

///|
fn markdown_editor_chars_match_at(
  source : Array[Char],
  query : Array[Char],
  start : Int,
  case_sensitive~ : Bool = false,
) -> Bool {
  if case_sensitive {
    for index in 0..<query.length() {
      if source[start + index] != query[index] {
        return false
      }
    }
  } else {
    for index in 0..<query.length() {
      if source[start + index].to_ascii_lowercase() != query[index] {
        return false
      }
    }
  }
  true
}

///|
fn markdown_editor_find_next_index(
  matches : Array[@core.TextRange],
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
  matches : Array[@core.TextRange],
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
  matches : Array[@core.TextRange],
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
  matches : Array[@core.TextRange],
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
  range : @core.TextRange,
  replacement : String,
) -> String {
  let chars = source.to_array()
  let normalized = range.normalized()
  String::from_array(chars[:normalized.start]) +
  replacement +
  String::from_array(chars[normalized.end:])
}

///|
fn markdown_editor_replacement_selection(
  start : Int,
  end : Int,
) -> @core.TextRange? {
  if start == end {
    None
  } else {
    Some(@core.TextRange::new(start~, end~))
  }
}

///|
fn markdown_editor_next_match_after_replacement(
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
fn markdown_editor_replace_all_matches(
  source : String,
  matches : Array[@core.TextRange],
  replacement : String,
) -> String {
  let source_chars = source.to_array()
  let replacement_chars = replacement.to_array()
  let result : Array[Char] = []
  let mut offset = 0
  for range in matches {
    let normalized = range.normalized()
    result.append(source_chars[offset:normalized.start])
    result.append(replacement_chars)
    offset = normalized.end
  }
  result.append(source_chars[offset:])
  String::from_array(result)
}

///|
fn markdown_editor_find_status_label(
  query : String,
  matches : Array[@core.TextRange],
  selection : MarkdownEditorSelection,
) -> String {
  if query == "" {
    "Ready"
  } else if matches.length() == 0 {
    "No match"
  } else {
    let active = markdown_editor_find_active_index(matches, selection)
    let visible_index = if active >= 0 { active + 1 } else { 0 }
    visible_index.to_string() + "/" + matches.length().to_string()
  }
}
