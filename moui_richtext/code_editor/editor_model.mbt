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
pub(all) enum CodeDiagnosticSeverity {
  Info
  Warning
  Error
}

///|
pub fn CodeDiagnosticSeverity::label(self : CodeDiagnosticSeverity) -> String {
  match self {
    Info => "Info"
    Warning => "Warning"
    Error => "Error"
  }
}

///|
pub(all) struct CodeDiagnostic {
  range : @text.TextRange
  severity : CodeDiagnosticSeverity
  message : String
}

///|
pub fn CodeDiagnostic::new(
  range~ : @text.TextRange,
  severity~ : CodeDiagnosticSeverity,
  message~ : String,
) -> CodeDiagnostic {
  { range, severity, message }
}

///|
pub(all) struct CodeCompletionItem {
  label : String
  insert_text : String
  detail : String
}

///|
pub(all) struct CodeEditorToken {
  text : String
  kind : String
}

///|
pub(all) struct CodeLanguageRegistry {
  language_id : String
}

///|
pub fn CodeLanguageRegistry::new(
  language_id? : String = "moonbit",
) -> CodeLanguageRegistry {
  { language_id, }
}

///|
pub fn CodeLanguageRegistry::tokenize(
  self : CodeLanguageRegistry,
  source : String,
) -> Array[CodeEditorToken] {
  @richtext.code_highlight_tokenize(source, self.language_id).map(span => {
    text: span.text,
    kind: code_highlight_kind(span.kind),
  })
}

///|
pub fn CodeLanguageRegistry::completions(
  _self : CodeLanguageRegistry,
  source : String,
  offset : Int,
) -> Array[CodeCompletionItem] {
  let prefix = code_word_prefix(source, offset)
  let candidates : Array[String] = [
    "fn", "let", "pub", "struct", "enum", "match", "@moui.View", "@views.column",
    "@views.row",
  ]
  candidates
  .filter(value => prefix == "" || value.has_prefix(prefix))
  .map(value => {
    CodeCompletionItem::new(label=value, insert_text=value, detail="MoonBit")
  })
}

