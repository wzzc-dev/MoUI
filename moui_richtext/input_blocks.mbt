///|
fn markdown_editor_complete_rule_on_space(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  let line = String::from_array(chars[range.start:range.end])
  markdown_editor_complete_rule_on_enter(chars, range, line, caret)
}

///|
fn markdown_editor_complete_setext_heading_on_space(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  let line = String::from_array(chars[range.start:range.end])
  markdown_editor_complete_setext_heading_on_enter(chars, range, line, caret)
}

///|
priv struct MarkdownEditorPastedFootnoteDefinition {
  label : String
  text : String
}

///|
priv struct MarkdownEditorFootnoteDefinitionEdit {
  source : String
  anchor_delta : Int
}

///|
pub fn markdown_editor_insert_hard_break(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if markdown_editor_table_cell_at_text_offset(source, caret, selection) {
    return None
  }
  if markdown_editor_active_selection(selection) is None &&
    markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return markdown_editor_transform_input(source, caret, selection, "\n")
  }
  let replace_range = match markdown_editor_active_selection(selection) {
    Some(range) => range.normalized()
    None => @core.TextRange::new(start=caret, end=caret)
  }
  let current : MarkdownEditorSelection = {
    caret: replace_range.start,
    selection: None,
  }
  let line_range = markdown_editor_current_line_range(source, current)
  let line = String::from_array(chars[line_range.start:line_range.end])
  let insert = "  \n" + markdown_editor_hard_break_continuation_prefix(line)
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:replace_range.start]) +
        insert +
        String::from_array(chars[replace_range.end:]),
      caret=replace_range.start + markdown_editor_text_length(insert),
    ),
  )
}

///|
fn markdown_editor_complete_rule_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
  if caret != range.end || !markdown_editor_is_typed_rule_line(line) {
    return None
  }
  let text = String::from_array(chars[:caret]) +
    "\n" +
    String::from_array(chars[caret:])
  Some(markdown_editor_transform_result(text~, caret=caret + 1))
}

///|
fn markdown_editor_complete_setext_heading_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
  if caret != range.end || !markdown_editor_is_typed_setext_underline_line(line) {
    return None
  }
  if range.start == 0 || chars[range.start - 1] != '\n' {
    return None
  }
  let previous_end = range.start - 1
  let previous_start = markdown_editor_previous_line_start(chars, previous_end)
  let previous_line = String::from_array(chars[previous_start:previous_end])
  if previous_line.trim().to_owned() == "" ||
    !markdown_editor_is_setext_paragraph_candidate(previous_line) {
    return None
  }
  let text = String::from_array(chars[:caret]) +
    "\n" +
    String::from_array(chars[caret:])
  Some(markdown_editor_transform_result(text~, caret=caret + 1))
}

///|
fn markdown_editor_is_typed_setext_underline_line(line : String) -> Bool {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() < indent + 3 {
    return false
  }
  let marker = chars[indent]
  if marker != '=' && marker != '-' {
    return false
  }
  for index in indent..<chars.length() {
    if chars[index] != marker {
      return false
    }
  }
  true
}

///|
fn markdown_editor_is_typed_rule_line(line : String) -> Bool {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() != indent + 3 {
    return false
  }
  (chars[indent] == '-' && chars[indent + 1] == '-' && chars[indent + 2] == '-') ||
  (chars[indent] == '*' && chars[indent + 1] == '*' && chars[indent + 2] == '*') ||
  (chars[indent] == '_' && chars[indent + 1] == '_' && chars[indent + 2] == '_')
}

///|
fn markdown_editor_transform_result(
  text~ : String,
  caret~ : Int,
  selection? : @core.TextRange? = None,
) -> RichTextInputTransform {
  markdown_editor_normalize_ordered_transform(
    RichTextInputTransform::new(text~, caret~, selection~),
  )
}

///|
fn markdown_editor_autocomplete_block_marker(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  let before = String::from_array(chars[range.start:caret])
  let marker = markdown_editor_typed_block_marker(before)
  if marker == "" {
    return None
  }
  let text = String::from_array(chars[:range.start]) +
    marker +
    String::from_array(chars[caret:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=range.start + markdown_editor_text_length(marker),
    ),
  )
}

///|
fn markdown_editor_typed_block_marker(before : String) -> String {
  let chars = before.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let prefix = String::from_array(chars[:indent])
  let token = String::from_array(chars[indent:])
  if markdown_editor_typed_heading_marker(token) is Some(level) {
    prefix + markdown_editor_heading_marker(level) + " "
  } else if token == "-" || token == "*" || token == "+" {
    prefix + "- "
  } else if markdown_editor_typed_task_marker(token, checked=false) {
    prefix + "- [ ] "
  } else if markdown_editor_typed_task_marker(token, checked=true) {
    prefix + "- [x] "
  } else if markdown_editor_typed_quote_marker(token) is Some(depth) {
    prefix + markdown_editor_quote_marker(depth)
  } else if markdown_editor_typed_ordered_marker(token) is Some(number) {
    prefix + number.to_string() + ". "
  } else if markdown_editor_typed_quoted_block_marker(token) is Some(marker) {
    prefix + marker
  } else {
    ""
  }
}

