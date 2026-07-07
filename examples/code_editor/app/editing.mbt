///|
pub(all) struct CodeCursor {
  position : Int
  selection : @text.TextRange?
}

///|
pub fn CodeCursor::new(
  position~ : Int,
  selection? : @text.TextRange? = None,
) -> CodeCursor {
  { position, selection }
}

///|
pub(all) struct CodeFindState {
  query : String
  replacement : String
  matches : Array[@text.TextRange]
  active_index : Int
}

///|
pub fn CodeFindState::new() -> CodeFindState {
  { query: "", replacement: "", matches: [], active_index: -1 }
}

///|
fn CodeFindState::recompute(
  self : CodeFindState,
  source : String,
) -> CodeFindState {
  {
    ..self,
    matches: code_find_matches(source, self.query),
    active_index: if self.query == "" {
      -1
    } else {
      self.active_index
    },
  }
}

///|
pub fn code_find_matches(
  source : String,
  query : String,
) -> Array[@text.TextRange] {
  let matches : Array[@text.TextRange] = []
  if query == "" {
    return matches
  }
  let source_chars = source.to_array()
  let query_chars = query.to_array()
  if query_chars.is_empty() || query_chars.length() > source_chars.length() {
    return matches
  }
  let mut i = 0
  while i <= source_chars.length() - query_chars.length() {
    let mut ok = true
    for j in 0..<query_chars.length() {
      if source_chars[i + j] != query_chars[j] {
        ok = false
      }
    }
    if ok {
      matches.push(@text.TextRange::new(start=i, end=i + query_chars.length()))
      i = i + query_chars.length()
    } else {
      i = i + 1
    }
  }
  matches
}

///|
pub fn code_replace_all(
  source : String,
  query : String,
  replacement : String,
) -> String {
  if query == "" {
    return source
  }
  let chars = source.to_array()
  let q = query.to_array()
  let out : Array[Char] = []
  let replacement_chars = replacement.to_array()
  let mut i = 0
  while i < chars.length() {
    if q.length() > 0 &&
      i + q.length() <= chars.length() &&
      chars_match(chars, i, q) {
      out.append(replacement_chars)
      i = i + q.length()
    } else {
      out.push(chars[i])
      i = i + 1
    }
  }
  String::from_array(out)
}

///|
fn chars_match(chars : Array[Char], start : Int, query : Array[Char]) -> Bool {
  for i in 0..<query.length() {
    if chars[start + i] != query[i] {
      return false
    }
  }
  true
}

///|
pub fn code_insert_text(
  source : String,
  cursors : Array[CodeCursor],
  inserted : String,
) -> (String, Array[CodeCursor]) {
  let chars = source.to_array()
  let sorted = sort_cursor_edits(cursors, chars.length())
  let out : Array[Char] = []
  let next_cursors : Array[CodeCursor] = []
  let mut source_index = 0
  for edit in sorted {
    let start = if edit.start < source_index {
      source_index
    } else {
      edit.start
    }
    let end = if edit.end < start { start } else { edit.end }
    while source_index < start {
      out.push(chars[source_index])
      source_index = source_index + 1
    }
    let insertion = if inserted == "\n" {
      "\n" + auto_indent_for_position(source, start)
    } else {
      inserted
    }
    let insert_chars = insertion.to_array()
    out.append(insert_chars)
    next_cursors.push(CodeCursor::new(position=out.length()))
    source_index = end
  }
  while source_index < chars.length() {
    out.push(chars[source_index])
    source_index = source_index + 1
  }
  (String::from_array(out), next_cursors)
}

///|
priv struct CursorEdit {
  start : Int
  end : Int
}

///|
fn sort_cursor_edits(
  cursors : Array[CodeCursor],
  source_length : Int,
) -> Array[CursorEdit] {
  let sorted = cursors.map(cursor => cursor_edit(cursor, source_length))
  for i in 0..<sorted.length() {
    for j in (i + 1)..<sorted.length() {
      if sorted[j].start < sorted[i].start ||
        (sorted[j].start == sorted[i].start && sorted[j].end < sorted[i].end) {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }
  sorted
}

///|
fn cursor_edit(cursor : CodeCursor, source_length : Int) -> CursorEdit {
  match cursor.selection {
    Some(range) => {
      let raw_start = if range.start < range.end {
        range.start
      } else {
        range.end
      }
      let raw_end = if range.start < range.end {
        range.end
      } else {
        range.start
      }
      {
        start: clamp_int(raw_start, 0, source_length),
        end: clamp_int(raw_end, 0, source_length),
      }
    }
    None => {
      let position = clamp_int(cursor.position, 0, source_length)
      { start: position, end: position }
    }
  }
}

///|
pub fn auto_indent_for_position(source : String, position : Int) -> String {
  let chars = source.to_array()
  let pos = clamp_int(position, 0, chars.length())
  let mut line_start = pos
  while line_start > 0 && chars[line_start - 1] != '\n' {
    line_start = line_start - 1
  }
  let indent : Array[Char] = []
  let mut i = line_start
  while i < pos && (chars[i] == ' ' || chars[i] == '\t') {
    indent.push(chars[i])
    i = i + 1
  }
  if pos > 0 && chars[pos - 1] == '{' {
    indent.push(' ')
    indent.push(' ')
  }
  String::from_array(indent)
}

///|
pub(all) struct BracketMatch {
  open : Int
  close : Int
}

///|
pub fn code_bracket_match(source : String, offset : Int) -> BracketMatch? {
  let chars = source.to_array()
  if chars.is_empty() {
    return None
  }
  if offset >= 0 && offset < chars.length() {
    match code_bracket_match_at(chars, offset) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  if offset > 0 {
    let previous = clamp_int(offset - 1, 0, chars.length() - 1)
    return code_bracket_match_at(chars, previous)
  }
  None
}

///|
fn code_bracket_match_at(chars : Array[Char], index : Int) -> BracketMatch? {
  let ch = chars[index]
  if ch == '(' || ch == '[' || ch == '{' {
    return find_forward_bracket(chars, index, ch, matching_close(ch))
  }
  if ch == ')' || ch == ']' || ch == '}' {
    return find_backward_bracket(chars, index, matching_open(ch), ch)
  }
  None
}

///|
fn find_forward_bracket(
  chars : Array[Char],
  start : Int,
  open : Char,
  close : Char,
) -> BracketMatch? {
  let mut depth = 0
  for i in start..<chars.length() {
    if chars[i] == open {
      depth = depth + 1
    } else if chars[i] == close {
      depth = depth - 1
      if depth == 0 {
        return Some({ open: start, close: i })
      }
    }
  }
  None
}

///|
fn find_backward_bracket(
  chars : Array[Char],
  end : Int,
  open : Char,
  close : Char,
) -> BracketMatch? {
  let mut depth = 0
  let mut i = end
  while i >= 0 {
    if chars[i] == close {
      depth = depth + 1
    } else if chars[i] == open {
      depth = depth - 1
      if depth == 0 {
        return Some({ open: i, close: end })
      }
    }
    i = i - 1
  }
  None
}

///|
fn matching_close(ch : Char) -> Char {
  match ch {
    '(' => ')'
    '[' => ']'
    '{' => '}'
    _ => ch
  }
}

///|
fn matching_open(ch : Char) -> Char {
  match ch {
    ')' => '('
    ']' => '['
    '}' => '{'
    _ => ch
  }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