///|
pub fn CodeCompletionItem::new(
  label~ : String,
  insert_text~ : String,
  detail? : String = "",
) -> CodeCompletionItem {
  { label, insert_text, detail }
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
pub(all) struct EditorDocument {
  path : String
  text : String
  language : String
  dirty : Bool
}

///|
pub fn EditorDocument::new(
  path~ : String,
  text~ : String,
  language? : String = "moonbit",
) -> EditorDocument {
  { path, text, language, dirty: false }
}

///|
pub(all) struct EditorState {
  documents : Array[EditorDocument]
  active_file : String
  cursors : Array[CodeCursor]
  selection : @text.TextRange?
  diagnostics : Array[CodeDiagnostic]
  completions : Array[CodeCompletionItem]
  find : CodeFindState
  status : String
}

///|
pub fn EditorState::new(source~ : String) -> EditorState {
  {
    documents: [EditorDocument::new(path="main.mbt", text=source)],
    active_file: "main.mbt",
    cursors: [CodeCursor::new(position=0)],
    selection: None,
    diagnostics: [],
    completions: [],
    find: CodeFindState::new(),
    status: "Ready",
  }
}

///|
pub fn EditorState::active_document(self : EditorState) -> EditorDocument {
  for document in self.documents {
    if document.path == self.active_file {
      return document
    }
  }
  EditorDocument::new(path=self.active_file, text="")
}

///|
pub fn EditorState::with_source(
  self : EditorState,
  source : String,
) -> EditorState {
  let documents = self.documents.map(document => {
    if document.path == self.active_file {
      { ..document, text: source, dirty: true }
    } else {
      document
    }
  })
  { ..self, documents, find: self.find.recompute(source), status: "Edited" }
}

///|
pub fn EditorState::with_selection(
  self : EditorState,
  caret : Int,
  selection : @text.TextRange?,
) -> EditorState {
  { ..self, cursors: [CodeCursor::new(position=caret, selection~)], selection }
}

///|
pub fn EditorState::with_diagnostics(
  self : EditorState,
  diagnostics : Array[CodeDiagnostic],
) -> EditorState {
  {
    ..self,
    diagnostics,
    status: if diagnostics.is_empty() {
      "No problems"
    } else {
      "Problems found"
    },
  }
}

///|
pub fn EditorState::with_completions(
  self : EditorState,
  completions : Array[CodeCompletionItem],
) -> EditorState {
  { ..self, completions, }
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
  let clamped = clamp_editor_int(offset, 0, chars.length())
  let lines = code_editor_source_lines(source)
  for index in 0..<lines.length() {
    let line = lines[index]
    let is_last = index == lines.length() - 1
    if clamped >= line.start &&
      (clamped < line.end || (is_last && clamped <= line.end)) {
      return {
        line: line.number,
        column: clamped - line.start + 1,
        offset: clamped,
      }
    }
  }
  { line: 1, column: 1, offset: clamped }
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
  let mut index = 0
  while index <= source_chars.length() - query_chars.length() {
    if editor_chars_match(source_chars, index, query_chars) {
      matches.push(
        @text.TextRange::new(start=index, end=index + query_chars.length()),
      )
      index = index + query_chars.length()
    } else {
      index = index + 1
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
  let query_chars = query.to_array()
  let output : Array[Char] = []
  let replacement_chars = replacement.to_array()
  let mut index = 0
  while index < chars.length() {
    if index + query_chars.length() <= chars.length() &&
      editor_chars_match(chars, index, query_chars) {
      output.append(replacement_chars)
      index = index + query_chars.length()
    } else {
      output.push(chars[index])
      index = index + 1
    }
  }
  String::from_array(output)
}

///|
pub fn code_insert_text(
  source : String,
  cursors : Array[CodeCursor],
  inserted : String,
) -> (String, Array[CodeCursor]) {
  let chars = source.to_array()
  let edits = cursors.map(cursor => editor_cursor_edit(cursor, chars.length()))
  editor_sort_edits(edits)
  let output : Array[Char] = []
  let next_cursors : Array[CodeCursor] = []
  let mut source_index = 0
  for edit in edits {
    let start = if edit.start < source_index {
      source_index
    } else {
      edit.start
    }
    let end = if edit.end < start { start } else { edit.end }
    while source_index < start {
      output.push(chars[source_index])
      source_index = source_index + 1
    }
    let insertion = if inserted == "\n" {
      "\n" + auto_indent_for_position(source, start)
    } else {
      inserted
    }
    output.append(insertion.to_array())
    next_cursors.push(CodeCursor::new(position=output.length()))
    source_index = end
  }
  while source_index < chars.length() {
    output.push(chars[source_index])
    source_index = source_index + 1
  }
  (String::from_array(output), next_cursors)
}

///|
pub fn auto_indent_for_position(source : String, position : Int) -> String {
  let chars = source.to_array()
  let pos = clamp_editor_int(position, 0, chars.length())
  let mut line_start = pos
  while line_start > 0 && chars[line_start - 1] != '\n' {
    line_start = line_start - 1
  }
  let indent : Array[Char] = []
  let mut index = line_start
  while index < pos && (chars[index] == ' ' || chars[index] == '\t') {
    indent.push(chars[index])
    index = index + 1
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
    match editor_bracket_at(chars, offset) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  if offset > 0 {
    let index = clamp_editor_int(offset - 1, 0, chars.length() - 1)
    return editor_bracket_at(chars, index)
  }
  None
}

///|
fn editor_chars_match(
  chars : Array[Char],
  start : Int,
  query : Array[Char],
) -> Bool {
  for index in 0..<query.length() {
    if chars[start + index] != query[index] {
      return false
    }
  }
  true
}

///|
priv struct EditorCursorEdit {
  start : Int
  end : Int
}

///|
fn editor_cursor_edit(
  cursor : CodeCursor,
  source_length : Int,
) -> EditorCursorEdit {
  match cursor.selection {
    Some(range) => {
      let start = if range.start < range.end { range.start } else { range.end }
      let end = if range.start < range.end { range.end } else { range.start }
      {
        start: clamp_editor_int(start, 0, source_length),
        end: clamp_editor_int(end, 0, source_length),
      }
    }
    None => {
      let position = clamp_editor_int(cursor.position, 0, source_length)
      { start: position, end: position }
    }
  }
}

///|
fn editor_sort_edits(edits : Array[EditorCursorEdit]) -> Unit {
  for index in 0..<edits.length() {
    for next in (index + 1)..<edits.length() {
      if edits[next].start < edits[index].start {
        let value = edits[index]
        edits[index] = edits[next]
        edits[next] = value
      }
    }
  }
}

///|
fn editor_bracket_at(chars : Array[Char], index : Int) -> BracketMatch? {
  let character = chars[index]
  if character == '(' || character == '[' || character == '{' {
    return editor_find_forward(
      chars,
      index,
      character,
      editor_matching_close(character),
    )
  }
  if character == ')' || character == ']' || character == '}' {
    return editor_find_backward(
      chars,
      index,
      editor_matching_open(character),
      character,
    )
  }
  None
}

///|
fn editor_find_forward(
  chars : Array[Char],
  start : Int,
  open : Char,
  close : Char,
) -> BracketMatch? {
  let mut depth = 0
  for index in start..<chars.length() {
    if chars[index] == open {
      depth = depth + 1
    } else if chars[index] == close {
      depth = depth - 1
      if depth == 0 {
        return Some({ open: start, close: index })
      }
    }
  }
  None
}

///|
fn editor_find_backward(
  chars : Array[Char],
  end : Int,
  open : Char,
  close : Char,
) -> BracketMatch? {
  let mut depth = 0
  let mut index = end
  while index >= 0 {
    if chars[index] == close {
      depth = depth + 1
    } else if chars[index] == open {
      depth = depth - 1
      if depth == 0 {
        return Some({ open: index, close: end })
      }
    }
    index = index - 1
  }
  None
}

///|
fn editor_matching_close(character : Char) -> Char {
  match character {
    '(' => ')'
    '[' => ']'
    '{' => '}'
    _ => character
  }
}

///|
fn editor_matching_open(character : Char) -> Char {
  match character {
    ')' => '('
    ']' => '['
    '}' => '{'
    _ => character
  }
}

///|
fn clamp_editor_int(value : Int, minimum : Int, maximum : Int) -> Int {
  if value < minimum {
    minimum
  } else if value > maximum {
    maximum
  } else {
    value
  }
}

///|
pub fn CodeFindState::recompute(
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
fn code_highlight_kind(kind : @richtext.CodeHighlightToken) -> String {
  match kind {
    CodePlain => "plain"
    CodeKeyword => "keyword"
    CodeString => "string"
    CodeComment => "comment"
    CodeNumber => "number"
    CodeFunction => "function"
    CodeType => "type"
    CodeOperator => "operator"
    CodeAnnotation => "annotation"
    CodeEscape => "escape"
  }
}

///|
fn code_word_prefix(source : String, offset : Int) -> String {
  let chars = source.to_array()
  let end = clamp_editor_int(offset, 0, chars.length())
  let mut start = end
  while start > 0 && editor_is_word_char(chars[start - 1]) {
    start = start - 1
  }
  String::from_array(chars[start:end])
}

///|
fn editor_is_word_char(character : Char) -> Bool {
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z') ||
  (character >= '0' && character <= '9') ||
  character == '_' ||
  character == '@' ||
  character == '.'
}