///|
fn markdown_editor_typed_quoted_block_marker(token : String) -> String? {
  let quote = "> "
  if !markdown_editor_source_has_marker(token.to_array(), 0, quote) {
    return None
  }
  let nested = markdown_editor_substring(
    token,
    markdown_editor_text_length(quote),
    markdown_editor_text_length(token),
  )
  let marker = markdown_editor_typed_block_marker(nested)
  if marker == "" {
    None
  } else {
    Some(quote + marker)
  }
}

///|
fn markdown_editor_typed_quote_marker(token : String) -> Int? {
  let chars = token.to_array()
  if chars.length() < 1 {
    return None
  }
  for ch in chars {
    if ch != '>' {
      return None
    }
  }
  Some(chars.length())
}

///|
fn markdown_editor_quote_marker(depth : Int) -> String {
  let parts : Array[String] = []
  for _ in 0..<depth {
    parts.push(">")
  }
  parts.join(" ") + " "
}

///|
fn markdown_editor_typed_task_marker(token : String, checked~ : Bool) -> Bool {
  let checkbox = if checked { ["[x]", "[X]"] } else { ["[]", "[ ]"] }
  for item in checkbox {
    if token == item {
      return true
    }
    if token == "- " + item || token == "* " + item || token == "+ " + item {
      return true
    }
  }
  false
}

///|
fn markdown_editor_typed_heading_marker(token : String) -> Int? {
  let chars = token.to_array()
  if chars.length() < 1 || chars.length() > 6 {
    return None
  }
  for ch in chars {
    if ch != '#' {
      return None
    }
  }
  Some(chars.length())
}

///|
fn markdown_editor_typed_ordered_marker(token : String) -> Int? {
  let chars = token.to_array()
  if chars.length() < 2 ||
    (chars[chars.length() - 1] != '.' && chars[chars.length() - 1] != ')') {
    return None
  }
  for index in 0..<(chars.length() - 1) {
    if !chars[index].is_ascii_digit() {
      return None
    }
  }
  Some(markdown_editor_parse_digits(chars, 0, chars.length() - 1))
}

///|
pub fn markdown_editor_indent_lines(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform {
  markdown_editor_shift_lines(source, caret, selection, indent=true).unwrap()
}

///|
pub fn markdown_editor_outdent_lines(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  markdown_editor_shift_lines(source, caret, selection, indent=false)
}

///|
fn markdown_editor_shift_lines(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  indent~ : Bool,
) -> RichTextInputTransform? {
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_selected_line_range(source, current)
  let chars = source.to_array()
  let segment = String::from_array(chars[range.start:range.end])
  let shifted = if indent {
    markdown_editor_indent_segment(segment)
  } else {
    markdown_editor_outdent_segment(segment)
  }
  if shifted == segment {
    return None
  }
  let delta = markdown_editor_text_length(shifted) - (range.end - range.start)
  let text = String::from_array(chars[:range.start]) +
    shifted +
    String::from_array(chars[range.end:])
  let next_selection = match markdown_editor_active_selection(selection) {
    Some(_) =>
      Some(
        @core.TextRange::new(
          start=range.start,
          end=range.start + markdown_editor_text_length(shifted),
        ),
      )
    None => None
  }
  let next_caret = if caret <= range.start {
    caret
  } else if caret <= range.end {
    caret + delta
  } else {
    caret + delta
  }
  Some(
    markdown_editor_transform_result(
      text~,
      caret=next_caret,
      selection=next_selection,
    ),
  )
}

///|
fn markdown_editor_indent_segment(segment : String) -> String {
  let lines = markdown_editor_lines(segment)
  let shifted : Array[String] = []
  for line in lines {
    shifted.push("  " + line.text)
  }
  markdown_join_lines(shifted)
}

///|
fn markdown_editor_outdent_segment(segment : String) -> String {
  let lines = markdown_editor_lines(segment)
  let shifted : Array[String] = []
  for line in lines {
    shifted.push(markdown_editor_outdent_line(line.text))
  }
  markdown_join_lines(shifted)
}

///|
fn markdown_editor_outdent_line(line : String) -> String {
  let chars = line.to_array()
  if chars.length() >= 2 && chars[0] == ' ' && chars[1] == ' ' {
    String::from_array(chars[2:])
  } else if chars.length() >= 1 && chars[0] == ' ' {
    String::from_array(chars[1:])
  } else if chars.length() >= 1 && chars[0] == '\t' {
    String::from_array(chars[1:])
  } else {
    line
  }
}

///|
fn markdown_editor_exit_empty_continuation(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
) -> RichTextInputTransform? {
  let marker = markdown_editor_continuation_marker(line)
  if marker == "" {
    return None
  }
  if markdown_editor_text_length(line) != markdown_editor_text_length(marker) {
    return None
  }
  match markdown_editor_quoted_continuation_parent(line) {
    Some(parent) =>
      return Some(
        markdown_editor_transform_result(
          text=String::from_array(chars[:range.start]) +
            parent +
            String::from_array(chars[range.end:]),
          caret=range.start + markdown_editor_text_length(parent),
        ),
      )
    None => ()
  }
  if markdown_editor_line_indent_prefix_length(line) > 0 {
    let outdented = markdown_editor_outdent_line(line)
    return Some(
      markdown_editor_transform_result(
        text=String::from_array(chars[:range.start]) +
          outdented +
          String::from_array(chars[range.end:]),
        caret=range.start + markdown_editor_marker_prefix_length(outdented),
      ),
    )
  }
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:range.start]) +
        String::from_array(chars[range.end:]),
      caret=range.start,
    ),
  )
}

