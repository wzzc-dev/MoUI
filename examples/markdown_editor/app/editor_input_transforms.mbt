///|
fn markdown_editor_transform_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  match
    markdown_editor_paste_reference_over_selection(source, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_paste_autolink(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_wrap_selection_input(source, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  if input == "\t" {
    match
      markdown_editor_move_table_cell(source, caret, selection, forward=true) {
      Some(transform) => return Some(transform)
      None => ()
    }
    return Some(markdown_editor_indent_lines(source, caret, selection))
  }
  if input == "\u{000b}" {
    match
      markdown_editor_move_table_cell(source, caret, selection, forward=false) {
      Some(transform) => return Some(transform)
      None => ()
    }
    return markdown_editor_outdent_lines(source, caret, selection)
  }
  if markdown_editor_is_multiline_input(input) {
    return markdown_editor_transform_multiline_paste(
      source, caret, selection, input,
    )
  }
  if input == "\n" && markdown_editor_active_selection(selection) is None {
    let chars = source.to_array()
    let caret = markdown_editor_clamp_int(caret, 0, chars.length())
    let current = { caret, selection }
    let range = markdown_editor_current_line_range(source, current)
    let line = String::from_array(chars[range.start:range.end])
    match
      markdown_editor_complete_code_fence_on_enter(chars, range, line, caret) {
      Some(transform) => return Some(transform)
      None => ()
    }
  }
  if markdown_editor_code_block_at_content_offset(source, caret, selection)
    is Some(_) {
    if input == "\n" {
      return Some(markdown_editor_code_block_enter(source, caret))
    }
    return None
  }
  if input == "\u{0008}" {
    match markdown_editor_backspace_marker(source, caret, selection) {
      Some(transform) => return Some(transform)
      None =>
        return markdown_editor_backspace_merge_block(source, caret, selection)
    }
  }
  if input == "\u{007f}" {
    return markdown_editor_delete_merge_block(source, caret, selection)
  }
  if input == " " {
    match markdown_editor_autocomplete_block_marker(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match markdown_editor_complete_autolink_on_space(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
  }
  if input != "\n" || markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let current = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  let chars = source.to_array()
  let line = String::from_array(chars[range.start:range.end])
  match
    markdown_editor_complete_table_header_on_enter(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_insert_table_row_on_enter(source, caret, selection) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_complete_rule_on_enter(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_exit_empty_continuation(chars, range, line) {
    Some(transform) => return Some(transform)
    None => ()
  }
  let marker = markdown_editor_continuation_marker(line)
  if marker == "" {
    None
  } else {
    let insert = "\n" + marker
    let caret = markdown_editor_clamp_int(caret, 0, chars.length())
    Some(
      markdown_editor_transform_result(
        text=String::from_array(chars[:caret]) +
          insert +
          String::from_array(chars[caret:]),
        caret=caret + markdown_editor_text_length(insert),
      ),
    )
  }
}

///|
fn markdown_editor_paste_autolink(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) ||
    markdown_editor_code_block_at_content_offset(source, caret, selection)
    is Some(_) {
    return None
  }
  let target = input.trim().to_owned()
  if !markdown_editor_is_plain_url(target) ||
    markdown_editor_text_length(target) != markdown_editor_text_length(input) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let insert = "<" + target + ">"
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret]) +
        insert +
        String::from_array(chars[caret:]),
      caret=caret + markdown_editor_text_length(insert),
    ),
  )
}

///|
fn markdown_editor_complete_autolink_on_space(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) ||
    markdown_editor_code_block_at_content_offset(source, caret, selection)
    is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let start = markdown_editor_previous_token_start(chars, caret)
  if start == caret || (start > 0 && chars[start - 1] == '<') {
    return None
  }
  let token = String::from_array(chars[start:caret])
  if !markdown_editor_is_plain_url(token) {
    return None
  }
  let replacement = "<" + token + "> "
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:start]) +
        replacement +
        String::from_array(chars[caret:]),
      caret=start + markdown_editor_text_length(replacement),
    ),
  )
}

