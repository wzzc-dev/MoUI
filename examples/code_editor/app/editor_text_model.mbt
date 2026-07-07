///|
pub(all) struct CodeEditorSourceLine {
  number : Int
  start : Int
  end : Int
  text : String
}

///|
pub(all) struct CodeEditorCaretPosition {
  line : Int
  column : Int
  offset : Int
}

///|
pub fn code_editor_source_lines(source : String) -> Array[CodeEditorSourceLine] {
  let lines : Array[CodeEditorSourceLine] = []
  let chars = source.to_array()
  let current : Array[Char] = []
  let mut line_start = 0
  let mut number = 1
  for index in 0..<chars.length() {
    if chars[index] == '\n' {
      lines.push({
        number,
        start: line_start,
        end: index + 1,
        text: String::from_array(current),
      })
      current.clear()
      line_start = index + 1
      number = number + 1
    } else {
      current.push(chars[index])
    }
  }
  if line_start < chars.length() || lines.is_empty() {
    lines.push({
      number,
      start: line_start,
      end: chars.length(),
      text: String::from_array(current),
    })
  }
  lines
}

///|
pub fn code_editor_caret_position(
  source : String,
  offset : Int,
) -> CodeEditorCaretPosition {
  let chars = source.to_array()
  let clamped = clamp_int(offset, 0, chars.length())
  let lines = code_editor_source_lines(source)
  for index in 0..<lines.length() {
    let line = lines[index]
    let is_last = index == lines.length() - 1
    if clamped >= line.start &&
      (clamped < line.end || (is_last && clamped <= line.end)) {
      let column = clamped - line.start + 1
      return { line: line.number, column, offset: clamped }
    }
  }
  if lines.length() > 0 {
    let last = lines[lines.length() - 1]
    { line: last.number, column: last.text.length() + 1, offset: clamped }
  } else {
    { line: 1, column: 1, offset: clamped }
  }
}

///|
pub fn code_editor_diagnostic_lines(
  source : String,
  diagnostics : Array[CodeDiagnostic],
) -> Array[Int] {
  let lines : Array[Int] = []
  for diagnostic in diagnostics {
    let position = code_editor_caret_position(source, diagnostic.range.start)
    if !lines.contains(position.line) {
      lines.push(position.line)
    }
  }
  lines
}

///|
fn code_editor_text_offset(source : String, needle : String) -> Int {
  let source_chars = source.to_array()
  let needle_chars = needle.to_array()
  if needle_chars.is_empty() || needle_chars.length() > source_chars.length() {
    return 0
  }
  for start in 0..<=(source_chars.length() - needle_chars.length()) {
    let mut matched = true
    for index in 0..<needle_chars.length() {
      if source_chars[start + index] != needle_chars[index] {
        matched = false
      }
    }
    if matched {
      return start
    }
  }
  0
}

///|
fn code_editor_word_prefix_start(source : String, offset : Int) -> Int {
  let chars = source.to_array()
  let mut start = clamp_int(offset, 0, chars.length())
  while start > 0 && code_editor_is_word_char(chars[start - 1]) {
    start = start - 1
  }
  start
}

///|
fn code_editor_is_word_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_'
}