///|
fn markdown_editor_backspace_empty_continuation(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let range = markdown_editor_current_line_range(
    source,
    ({ caret, selection } : MarkdownEditorSelection),
  )
  if caret != range.end {
    return None
  }
  let line = String::from_array(chars[range.start:range.end])
  markdown_editor_exit_empty_continuation(chars, range, line)
}

///|
fn markdown_editor_delete_empty_continuation(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let range = markdown_editor_current_line_range(
    source,
    ({ caret, selection } : MarkdownEditorSelection),
  )
  if caret != range.start {
    return None
  }
  let line = String::from_array(chars[range.start:range.end])
  markdown_editor_exit_empty_continuation(chars, range, line)
}

///|
fn markdown_editor_exit_empty_heading(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
  if caret != range.end {
    return None
  }
  match markdown_editor_empty_heading_prefix(line) {
    Some(prefix) =>
      Some(
        markdown_editor_transform_result(
          text=String::from_array(chars[:range.start]) +
            prefix +
            String::from_array(chars[range.end:]),
          caret=range.start + markdown_editor_text_length(prefix),
        ),
      )
    None => None
  }
}

///|
fn markdown_editor_empty_heading_prefix(line : String) -> String? {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    let nested = String::from_array(chars[indent + 2:])
    match markdown_editor_empty_heading_prefix(nested) {
      Some(prefix) =>
        return Some(String::from_array(chars[:indent + 2]) + prefix)
      None => ()
    }
  }
  let mut index = indent
  while index < chars.length() && chars[index] == '#' {
    index = index + 1
  }
  let level = index - indent
  if level < 1 || level > 6 || index >= chars.length() {
    return None
  }
  if chars[index] != ' ' && chars[index] != '\t' {
    return None
  }
  while index < chars.length() {
    if chars[index] != ' ' && chars[index] != '\t' {
      return None
    }
    index = index + 1
  }
  Some(String::from_array(chars[:indent]))
}

///|
fn markdown_editor_quoted_continuation_parent(line : String) -> String? {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() < indent + 3 ||
    chars[indent] != '>' ||
    chars[indent + 1] != ' ' {
    return None
  }
  let nested = String::from_array(chars[indent + 2:])
  let nested_marker = markdown_editor_continuation_marker(nested)
  if nested_marker == "" ||
    markdown_editor_text_length(nested_marker) !=
    markdown_editor_text_length(nested) {
    None
  } else {
    let quote_prefix = String::from_array(chars[:indent + 2])
    match markdown_editor_quoted_continuation_parent(nested) {
      Some(parent) => Some(quote_prefix + parent)
      None => Some(quote_prefix)
    }
  }
}

///|
fn markdown_editor_continuation_marker(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let indent_text = String::from_array(chars[:indent])
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    let nested = String::from_array(chars[indent + 2:])
    let nested_marker = markdown_editor_continuation_marker(nested)
    if nested_marker == "" {
      indent_text + "> "
    } else {
      indent_text + "> " + nested_marker
    }
  } else if chars.length() >= indent + 6 &&
    chars[indent] == '-' &&
    chars[indent + 1] == ' ' &&
    chars[indent + 2] == '[' &&
    (
      chars[indent + 3] == ' ' ||
      chars[indent + 3] == 'x' ||
      chars[indent + 3] == 'X'
    ) &&
    chars[indent + 4] == ']' &&
    chars[indent + 5] == ' ' {
    indent_text + "- [ ] "
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    indent_text + String::from_array(chars[indent:indent + 2])
  } else {
    markdown_editor_ordered_continuation_marker(chars, indent)
  }
}

///|
fn markdown_editor_ordered_continuation_marker(
  chars : Array[Char],
  indent : Int,
) -> String {
  let mut index = indent
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  if index > 0 &&
    index + 1 < chars.length() &&
    chars[index] == '.' &&
    chars[index + 1] == ' ' {
    String::from_array(chars[:indent]) +
    (markdown_editor_parse_digits(chars, indent, index) + 1).to_string() +
    ". "
  } else {
    ""
  }
}

///|