///|
fn markdown_editor_previous_token_start(
  chars : Array[Char],
  caret : Int,
) -> Int {
  let mut start = markdown_editor_clamp_int(caret, 0, chars.length())
  while start > 0 &&
        chars[start - 1] != ' ' &&
        chars[start - 1] != '\n' &&
        chars[start - 1] != '\t' {
    start = start - 1
  }
  start
}

///|
fn markdown_editor_paste_reference_over_selection(
  source : String,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      let target = input.trim().to_owned()
      if markdown_editor_text_length(target) !=
        markdown_editor_text_length(input) {
        return None
      }
      let command = if markdown_editor_is_image_source(target) {
        SetImageTarget(target)
      } else if markdown_editor_is_plain_url(target) {
        SetLinkTarget(target)
      } else {
        return None
      }
      let result = markdown_editor_set_reference_target(
        source,
        { caret: range.end, selection: Some(range) },
        command,
        target,
      )
      Some(
        markdown_editor_transform_result(
          text=result.source,
          caret=result.caret,
          selection=result.selection,
        ),
      )
    }
    None => None
  }
}

///|
fn markdown_editor_is_image_source(text : String) -> Bool {
  if text.contains("\n") || text.contains(" ") || text == "" {
    return false
  }
  let lower = text.to_lower()
  markdown_editor_has_image_extension(lower)
}

///|
fn markdown_editor_has_image_extension(text : String) -> Bool {
  for ext in [".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".avif"] {
    if text.contains(ext) {
      return true
    }
  }
  false
}

///|
fn markdown_editor_is_plain_url(text : String) -> Bool {
  (text.has_prefix("https://") || text.has_prefix("http://")) &&
  !text.contains("\n") &&
  !text.contains(" ") &&
  markdown_editor_text_length(text) > markdown_editor_text_length("https://")
}

///|
fn markdown_editor_wrap_selection_input(
  source : String,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  let marker = match input {
    "**" => "**"
    "~~" => "~~"
    "`" => "`"
    "*" => "*"
    _ => return None
  }
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      let result = markdown_editor_toggle_inline_range(source, range, marker)
      Some(
        markdown_editor_transform_result(
          text=result.source,
          caret=result.caret,
          selection=result.selection,
        ),
      )
    }
    None => None
  }
}

///|
fn markdown_editor_complete_code_fence_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret != range.end {
    return None
  }
  let fence = match markdown_editor_opening_code_fence_marker(line) {
    Some(fence) => fence.marker
    None => return None
  }
  let indent = markdown_editor_line_indent_prefix(line)
  let insert = "\n" + indent + "\n" + indent + fence
  let text = String::from_array(chars[:caret]) +
    insert +
    String::from_array(chars[caret:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=caret + 1 + markdown_editor_text_length(indent),
    ),
  )
}

///|
fn markdown_editor_opening_code_fence_marker(
  line : String,
) -> MarkdownCodeFenceInfo? {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() < indent + 3 {
    return None
  }
  if chars[indent] != '`' ||
    chars[indent + 1] != '`' ||
    chars[indent + 2] != '`' {
    return None
  }
  let mut fence_end = indent + 3
  while fence_end < chars.length() && chars[fence_end] == '`' {
    fence_end = fence_end + 1
  }
  for index in fence_end..<chars.length() {
    if chars[index] == '`' {
      return None
    }
  }
  Some({
    marker: String::from_array(chars[indent:fence_end]),
    info: markdown_code_fence_info(chars, fence_end),
  })
}

///|
fn markdown_editor_code_block(
  text : String,
  code_language : String?,
) -> MarkdownBlock {
  {
    kind: MarkdownBlockKind::CodeBlock,
    text,
    inlines: [],
    table_alignments: [],
    code_language,
  }
}

///|
fn markdown_editor_line_indent_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  String::from_array(chars[:indent])
}

