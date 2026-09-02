///|
fn markdown_editor_line_start(chars : Array[Char], caret : Int) -> Int {
  let mut start = markdown_editor_clamp_int(caret, 0, chars.length())
  while start > 0 && chars[start - 1] != '\n' {
    start = start - 1
  }
  start
}

///|
fn markdown_editor_line_indent(
  chars : Array[Char],
  line_start : Int,
  caret : Int,
) -> String {
  let indent : Array[Char] = []
  let mut index = markdown_editor_clamp_int(line_start, 0, chars.length())
  let end = markdown_editor_clamp_int(caret, index, chars.length())
  while index < end && (chars[index] == ' ' || chars[index] == '\t') {
    indent.push(chars[index])
    index = index + 1
  }
  String::from_array(indent)
}

///|
fn markdown_editor_backspace_marker(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  match markdown_editor_backspace_inline_marker(source, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  let chars = source.to_array()
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range_from_chars(chars, current)
  let line = String::from_array(chars[range.start:range.end])
  match
    markdown_editor_backspace_quoted_inner_marker(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  let marker_length = markdown_editor_marker_prefix_length(line)
  if marker_length == 0 || caret != range.start + marker_length {
    return None
  }
  let indent_length = markdown_editor_line_indent_prefix_length(line)
  if indent_length > 0 {
    let outdented = markdown_editor_outdent_line(line)
    let delta = markdown_editor_text_length(line) -
      markdown_editor_text_length(outdented)
    let text = String::from_array(chars[:range.start]) +
      outdented +
      String::from_array(chars[range.end:])
    return Some(
      markdown_editor_transform_result(
        text~,
        caret=markdown_editor_clamp_int(caret - delta, range.start, caret),
      ),
    )
  }
  let text = String::from_array(chars[:range.start]) +
    String::from_array(chars[range.start + marker_length:])
  Some(markdown_editor_transform_result(text~, caret=range.start))
}

///|
fn markdown_editor_backspace_quoted_inner_marker(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
  let context_length = markdown_editor_block_command_context_prefix_length(line)
  let context_prefix = markdown_editor_substring(line, 0, context_length)
  if !markdown_editor_block_command_context_has_quote(context_prefix) {
    return None
  }
  let marker_length = markdown_editor_marker_prefix_length_after_context(
    line, context_length,
  )
  if marker_length <= context_length || caret != range.start + marker_length {
    return None
  }
  let line_chars = line.to_array()
  let text = String::from_array(chars[:range.start]) +
    String::from_array(line_chars[:context_length]) +
    String::from_array(line_chars[marker_length:]) +
    String::from_array(chars[range.end:])
  Some(
    markdown_editor_transform_result(text~, caret=range.start + context_length),
  )
}

///|
fn markdown_editor_delete_marker(
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
  let range = markdown_editor_current_line_range_from_chars(chars, current)
  let line = String::from_array(chars[range.start:range.end])
  let marker_length = markdown_editor_marker_prefix_length(line)
  let indent_length = markdown_editor_line_indent_prefix_length(line)
  if marker_length == 0 || caret != range.start + indent_length {
    return None
  }
  if indent_length > 0 {
    let outdented = markdown_editor_outdent_line(line)
    let delta = markdown_editor_text_length(line) -
      markdown_editor_text_length(outdented)
    let text = String::from_array(chars[:range.start]) +
      outdented +
      String::from_array(chars[range.end:])
    return Some(
      markdown_editor_transform_result(
        text~,
        caret=markdown_editor_clamp_int(caret - delta, range.start, caret),
      ),
    )
  }
  let text = String::from_array(chars[:range.start]) +
    String::from_array(chars[range.start + marker_length:])
  Some(markdown_editor_transform_result(text~, caret=range.start))
}

///|
fn markdown_editor_delete_quoted_inner_marker(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range_from_chars(chars, current)
  let line = String::from_array(chars[range.start:range.end])
  let context_length = markdown_editor_block_command_context_prefix_length(line)
  let context_prefix = markdown_editor_substring(line, 0, context_length)
  if !markdown_editor_block_command_context_has_quote(context_prefix) {
    return None
  }
  let marker_length = markdown_editor_marker_prefix_length_after_context(
    line, context_length,
  )
  if marker_length <= context_length || caret != range.start + context_length {
    return None
  }
  let line_chars = line.to_array()
  let text = String::from_array(chars[:range.start]) +
    String::from_array(line_chars[:context_length]) +
    String::from_array(line_chars[marker_length:]) +
    String::from_array(chars[range.end:])
  Some(
    markdown_editor_transform_result(text~, caret=range.start + context_length),
  )
}

///|
fn markdown_editor_backspace_merge_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if caret == 0 || chars[caret - 1] != '\n' {
    return None
  }
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range_from_chars(chars, current)
  if caret != range.start {
    return None
  }
  let previous_end = caret - 1
  let previous_start = markdown_editor_previous_line_start(chars, previous_end)
  let previous_line = String::from_array(chars[previous_start:previous_end])
  let current_line = String::from_array(chars[range.start:range.end])
  if markdown_editor_blank_source_line(current_line) {
    let text = String::from_array(chars[:previous_end]) +
      String::from_array(chars[range.end:])
    return Some(markdown_editor_transform_result(text~, caret=previous_end))
  }
  let previous_content = markdown_editor_strip_merge_block_marker(previous_line)
  let current_content = markdown_editor_strip_merge_block_marker(current_line)
  let preserve_prefix = markdown_editor_preserved_merge_prefix(
    previous_line, current_line,
  )
  let separator = if previous_content == "" || current_content == "" {
    ""
  } else {
    " "
  }
  let merged = preserve_prefix + previous_content + separator + current_content
  let text = String::from_array(chars[:previous_start]) +
    merged +
    String::from_array(chars[range.end:])
  let caret = previous_start +
    markdown_editor_text_length(preserve_prefix) +
    markdown_editor_text_length(previous_content)
  Some(markdown_editor_transform_result(text~, caret~))
}

///|
fn markdown_editor_delete_merge_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_delete_inline_marker(source, chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  if caret >= chars.length() || chars[caret] != '\n' {
    return None
  }
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range_from_chars(chars, current)
  if caret != range.end {
    return None
  }
  let next_start = caret + 1
  let next_end = markdown_editor_next_line_end(chars, next_start)
  let current_line = String::from_array(chars[range.start:range.end])
  let next_line = String::from_array(chars[next_start:next_end])
  if markdown_editor_blank_source_line(next_line) {
    let text = String::from_array(chars[:range.end]) +
      String::from_array(chars[next_end:])
    return Some(markdown_editor_transform_result(text~, caret=range.end))
  }
  let current_content = markdown_editor_strip_merge_block_marker(current_line)
  let next_content = markdown_editor_strip_merge_block_marker(next_line)
  let preserve_prefix = markdown_editor_preserved_merge_prefix(
    current_line, next_line,
  )
  let separator = if current_content == "" || next_content == "" {
    ""
  } else {
    " "
  }
  let merged = preserve_prefix + current_content + separator + next_content
  let text = String::from_array(chars[:range.start]) +
    merged +
    String::from_array(chars[next_end:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=range.start +
        markdown_editor_text_length(preserve_prefix) +
        markdown_editor_text_length(current_content),
    ),
  )
}

///|
fn markdown_editor_blank_source_line(line : String) -> Bool {
  line.trim().to_owned() == ""
}

///|
fn markdown_editor_preserved_merge_prefix(
  first_line : String,
  second_line : String,
) -> String {
  if markdown_editor_merge_block_kind(first_line) !=
    markdown_editor_merge_block_kind(second_line) {
    return ""
  }
  match markdown_editor_merge_block_kind(first_line) {
    MarkdownEditorMergeBlockKind::Plain => ""
    MarkdownEditorMergeBlockKind::Bullet
    | MarkdownEditorMergeBlockKind::Task
    | MarkdownEditorMergeBlockKind::Ordered
    | MarkdownEditorMergeBlockKind::Quote =>
      markdown_editor_merge_block_marker_prefix(first_line)
  }
}

///|
priv enum MarkdownEditorMergeBlockKind {
  Plain
  Bullet
  Task
  Ordered
  Quote
} derive(Eq)

///|
fn markdown_editor_merge_block_kind(
  line : String,
) -> MarkdownEditorMergeBlockKind {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 6 &&
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
    Task
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    Bullet
  } else if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    Quote
  } else if markdown_editor_ordered_marker_length(chars) > 0 {
    Ordered
  } else {
    Plain
  }
}

///|
fn markdown_editor_strip_merge_block_marker(line : String) -> String {
  let offset = markdown_editor_merge_block_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[offset:])
}

///|
fn markdown_editor_merge_block_marker_prefix(line : String) -> String {
  let marker_length = markdown_editor_merge_block_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[:marker_length])
}

///|
fn markdown_editor_merge_block_marker_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    let nested = String::from_array(chars[indent + 2:])
    indent + 2 + markdown_editor_merge_block_marker_prefix_length(nested)
  } else {
    markdown_editor_marker_prefix_length(line)
  }
}

///|
fn markdown_editor_next_line_end(chars : Array[Char], start : Int) -> Int {
  let mut end = markdown_editor_clamp_int(start, 0, chars.length())
  while end < chars.length() && chars[end] != '\n' {
    end = end + 1
  }
  end
}

///|
fn markdown_editor_previous_line_start(
  chars : Array[Char],
  previous_end : Int,
) -> Int {
  let mut start = markdown_editor_clamp_int(previous_end, 0, chars.length())
  while start > 0 && chars[start - 1] != '\n' {
    start = start - 1
  }
  start
}

///|