///|
fn markdown_editor_complete_table_header_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret != range.end || !markdown_editor_table_header_candidate(line) {
    return None
  }
  let column_count = markdown_editor_split_table_cells(line).length()
  if column_count <= 1 {
    return None
  }
  let separator = markdown_editor_table_separator_for_columns(column_count)
  let row = markdown_editor_empty_table_row(column_count)
  let insert = "\n" + separator + "\n" + row
  let text = String::from_array(chars[:caret]) +
    insert +
    String::from_array(chars[caret:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=caret +
        markdown_editor_text_length(insert) -
        markdown_editor_text_length(row) +
        2,
    ),
  )
}

///|
fn markdown_editor_table_header_candidate(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if !trimmed.contains("|") || markdown_editor_table_separator_line(trimmed) {
    return false
  }
  let cells = markdown_editor_split_table_cells(trimmed)
  if cells.length() <= 1 {
    return false
  }
  for cell in cells {
    if cell.trim().to_owned() == "" {
      return false
    }
  }
  true
}

///|
fn markdown_editor_table_separator_for_columns(column_count : Int) -> String {
  let cells : Array[String] = []
  for _ in 0..<column_count {
    cells.push("---")
  }
  "| " + cells.join(" | ") + " |"
}

///|
fn markdown_editor_complete_rule_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret != range.end || !markdown_editor_is_typed_rule_line(line) {
    return None
  }
  let text = String::from_array(chars[:caret]) +
    "\n" +
    String::from_array(chars[caret:])
  Some(markdown_editor_transform_result(text~, caret=caret + 1))
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
) -> @core.RichTextInputTransform {
  markdown_editor_normalize_ordered_transform(
    @core.RichTextInputTransform::new(text~, caret~, selection~),
  )
}

///|
fn markdown_editor_normalize_ordered_transform(
  edit : @core.RichTextInputTransform,
) -> @core.RichTextInputTransform {
  let normalized = markdown_editor_renumber_ordered_lists(edit.text)
  if normalized.text == edit.text {
    edit
  } else {
    @core.RichTextInputTransform::new(
      text=normalized.text,
      caret=markdown_editor_map_offset_after_replacements(
        edit.caret,
        normalized.replacements,
      ),
      selection=match edit.selection {
        Some(selection) =>
          Some(
            @core.TextRange::new(
              start=markdown_editor_map_offset_after_replacements(
                selection.start,
                normalized.replacements,
              ),
              end=markdown_editor_map_offset_after_replacements(
                selection.end,
                normalized.replacements,
              ),
            ),
          )
        None => None
      },
    )
  }
}

///|
fn markdown_editor_normalize_ordered_edit_result(
  edit : MarkdownEditorEditResult,
) -> MarkdownEditorEditResult {
  let normalized = markdown_editor_renumber_ordered_lists(edit.source)
  if normalized.text == edit.source {
    edit
  } else {
    {
      source: normalized.text,
      caret: markdown_editor_map_offset_after_replacements(
        edit.caret,
        normalized.replacements,
      ),
      selection: match edit.selection {
        Some(selection) =>
          Some(
            @core.TextRange::new(
              start=markdown_editor_map_offset_after_replacements(
                selection.start,
                normalized.replacements,
              ),
              end=markdown_editor_map_offset_after_replacements(
                selection.end,
                normalized.replacements,
              ),
            ),
          )
        None => None
      },
    }
  }
}

///|
struct MarkdownEditorOffsetReplacement {
  start : Int
  old_end : Int
  new_end : Int
} derive(Eq, Debug)

///|
struct MarkdownEditorRenumberResult {
  text : String
  replacements : Array[MarkdownEditorOffsetReplacement]
} derive(Eq, Debug)

///|
fn markdown_editor_autocomplete_block_marker(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current = { caret, selection }
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
  } else if token == "-" || token == "*" {
    prefix + "- "
  } else if token == "[]" || token == "[ ]" {
    prefix + "- [ ] "
  } else if token == "[x]" || token == "[X]" {
    prefix + "- [x] "
  } else if token == ">" {
    prefix + "> "
  } else if markdown_editor_typed_ordered_marker(token) is Some(number) {
    prefix + number.to_string() + ". "
  } else {
    ""
  }
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
  if chars.length() < 2 || chars[chars.length() - 1] != '.' {
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
fn markdown_editor_renumber_ordered_lists(
  source : String,
) -> MarkdownEditorRenumberResult {
  let lines = markdown_editor_lines(source)
  let rendered : Array[String] = []
  let replacements : Array[MarkdownEditorOffsetReplacement] = []
  let mut expected = 1
  let mut active_indent = -1
  let mut in_ordered = false
  for line in lines {
    match markdown_editor_ordered_line_info(line.text) {
      Some(info) => {
        if !in_ordered || info.indent != active_indent {
          expected = info.number
          active_indent = info.indent
          in_ordered = true
        }
        let next_number = expected
        expected = expected + 1
        let next_digits = next_number.to_string()
        if next_digits == info.digits {
          rendered.push(line.text)
        } else {
          let chars = line.text.to_array()
          rendered.push(
            String::from_array(chars[:info.digit_start]) +
            next_digits +
            String::from_array(chars[info.digit_end:]),
          )
          replacements.push({
            start: line.start + info.digit_start,
            old_end: line.start + info.digit_end,
            new_end: line.start +
            info.digit_start +
            markdown_editor_text_length(next_digits),
          })
        }
      }
      None => {
        in_ordered = false
        active_indent = -1
        expected = 1
        rendered.push(line.text)
      }
    }
  }
  { text: markdown_join_lines(rendered), replacements }
}

///|
struct MarkdownEditorOrderedLineInfo {
  indent : Int
  digit_start : Int
  digit_end : Int
  digits : String
  number : Int
} derive(Eq, Debug)

///|
fn markdown_editor_ordered_line_info(
  line : String,
) -> MarkdownEditorOrderedLineInfo? {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let digit_end = markdown_editor_ordered_digit_end(chars)
  if digit_end <= indent ||
    digit_end + 1 >= chars.length() ||
    chars[digit_end] != '.' ||
    chars[digit_end + 1] != ' ' {
    None
  } else {
    Some({
      indent,
      digit_start: indent,
      digit_end,
      digits: String::from_array(chars[indent:digit_end]),
      number: markdown_editor_parse_digits(chars, indent, digit_end),
    })
  }
}

///|
fn markdown_editor_map_offset_after_replacements(
  offset : Int,
  replacements : Array[MarkdownEditorOffsetReplacement],
) -> Int {
  let mut mapped = offset
  for replacement in replacements {
    let delta = replacement.new_end - replacement.old_end
    if offset > replacement.old_end {
      mapped = mapped + delta
    } else if offset >= replacement.start {
      mapped = replacement.new_end
    }
  }
  mapped
}

///|
fn markdown_editor_is_multiline_input(input : String) -> Bool {
  input != "\n" && input.contains("\n")
}

///|
fn markdown_editor_transform_multiline_paste(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  match markdown_editor_active_selection(selection) {
    Some(_) => None
    None => {
      let current = { caret, selection }
      let range = markdown_editor_current_line_range(source, current)
      let chars = source.to_array()
      let line = String::from_array(chars[range.start:range.end])
      let insert = match
        markdown_editor_code_block_at_content_offset(source, caret, selection) {
        Some(_) => markdown_editor_code_block_paste_insert(source, caret, input)
        None => markdown_editor_contextual_paste_insert(line, input)
      }
      if insert == input {
        None
      } else {
        let caret = markdown_editor_clamp_int(caret, 0, chars.length())
        Some(
          markdown_editor_transform_result(
            text=String::from_array(chars[:caret]) +
              insert +
              String::from_array(chars[caret:]),
            caret=caret + markdown_editor_text_length(insert),
          ),
        )
      }
    }
  }
}

///|
fn markdown_editor_code_block_paste_insert(
  source : String,
  caret : Int,
  input : String,
) -> String {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let line_start = markdown_editor_line_start(chars, caret)
  let indent = markdown_editor_line_indent(chars, line_start, caret)
  markdown_editor_join_paste_lines(
    markdown_editor_prefix_paste_continuation_lines(input, indent),
  )
}

///|
fn markdown_editor_contextual_paste_insert(
  line : String,
  input : String,
) -> String {
  if markdown_editor_continuation_marker(line) == "" {
    return input
  }
  let continuation = markdown_editor_continuation_marker(line)
  let lines = markdown_editor_paste_lines(input)
  let formatted : Array[String] = []
  let mut ordered_number = markdown_editor_ordered_continuation_number(line)
  for index in 0..<lines.length() {
    if index == 0 {
      formatted.push(lines[index])
      continue
    }
    let prefix = if ordered_number > 0 {
      let marker = markdown_editor_ordered_paste_prefix(line, ordered_number)
      ordered_number = ordered_number + 1
      marker
    } else {
      continuation
    }
    formatted.push(prefix + markdown_editor_strip_block_marker(lines[index]))
  }
  markdown_editor_join_paste_lines(formatted)
}

///|
fn markdown_editor_ordered_continuation_number(line : String) -> Int {
  let chars = line.to_array()
  if markdown_editor_ordered_marker_length(chars) > 0 {
    markdown_editor_parse_digits(
      chars,
      markdown_editor_leading_indent_length(chars),
      markdown_editor_ordered_digit_end(chars),
    ) +
    1
  } else {
    0
  }
}

///|
fn markdown_editor_ordered_paste_prefix(line : String, number : Int) -> String {
  let chars = line.to_array()
  String::from_array(chars[:markdown_editor_leading_indent_length(chars)]) +
  number.to_string() +
  ". "
}

///|
fn markdown_editor_ordered_digit_end(chars : Array[Char]) -> Int {
  let mut index = markdown_editor_leading_indent_length(chars)
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_paste_lines(input : String) -> Array[String] {
  let lines = markdown_editor_lines(
    markdown_editor_trim_trailing_newline(input),
  )
  let result : Array[String] = []
  for line in lines {
    result.push(line.text)
  }
  result
}

///|
fn markdown_editor_prefix_paste_continuation_lines(
  input : String,
  prefix : String,
) -> Array[String] {
  let lines = markdown_editor_paste_lines(input)
  let result : Array[String] = []
  for index in 0..<lines.length() {
    if index == 0 {
      result.push(lines[index])
    } else {
      result.push(prefix + lines[index])
    }
  }
  result
}

///|
fn markdown_editor_join_paste_lines(lines : Array[String]) -> String {
  markdown_join_lines(lines)
}

///|
fn markdown_editor_trim_trailing_newline(input : String) -> String {
  let chars = input.to_array()
  if chars.length() > 0 && chars[chars.length() - 1] == '\n' {
    String::from_array(chars[:chars.length() - 1])
  } else {
    input
  }
}

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
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  match markdown_editor_backspace_inline_marker(source, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  let chars = source.to_array()
  let current = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  let line = String::from_array(chars[range.start:range.end])
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
fn markdown_editor_backspace_merge_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if caret == 0 || chars[caret - 1] != '\n' {
    return None
  }
  let current = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  if caret != range.start {
    return None
  }
  let previous_end = caret - 1
  let previous_start = markdown_editor_previous_line_start(chars, previous_end)
  let previous_line = String::from_array(chars[previous_start:previous_end])
  let current_line = String::from_array(chars[range.start:range.end])
  let previous_content = markdown_editor_strip_block_marker(previous_line)
  let current_content = markdown_editor_strip_block_marker(current_line)
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
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_delete_inline_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  if caret >= chars.length() || chars[caret] != '\n' {
    return None
  }
  let current = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  if caret != range.end {
    return None
  }
  let next_start = caret + 1
  let next_end = markdown_editor_next_line_end(chars, next_start)
  let current_line = String::from_array(chars[range.start:range.end])
  let next_line = String::from_array(chars[next_start:next_end])
  let current_content = markdown_editor_strip_block_marker(current_line)
  let next_content = markdown_editor_strip_block_marker(next_line)
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
      markdown_editor_block_marker_prefix(first_line)
  }
}

///|
enum MarkdownEditorMergeBlockKind {
  Plain
  Bullet
  Task
  Ordered
  Quote
} derive(Eq, Debug)

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
fn markdown_editor_block_marker_prefix(line : String) -> String {
  let marker_length = markdown_editor_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[:marker_length])
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
fn markdown_editor_backspace_inline_marker(
  source : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_backspace_reference_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  for marker in ["**", "~~", "`", "*"] {
    let marker_length = markdown_editor_text_length(marker)
    if caret >= marker_length &&
      markdown_editor_source_has_marker(chars, caret - marker_length, marker) {
      match markdown_editor_find_inline_closing_marker(chars, caret, marker) {
        Some(close_start) =>
          return Some(
            markdown_editor_remove_inline_marker_pair(
              chars,
              caret - marker_length,
              marker_length,
              close_start,
            ),
          )
        None => ()
      }
    }
  }
  None
}

///|
fn markdown_editor_delete_inline_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  match markdown_editor_delete_reference_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  for marker in ["**", "~~", "`", "*"] {
    let marker_length = markdown_editor_text_length(marker)
    if markdown_editor_source_has_marker(chars, caret, marker) {
      match markdown_editor_find_inline_opening_marker(chars, caret, marker) {
        Some(open_start) =>
          return Some(
            markdown_editor_remove_inline_marker_pair(
              chars, open_start, marker_length, caret,
            ),
          )
        None => ()
      }
    }
  }
  None
}

///|
fn markdown_editor_delete_reference_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret >= chars.length() || chars[caret] != ']' {
    return None
  }
  match markdown_editor_reference_open_before(chars, caret) {
    Some(bounds) => {
      let mut content_start = bounds.open_start + 1
      if chars[bounds.open_start] == '!' {
        content_start = bounds.open_start + 2
      }
      Some(
        markdown_editor_remove_reference_marker(
          chars,
          bounds.open_start,
          content_start,
          caret,
          bounds.target_end,
        ),
      )
    }
    None => None
  }
}

///|
fn markdown_editor_reference_open_before(
  chars : Array[Char],
  close_start : Int,
) -> MarkdownLinkBounds? {
  if close_start + 1 >= chars.length() || chars[close_start + 1] != '(' {
    return None
  }
  let mut target_end = close_start + 2
  while target_end < chars.length() &&
        chars[target_end] != ')' &&
        chars[target_end] != '\n' {
    target_end = target_end + 1
  }
  if target_end >= chars.length() || chars[target_end] != ')' {
    return None
  }
  let mut open_start = close_start
  while open_start > 0 &&
        chars[open_start - 1] != '[' &&
        chars[open_start - 1] != '\n' {
    open_start = open_start - 1
  }
  if open_start == 0 || chars[open_start - 1] != '[' {
    return None
  }
  let bracket_start = open_start - 1
  let open_start = if bracket_start > 0 && chars[bracket_start - 1] == '!' {
    bracket_start - 1
  } else {
    bracket_start
  }
  Some({
    open_start,
    close_start,
    target_start: close_start + 2,
    target_end,
    definition_target_start: -1,
    definition_target_end: -1,
    reference_label: "",
  })
}

///|
fn markdown_editor_backspace_reference_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret >= 2 && chars[caret - 2] == '!' && chars[caret - 1] == '[' {
    match markdown_editor_reference_close_after(chars, caret) {
      Some(bounds) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 2,
            caret,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      None => ()
    }
  }
  if caret >= 1 && chars[caret - 1] == '[' {
    match markdown_editor_reference_close_after(chars, caret) {
      Some(bounds) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 1,
            caret,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_reference_close_after(
  chars : Array[Char],
  content_start : Int,
) -> MarkdownLinkBounds? {
  let mut close_start = content_start
  while close_start < chars.length() &&
        chars[close_start] != ']' &&
        chars[close_start] != '\n' {
    close_start = close_start + 1
  }
  if close_start + 1 >= chars.length() ||
    chars[close_start] != ']' ||
    chars[close_start + 1] != '(' {
    return None
  }
  let mut target_end = close_start + 2
  while target_end < chars.length() &&
        chars[target_end] != ')' &&
        chars[target_end] != '\n' {
    target_end = target_end + 1
  }
  if target_end < chars.length() && chars[target_end] == ')' {
    Some({
      open_start: content_start - 1,
      close_start,
      target_start: close_start + 2,
      target_end,
      definition_target_start: -1,
      definition_target_end: -1,
      reference_label: "",
    })
  } else {
    None
  }
}

///|
fn markdown_editor_remove_reference_marker(
  chars : Array[Char],
  open_start : Int,
  content_start : Int,
  close_start : Int,
  target_end : Int,
) -> @core.RichTextInputTransform {
  let text = String::from_array(chars[:open_start]) +
    String::from_array(chars[content_start:close_start]) +
    String::from_array(chars[target_end + 1:])
  markdown_editor_transform_result(text~, caret=open_start)
}

///|
fn markdown_editor_source_has_marker(
  chars : Array[Char],
  start : Int,
  marker : String,
) -> Bool {
  let marker_chars = marker.to_array()
  if start < 0 || start + marker_chars.length() > chars.length() {
    return false
  }
  for index in 0..<marker_chars.length() {
    if chars[start + index] != marker_chars[index] {
      return false
    }
  }
  true
}

///|
fn markdown_editor_find_inline_closing_marker(
  chars : Array[Char],
  start : Int,
  marker : String,
) -> Int? {
  let marker_length = markdown_editor_text_length(marker)
  let mut index = start
  while index + marker_length <= chars.length() && chars[index] != '\n' {
    if markdown_editor_source_has_marker(chars, index, marker) {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn markdown_editor_find_inline_opening_marker(
  chars : Array[Char],
  close_start : Int,
  marker : String,
) -> Int? {
  let marker_length = markdown_editor_text_length(marker)
  let mut index = close_start - marker_length
  while index >= 0 {
    if chars[index] == '\n' {
      return None
    }
    if markdown_editor_source_has_marker(chars, index, marker) {
      return Some(index)
    }
    index = index - 1
  }
  None
}

///|
fn markdown_editor_remove_inline_marker_pair(
  chars : Array[Char],
  open_start : Int,
  marker_length : Int,
  close_start : Int,
) -> @core.RichTextInputTransform {
  let text = String::from_array(chars[:open_start]) +
    String::from_array(chars[open_start + marker_length:close_start]) +
    String::from_array(chars[close_start + marker_length:])
  markdown_editor_transform_result(text~, caret=open_start)
}

///|
fn markdown_editor_indent_lines(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform {
  markdown_editor_shift_lines(source, caret, selection, indent=true).unwrap()
}

///|
fn markdown_editor_outdent_lines(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  markdown_editor_shift_lines(source, caret, selection, indent=false)
}

///|
fn markdown_editor_shift_lines(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  indent~ : Bool,
) -> @core.RichTextInputTransform? {
  let current = { caret, selection }
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
) -> @core.RichTextInputTransform? {
  if markdown_editor_continuation_marker(line) == "" {
    return None
  }
  let prefix_length = markdown_editor_marker_prefix_length(line)
  if prefix_length == 0 || markdown_editor_text_length(line) != prefix_length {
    return None
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
fn markdown_editor_continuation_marker(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let indent_text = String::from_array(chars[:indent])
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
    indent_text + "- [ ] "
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    indent_text + String::from_array(chars[indent:indent + 2])
  } else if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    indent_text + "> "
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
fn markdown_editor_parse_digits(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> Int {
  let mut value = 0
  for index in start..<end {
    value = value * 10 + chars[index].to_int() - '0'.to_int()
  }
  value
}

///|
