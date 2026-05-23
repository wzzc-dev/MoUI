///|
pub(all) struct MarkdownSourceRange {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorBlock {
  block : MarkdownBlock
  source_range : MarkdownSourceRange
  content_range : MarkdownSourceRange
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorSnapshot {
  source : String
  blocks : Array[MarkdownEditorBlock]
  rich_text : @core.RichTextDocument
  line_count : Int
  word_count : Int
  active_heading : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorSelection {
  caret : Int
  selection : @core.TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorEditResult {
  source : String
  caret : Int
  selection : @core.TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MarkdownEditorCommand {
  Bold
  Italic
  Code
  Strikethrough
  Link
  Image
  SetLinkTarget(String)
  SetImageTarget(String)
  Paragraph
  Heading(Int)
  BulletList
  TaskList
  OrderedList
  Quote
  CodeBlock
  HorizontalRule
  Table
  Clear
} derive(Eq, Debug, ToJson)

///|
struct MarkdownLine {
  text : String
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub fn MarkdownEditorSnapshot::parse(source : String) -> MarkdownEditorSnapshot {
  let blocks = parse_markdown_editor_blocks(source)
  {
    source,
    blocks,
    rich_text: markdown_editor_blocks_to_rich_text(blocks),
    line_count: markdown_editor_line_count(source),
    word_count: markdown_editor_word_count(source),
    active_heading: markdown_editor_active_heading(blocks),
  }
}

///|
pub fn markdown_editor_format(source : String) -> @core.RichTextDocument {
  MarkdownEditorSnapshot::parse(source).rich_text
}

///|
pub fn markdown_editor_apply_command(
  source : String,
  command : MarkdownEditorCommand,
) -> String {
  markdown_editor_apply_command_at(source, command, None).source
}

///|
pub fn markdown_editor_apply_command_at(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection?,
) -> MarkdownEditorEditResult {
  match command {
    Clear => { source: "", caret: 0, selection: None }
    Bold | Italic | Code | Strikethrough =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(range) =>
              markdown_editor_toggle_inline_range(
                source,
                range,
                markdown_editor_inline_marker(command),
              )
            None => markdown_editor_append_snippet(source, command)
          }
        None => markdown_editor_append_snippet(source, command)
      }
    Link | Image =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(range) =>
              if command == Image {
                markdown_editor_toggle_image_range(source, range)
              } else {
                markdown_editor_toggle_link_range(source, range)
              }
            None => markdown_editor_append_snippet(source, command)
          }
        None => markdown_editor_append_snippet(source, command)
      }
    SetLinkTarget(target) | SetImageTarget(target) =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(_) =>
              markdown_editor_set_reference_target(
                source, selection, command, target,
              )
            None => markdown_editor_append_snippet(source, command)
          }
        None => markdown_editor_append_snippet(source, command)
      }
    Paragraph
    | Heading(_)
    | BulletList
    | TaskList
    | OrderedList
    | Quote
    | HorizontalRule
    | Table =>
      match selection {
        Some(selection) =>
          markdown_editor_transform_current_block(source, command, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    CodeBlock =>
      match selection {
        Some(selection) => markdown_editor_toggle_code_block(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
  }
}

///|
pub fn markdown_editor_selected_link_target(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      match markdown_editor_range_link_bounds(source, range.normalized()) {
        Some(bounds) => markdown_editor_reference_target(source, bounds)
        None => None
      }
    None => None
  }
}

///|
pub fn markdown_editor_selected_image_target(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      match markdown_editor_range_image_bounds(source, range.normalized()) {
        Some(bounds) => markdown_editor_reference_target(source, bounds)
        None => None
      }
    None => None
  }
}

///|
pub fn markdown_editor_active_block_label(
  source : String,
  selection : MarkdownEditorSelection,
) -> String {
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if anchor >= block.source_range.start && anchor <= block.source_range.end {
      return markdown_editor_block_kind_label(block.block.kind)
    }
  }
  "Paragraph"
}

///|
pub fn markdown_editor_transform_input(
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
    Some(fence) => fence
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
fn markdown_editor_opening_code_fence_marker(line : String) -> String? {
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
  Some(String::from_array(chars[indent:fence_end]))
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
  if token == "#" {
    prefix + "# "
  } else if token == "##" {
    prefix + "## "
  } else if token == "###" {
    prefix + "### "
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
fn markdown_editor_code_block_at_content_offset(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> MarkdownEditorBlock? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let caret = markdown_editor_clamp_int(
    caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if block.block.kind is MarkdownBlockKind::CodeBlock &&
      caret >= block.content_range.start &&
      caret <= block.content_range.end {
      return Some(block)
    }
  }
  None
}

///|
fn markdown_editor_code_block_enter(
  source : String,
  caret : Int,
) -> @core.RichTextInputTransform {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let line_start = markdown_editor_line_start(chars, caret)
  let indent = markdown_editor_line_indent(chars, line_start, caret)
  let insert = "\n" + indent
  markdown_editor_transform_result(
    text=String::from_array(chars[:caret]) +
      insert +
      String::from_array(chars[caret:]),
    caret=caret + markdown_editor_text_length(insert),
  )
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
  Some({ open_start, close_start, target_end })
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
    Some({ open_start: content_start - 1, close_start, target_end })
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
struct MarkdownEditorTableCellRange {
  hit_start : Int
  hit_end : Int
  content_start : Int
  content_end : Int
  row : Int
  column : Int
} derive(Eq, Debug)

///|
fn markdown_editor_move_table_cell(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  forward~ : Bool,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    if cells.length() == 0 {
      return None
    }
    let current = markdown_editor_table_cell_index_at(cells, caret)
    match current {
      Some(index) =>
        if forward {
          if index + 1 < cells.length() {
            return Some(
              markdown_editor_transform_result(
                text=source,
                caret=cells[index + 1].content_start,
              ),
            )
          }
          return Some(
            markdown_editor_append_table_row(source, block, cells[0].row),
          )
        } else if index > 0 {
          return Some(
            markdown_editor_transform_result(
              text=source,
              caret=cells[index - 1].content_start,
            ),
          )
        } else {
          return Some(markdown_editor_transform_result(text=source, caret~))
        }
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_table_cells_for_block(
  source : String,
  block : MarkdownEditorBlock,
) -> Array[MarkdownEditorTableCellRange] {
  let cells : Array[MarkdownEditorTableCellRange] = []
  let lines = markdown_editor_lines(source)
  let mut table_line_index = 0
  let mut row = 0
  for line in lines {
    if line.start < block.source_range.start ||
      line.end > block.source_range.end {
      continue
    }
    if table_line_index != 1 {
      cells.append(markdown_editor_table_cells_for_line(line, row))
      row = row + 1
    }
    table_line_index = table_line_index + 1
  }
  cells
}

///|
fn markdown_editor_table_cells_for_line(
  line : MarkdownLine,
  row : Int,
) -> Array[MarkdownEditorTableCellRange] {
  let cells : Array[MarkdownEditorTableCellRange] = []
  let chars = line.text.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '|' {
    start = start + 1
  }
  if end > start && chars[end - 1] == '|' {
    end = end - 1
  }
  let mut segment_start = start
  let mut index = start
  let mut column = 0
  while index <= end {
    if index == end || chars[index] == '|' {
      let content = markdown_editor_table_cell_content_range(
        chars, segment_start, index,
      )
      cells.push({
        hit_start: line.start + segment_start,
        hit_end: line.start + index,
        content_start: line.start + content.start,
        content_end: line.start + content.end,
        row,
        column,
      })
      column = column + 1
      segment_start = index + 1
    }
    index = index + 1
  }
  cells
}

///|
fn markdown_editor_table_cell_content_range(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> MarkdownSourceRange {
  let mut content_start = start
  let mut content_end = end
  while content_start < content_end &&
        (chars[content_start] == ' ' || chars[content_start] == '\t') {
    content_start = content_start + 1
  }
  while content_end > content_start &&
        (chars[content_end - 1] == ' ' || chars[content_end - 1] == '\t') {
    content_end = content_end - 1
  }
  { start: content_start, end: content_end }
}

///|
fn markdown_editor_table_cell_index_at(
  cells : Array[MarkdownEditorTableCellRange],
  caret : Int,
) -> Int? {
  for index in 0..<cells.length() {
    let cell = cells[index]
    if caret >= cell.hit_start && caret <= cell.hit_end {
      return Some(index)
    }
  }
  None
}

///|
fn markdown_editor_append_table_row(
  source : String,
  block : MarkdownEditorBlock,
  first_row : Int,
) -> @core.RichTextInputTransform {
  let cells = markdown_editor_table_cells_for_block(source, block)
  let column_count = cells.filter(cell => cell.row == first_row).length()
  let column_count = if column_count <= 0 { 1 } else { column_count }
  let row = markdown_editor_empty_table_row(column_count)
  let chars = source.to_array()
  let text = String::from_array(chars[:block.source_range.end]) +
    "\n" +
    row +
    String::from_array(chars[block.source_range.end:])
  markdown_editor_transform_result(text~, caret=block.source_range.end + 3)
}

///|
fn markdown_editor_empty_table_row(column_count : Int) -> String {
  let cells : Array[String] = []
  for _ in 0..<column_count {
    cells.push("")
  }
  "| " + cells.join(" | ") + " |"
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
fn markdown_editor_append_snippet(
  source : String,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  let snippet = markdown_editor_command_snippet(command)
  let text = if source == "" { snippet } else { source + "\n\n" + snippet }
  { source: text, caret: markdown_editor_text_length(text), selection: None }
}

///|
fn markdown_editor_wrap_range(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let selected = String::from_array(chars[start:end])
  let text = String::from_array(chars[:start]) +
    marker +
    selected +
    marker +
    String::from_array(chars[end:])
  let marker_len = markdown_editor_text_length(marker)
  let selected_len = markdown_editor_text_length(selected)
  let next_selection = @core.TextRange::new(
    start=start + marker_len,
    end=start + marker_len + selected_len,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_toggle_inline_range(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> MarkdownEditorEditResult {
  let normalized = range.normalized()
  if markdown_editor_range_has_inline_marker(source, normalized, marker) {
    markdown_editor_unwrap_range(source, normalized, marker)
  } else {
    markdown_editor_wrap_range(source, normalized, marker)
  }
}

///|
fn markdown_editor_range_has_inline_marker(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> Bool {
  let marker_length = markdown_editor_text_length(marker)
  let chars = source.to_array()
  range.start >= marker_length &&
  range.end + marker_length <= chars.length() &&
  markdown_editor_source_has_marker(chars, range.start - marker_length, marker) &&
  markdown_editor_source_has_marker(chars, range.end, marker)
}

///|
fn markdown_editor_unwrap_range(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> MarkdownEditorEditResult {
  let marker_length = markdown_editor_text_length(marker)
  let chars = source.to_array()
  let open_start = range.start - marker_length
  let text = String::from_array(chars[:open_start]) +
    String::from_array(chars[range.start:range.end]) +
    String::from_array(chars[range.end + marker_length:])
  let next_selection = @core.TextRange::new(
    start=open_start,
    end=open_start + range.end - range.start,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_toggle_link_range(
  source : String,
  range : @core.TextRange,
) -> MarkdownEditorEditResult {
  let normalized = range.normalized()
  match markdown_editor_range_link_bounds(source, normalized) {
    Some(bounds) =>
      markdown_editor_unwrap_link_range(source, normalized, bounds)
    None => markdown_editor_wrap_link_range(source, normalized)
  }
}

///|
fn markdown_editor_toggle_image_range(
  source : String,
  range : @core.TextRange,
) -> MarkdownEditorEditResult {
  let normalized = range.normalized()
  match markdown_editor_range_image_bounds(source, normalized) {
    Some(bounds) =>
      markdown_editor_unwrap_image_range(source, normalized, bounds)
    None => markdown_editor_wrap_image_range(source, normalized)
  }
}

///|
fn markdown_editor_set_reference_target(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
  target : String,
) -> MarkdownEditorEditResult {
  let range = markdown_editor_active_selection(selection.selection)
    .unwrap_or(@core.TextRange::new(start=selection.caret, end=selection.caret))
    .normalized()
  if command == SetImageTarget(target) {
    match markdown_editor_range_image_bounds(source, range) {
      Some(bounds) =>
        return markdown_editor_replace_reference_target(
          source, range, bounds, target,
        )
      None =>
        return markdown_editor_wrap_image_range_with_target(
          source, range, target,
        )
    }
  }
  match markdown_editor_range_link_bounds(source, range) {
    Some(bounds) =>
      markdown_editor_replace_reference_target(source, range, bounds, target)
    None => markdown_editor_wrap_link_range_with_target(source, range, target)
  }
}

///|
struct MarkdownLinkBounds {
  open_start : Int
  close_start : Int
  target_end : Int
} derive(Eq, Debug)

///|
fn markdown_editor_range_link_bounds(
  source : String,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  let chars = source.to_array()
  if range.start < 1 || range.end + 2 > chars.length() {
    return None
  }
  let open_start = range.start - 1
  if open_start > 0 && chars[open_start - 1] == '!' {
    return None
  }
  if chars[open_start] != '[' ||
    chars[range.end] != ']' ||
    chars[range.end + 1] != '(' {
    return None
  }
  let mut index = range.end + 2
  while index < chars.length() && chars[index] != ')' && chars[index] != '\n' {
    index = index + 1
  }
  if index < chars.length() && chars[index] == ')' {
    Some({ open_start, close_start: range.end, target_end: index })
  } else {
    None
  }
}

///|
fn markdown_editor_range_image_bounds(
  source : String,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  let chars = source.to_array()
  if range.start < 2 || range.end + 2 > chars.length() {
    return None
  }
  let bang_start = range.start - 2
  let open_start = range.start - 1
  if chars[bang_start] != '!' ||
    chars[open_start] != '[' ||
    chars[range.end] != ']' ||
    chars[range.end + 1] != '(' {
    return None
  }
  let mut index = range.end + 2
  while index < chars.length() && chars[index] != ')' && chars[index] != '\n' {
    index = index + 1
  }
  if index < chars.length() && chars[index] == ')' {
    Some({ open_start: bang_start, close_start: range.end, target_end: index })
  } else {
    None
  }
}

///|
fn markdown_editor_wrap_link_range(
  source : String,
  range : @core.TextRange,
) -> MarkdownEditorEditResult {
  markdown_editor_wrap_link_range_with_target(
    source, range, "https://example.com",
  )
}

///|
fn markdown_editor_wrap_link_range_with_target(
  source : String,
  range : @core.TextRange,
  target : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let selected = String::from_array(chars[start:end])
  let text = String::from_array(chars[:start]) +
    "[" +
    selected +
    "](" +
    target +
    ")" +
    String::from_array(chars[end:])
  let next_selection = @core.TextRange::new(
    start=start + 1,
    end=start + 1 + end - start,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_wrap_image_range(
  source : String,
  range : @core.TextRange,
) -> MarkdownEditorEditResult {
  markdown_editor_wrap_image_range_with_target(source, range, "image.png")
}

///|
fn markdown_editor_wrap_image_range_with_target(
  source : String,
  range : @core.TextRange,
  target : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let selected = String::from_array(chars[start:end])
  let text = String::from_array(chars[:start]) +
    "![" +
    selected +
    "](" +
    target +
    ")" +
    String::from_array(chars[end:])
  let next_selection = @core.TextRange::new(
    start=start + 2,
    end=start + 2 + end - start,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_replace_reference_target(
  source : String,
  range : @core.TextRange,
  bounds : MarkdownLinkBounds,
  target : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let target_start = bounds.close_start + 2
  let text = String::from_array(chars[:target_start]) +
    target +
    String::from_array(chars[bounds.target_end:])
  let next_selection = @core.TextRange::new(start=range.start, end=range.end)
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_reference_target(
  source : String,
  bounds : MarkdownLinkBounds,
) -> String? {
  let chars = source.to_array()
  let start = bounds.close_start + 2
  if start > bounds.target_end || bounds.target_end > chars.length() {
    None
  } else {
    Some(String::from_array(chars[start:bounds.target_end]))
  }
}

///|
fn markdown_editor_unwrap_link_range(
  source : String,
  range : @core.TextRange,
  bounds : MarkdownLinkBounds,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let text = String::from_array(chars[:bounds.open_start]) +
    String::from_array(chars[range.start:range.end]) +
    String::from_array(chars[bounds.target_end + 1:])
  let next_selection = @core.TextRange::new(
    start=bounds.open_start,
    end=bounds.open_start + range.end - range.start,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_unwrap_image_range(
  source : String,
  range : @core.TextRange,
  bounds : MarkdownLinkBounds,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let text = String::from_array(chars[:bounds.open_start]) +
    String::from_array(chars[range.start:range.end]) +
    String::from_array(chars[bounds.target_end + 1:])
  let next_selection = @core.TextRange::new(
    start=bounds.open_start,
    end=bounds.open_start + range.end - range.start,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_transform_current_block(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if source == "" {
    return markdown_editor_append_snippet(source, command)
  }
  match markdown_editor_active_selection(selection.selection) {
    Some(_) =>
      match command {
        Paragraph | BulletList | TaskList | OrderedList | Quote =>
          return markdown_editor_transform_selected_lines(
            source, command, selection,
          )
        HorizontalRule =>
          return markdown_editor_replace_selected_lines_with_rule(
            source, selection,
          )
        Table =>
          return markdown_editor_replace_selected_lines_with_table(
            source, selection,
          )
        _ => ()
      }
    None => ()
  }
  let range = markdown_editor_current_line_range(source, selection)
  let chars = source.to_array()
  let line = String::from_array(chars[range.start:range.end])
  let stripped = markdown_editor_strip_block_marker(line)
  let prefix = markdown_editor_block_prefix(command)
  if command == Paragraph {
    let next_source = String::from_array(chars[:range.start]) +
      stripped +
      String::from_array(chars[range.end:])
    let next_caret = range.start +
      markdown_editor_caret_offset_in_stripped_line(
        line,
        selection.caret - range.start,
      )
    { source: next_source, caret: next_caret, selection: None }
  } else if command == HorizontalRule {
    let next_source = String::from_array(chars[:range.start]) +
      "---" +
      String::from_array(chars[range.end:])
    { source: next_source, caret: range.start + 3, selection: None }
  } else if command == Table {
    let snippet = markdown_editor_command_snippet(Table)
    let next_source = String::from_array(chars[:range.start]) +
      snippet +
      String::from_array(chars[range.end:])
    { source: next_source, caret: range.start + 2, selection: None }
  } else if prefix == "" {
    markdown_editor_append_snippet(source, command)
  } else {
    let replacement = if markdown_editor_line_has_same_block_marker(
        line, command,
      ) {
      stripped
    } else {
      prefix + stripped
    }
    let next_source = String::from_array(chars[:range.start]) +
      replacement +
      String::from_array(chars[range.end:])
    let replacement_prefix_length = markdown_editor_text_length(replacement) -
      markdown_editor_text_length(stripped)
    let next_caret = range.start +
      replacement_prefix_length +
      markdown_editor_caret_offset_in_stripped_line(
        line,
        selection.caret - range.start,
      )
    { source: next_source, caret: next_caret, selection: None }
  }
}

///|
fn markdown_editor_replace_selected_lines_with_table(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let snippet = markdown_editor_command_snippet(Table)
  let text = String::from_array(chars[:range.start]) +
    snippet +
    String::from_array(chars[range.end:])
  let next_selection = @core.TextRange::new(
    start=range.start,
    end=range.start + markdown_editor_text_length(snippet),
  )
  { source: text, caret: range.start + 2, selection: Some(next_selection) }
}

///|
fn markdown_editor_replace_selected_lines_with_rule(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let text = String::from_array(chars[:range.start]) +
    "---" +
    String::from_array(chars[range.end:])
  let next_selection = @core.TextRange::new(
    start=range.start,
    end=range.start + 3,
  )
  { source: text, caret: range.start + 3, selection: Some(next_selection) }
}

///|
fn markdown_editor_line_has_same_block_marker(
  line : String,
  command : MarkdownEditorCommand,
) -> Bool {
  let marker_length = markdown_editor_marker_prefix_length(line)
  let indent_length = markdown_editor_line_indent_prefix_length(line)
  match command {
    Heading(level) => markdown_editor_heading_marker_level(line) == level
    BulletList =>
      marker_length == indent_length + 2 &&
      markdown_editor_string_ends_with(
        markdown_editor_continuation_marker(line),
        "- ",
      )
    TaskList => marker_length == indent_length + 6
    OrderedList => markdown_editor_ordered_marker_length(line.to_array()) > 0
    Quote =>
      marker_length == indent_length + 2 &&
      markdown_editor_string_ends_with(
        markdown_editor_continuation_marker(line),
        "> ",
      )
    _ => false
  }
}

///|
fn markdown_editor_heading_marker_level(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let mut index = indent
  while index < chars.length() && chars[index] == '#' {
    index = index + 1
  }
  if index > 0 && index < chars.length() && chars[index] == ' ' {
    index - indent
  } else {
    0
  }
}

///|
fn markdown_editor_caret_offset_in_stripped_line(
  line : String,
  caret_offset : Int,
) -> Int {
  let marker_length = markdown_editor_marker_prefix_length(line)
  let stripped_length = markdown_editor_text_length(line) - marker_length
  markdown_editor_clamp_int(caret_offset - marker_length, 0, stripped_length)
}

///|
fn markdown_editor_transform_selected_lines(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let segment = String::from_array(chars[range.start:range.end])
  let transformed = markdown_editor_transform_line_segment(segment, command)
  let text = String::from_array(chars[:range.start]) +
    transformed +
    String::from_array(chars[range.end:])
  let delta = markdown_editor_text_length(transformed) -
    (range.end - range.start)
  let next_selection = Some(
    @core.TextRange::new(
      start=range.start,
      end=range.start + markdown_editor_text_length(transformed),
    ),
  )
  let caret = if selection.caret <= range.start {
    selection.caret
  } else if selection.caret <= range.end {
    range.start + markdown_editor_text_length(transformed)
  } else {
    selection.caret + delta
  }
  { source: text, caret, selection: next_selection }
}

///|
fn markdown_editor_transform_line_segment(
  segment : String,
  command : MarkdownEditorCommand,
) -> String {
  let lines = markdown_editor_lines(segment)
  let transformed : Array[String] = []
  let mut ordered_number = 1
  for line in lines {
    let stripped = markdown_editor_strip_block_marker(line.text)
    match command {
      Paragraph => transformed.push(stripped)
      BulletList => transformed.push("- " + stripped)
      TaskList => transformed.push("- [ ] " + stripped)
      OrderedList => {
        transformed.push(ordered_number.to_string() + ". " + stripped)
        ordered_number = ordered_number + 1
      }
      Quote => transformed.push("> " + stripped)
      _ => transformed.push(line.text)
    }
  }
  markdown_join_lines(transformed)
}

///|
fn markdown_editor_toggle_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if source == "" {
    return markdown_editor_append_snippet(source, CodeBlock)
  }
  match markdown_editor_containing_code_block(source, selection) {
    Some(block) => markdown_editor_unwrap_code_block(source, block, selection)
    None => markdown_editor_wrap_lines_in_code_block(source, selection)
  }
}

///|
fn markdown_editor_containing_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlock? {
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if block.block.kind is MarkdownBlockKind::CodeBlock &&
      anchor >= block.source_range.start &&
      anchor <= block.source_range.end {
      return Some(block)
    }
  }
  None
}

///|
fn markdown_editor_unwrap_code_block(
  source : String,
  block : MarkdownEditorBlock,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let open_end = markdown_editor_min_int(
    block.source_range.start + 4,
    chars.length(),
  )
  let close_start = markdown_editor_max_int(
    block.content_range.end - 1,
    open_end,
  )
  let text = String::from_array(chars[:block.source_range.start]) +
    String::from_array(chars[open_end:close_start]) +
    String::from_array(chars[block.source_range.end:])
  let removed_before_content = open_end - block.source_range.start
  let removed_total = removed_before_content +
    block.source_range.end -
    close_start
  let caret = if selection.caret <= block.source_range.start {
    selection.caret
  } else if selection.caret <= block.source_range.end {
    markdown_editor_clamp_int(
      selection.caret - removed_before_content,
      block.source_range.start,
      block.source_range.end - removed_total,
    )
  } else {
    selection.caret - removed_total
  }
  let next_selection = match
    markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      Some(
        @core.TextRange::new(
          start=markdown_editor_unwrapped_code_offset(
            range.start,
            block,
            removed_before_content,
            removed_total,
          ),
          end=markdown_editor_unwrapped_code_offset(
            range.end,
            block,
            removed_before_content,
            removed_total,
          ),
        ),
      )
    None => None
  }
  { source: text, caret, selection: next_selection }
}

///|
fn markdown_editor_unwrapped_code_offset(
  offset : Int,
  block : MarkdownEditorBlock,
  removed_before_content : Int,
  removed_total : Int,
) -> Int {
  if offset <= block.source_range.start {
    offset
  } else if offset <= block.source_range.end {
    markdown_editor_clamp_int(
      offset - removed_before_content,
      block.source_range.start,
      block.source_range.end - removed_total,
    )
  } else {
    offset - removed_total
  }
}

///|
fn markdown_editor_wrap_lines_in_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let selected = String::from_array(chars[range.start:range.end])
  let prefix = "```\n"
  let suffix = "\n```"
  let text = String::from_array(chars[:range.start]) +
    prefix +
    selected +
    suffix +
    String::from_array(chars[range.end:])
  let prefix_length = markdown_editor_text_length(prefix)
  let caret = if selection.caret < range.start {
    selection.caret
  } else if selection.caret <= range.end {
    selection.caret + prefix_length
  } else {
    selection.caret + prefix_length + markdown_editor_text_length(suffix)
  }
  let next_selection = match
    markdown_editor_active_selection(selection.selection) {
    Some(active) =>
      Some(
        @core.TextRange::new(
          start=active.start + prefix_length,
          end=active.end + prefix_length,
        ),
      )
    None => None
  }
  { source: text, caret, selection: next_selection }
}

///|
fn markdown_editor_selected_line_range(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownSourceRange {
  let chars = source.to_array()
  match markdown_editor_active_selection(selection.selection) {
    Some(active) => {
      let start_anchor = markdown_editor_clamp_int(
        active.start,
        0,
        chars.length(),
      )
      let mut end_anchor = markdown_editor_clamp_int(
        active.end,
        start_anchor,
        chars.length(),
      )
      if end_anchor > start_anchor && chars[end_anchor - 1] == '\n' {
        end_anchor = end_anchor - 1
      }
      markdown_editor_line_range_around(chars, start_anchor, end_anchor)
    }
    None => markdown_editor_current_line_range(source, selection)
  }
}

///|
fn markdown_editor_line_range_around(
  chars : Array[Char],
  start_anchor : Int,
  end_anchor : Int,
) -> MarkdownSourceRange {
  let mut start = start_anchor
  while start > 0 && chars[start - 1] != '\n' {
    start = start - 1
  }
  let mut end = end_anchor
  while end < chars.length() && chars[end] != '\n' {
    end = end + 1
  }
  { start, end }
}

///|
fn markdown_editor_current_line_range(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownSourceRange {
  let chars = source.to_array()
  let active = markdown_editor_active_selection(selection.selection)
  let caret = match active {
    Some(range) => range.start
    None => selection.caret
  }
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let mut start = caret
  while start > 0 && chars[start - 1] != '\n' {
    start = start - 1
  }
  let mut end = caret
  while end < chars.length() && chars[end] != '\n' {
    end = end + 1
  }
  { start, end }
}

///|
fn markdown_editor_block_prefix(command : MarkdownEditorCommand) -> String {
  match command {
    Paragraph => ""
    Heading(level) =>
      if level <= 1 {
        "# "
      } else if level == 2 {
        "## "
      } else {
        "### "
      }
    BulletList => "- "
    TaskList => "- [ ] "
    OrderedList => "1. "
    Quote => "> "
    _ => ""
  }
}

///|
fn markdown_editor_strip_block_marker(line : String) -> String {
  let offset = markdown_editor_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[offset:])
}

///|
fn markdown_editor_marker_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 && chars[indent] == '#' {
    let mut index = indent
    while index < chars.length() && chars[index] == '#' {
      index = index + 1
    }
    if index < chars.length() && chars[index] == ' ' {
      index + 1
    } else {
      0
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
    indent + 6
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    indent + 2
  } else if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    indent + 2
  } else {
    markdown_editor_ordered_marker_length(chars)
  }
}

///|
fn markdown_editor_ordered_marker_length(chars : Array[Char]) -> Int {
  let indent = markdown_editor_leading_indent_length(chars)
  let mut index = indent
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  if index > indent &&
    index + 1 < chars.length() &&
    chars[index] == '.' &&
    chars[index + 1] == ' ' {
    index + 2
  } else {
    0
  }
}

///|
fn markdown_editor_line_indent_prefix_length(line : String) -> Int {
  markdown_editor_leading_indent_length(line.to_array())
}

///|
fn markdown_editor_leading_indent_length(chars : Array[Char]) -> Int {
  let mut index = 0
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_string_ends_with(source : String, suffix : String) -> Bool {
  let source_chars = source.to_array()
  let suffix_chars = suffix.to_array()
  if suffix_chars.length() > source_chars.length() {
    return false
  }
  let start = source_chars.length() - suffix_chars.length()
  for index in 0..<suffix_chars.length() {
    if source_chars[start + index] != suffix_chars[index] {
      return false
    }
  }
  true
}

///|
fn markdown_editor_active_selection(
  selection : @core.TextRange?,
) -> @core.TextRange? {
  match selection {
    Some(selection) => {
      let normalized = selection.normalized()
      if normalized.is_collapsed() {
        None
      } else {
        Some(normalized)
      }
    }
    None => None
  }
}

///|
fn markdown_editor_inline_marker(command : MarkdownEditorCommand) -> String {
  match command {
    Bold => "**"
    Italic => "*"
    Code => "`"
    Strikethrough => "~~"
    _ => ""
  }
}

///|
pub fn markdown_editor_command_snippet(
  command : MarkdownEditorCommand,
) -> String {
  match command {
    Bold => "**bold text**"
    Italic => "*italic text*"
    Code => "`code`"
    Strikethrough => "~~old text~~"
    Link => "[link text](https://example.com)"
    Image => "![image alt](image.png)"
    SetLinkTarget(target) => "[link text](" + target + ")"
    SetImageTarget(target) => "![image alt](" + target + ")"
    Paragraph => "Paragraph"
    Heading(level) =>
      if level <= 1 {
        "# Heading"
      } else if level == 2 {
        "## Section"
      } else {
        "### Detail"
      }
    BulletList => "- List item"
    TaskList => "- [ ] Task item"
    OrderedList => "1. List item"
    Quote => "> Quote"
    CodeBlock => "```\ncode block\n```"
    HorizontalRule => "---"
    Table => "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    Clear => ""
  }
}

///|
pub fn markdown_editor_preview_text(source : String) -> String {
  if source == "" {
    "(empty)"
  } else if markdown_editor_text_length(source) > 700 {
    markdown_editor_substring(source, 0, 700) + "\n..."
  } else {
    source
  }
}

///|
pub fn markdown_editor_toggle_task_at(
  source : String,
  content_offset : Int,
) -> MarkdownEditorEditResult? {
  let chars = source.to_array()
  for block in parse_markdown_editor_blocks(source) {
    match block.block.kind {
      TaskListItem(checked) =>
        if content_offset == block.content_range.start {
          let marker_index = block.content_range.start - 3
          if marker_index < chars.length() {
            let next = if checked { ' ' } else { 'x' }
            let text = String::from_array(chars[:marker_index]) +
              String::from_array([next]) +
              String::from_array(chars[marker_index + 1:])
            return Some({
              source: text,
              caret: block.content_range.start,
              selection: None,
            })
          }
        }
      _ => ()
    }
  }
  None
}

///|
pub fn markdown_editor_line_count(source : String) -> Int {
  if source == "" {
    0
  } else {
    let mut count = 1
    for ch in source {
      if ch == '\n' {
        count = count + 1
      }
    }
    count
  }
}

///|
pub fn markdown_editor_word_count(source : String) -> Int {
  let mut count = 0
  let mut in_word = false
  for ch in source {
    if ch.is_ascii_whitespace() {
      if in_word {
        count = count + 1
      }
      in_word = false
    } else {
      in_word = true
    }
  }
  if in_word {
    count = count + 1
  }
  count
}

///|
fn parse_markdown_editor_blocks(source : String) -> Array[MarkdownEditorBlock] {
  let blocks : Array[MarkdownEditorBlock] = []
  let lines = markdown_editor_lines(source)
  let code_lines : Array[String] = []
  let mut code_start = 0
  let mut code_content_start = 0
  let mut code_fence = ""
  let mut in_code = false
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    if in_code {
      if markdown_editor_closing_code_fence(line.text, code_fence) {
        let text = markdown_join_lines(code_lines).trim().to_owned()
        blocks.push({
          block: markdown_block(MarkdownBlockKind::CodeBlock, text),
          source_range: { start: code_start, end: line.end },
          content_range: { start: code_content_start, end: line.start },
        })
        code_lines.clear()
        code_fence = ""
        in_code = false
      } else {
        code_lines.push(line.text)
      }
    } else if line.text.trim().to_owned() != "" {
      match markdown_editor_opening_code_fence_marker(line.text) {
        Some(fence) => {
          in_code = true
          code_fence = fence
          code_start = line.start
          code_content_start = line.end + 1
        }
        None =>
          match markdown_editor_table_block_at(lines, index) {
            Some(table) => {
              blocks.push(table.block)
              index = table.end_index
            }
            None =>
              match markdown_editor_setext_heading_level_at(lines, index) {
                Some(level) => {
                  let text = line.text.trim().to_owned()
                  blocks.push({
                    block: {
                      kind: MarkdownBlockKind::Heading(level),
                      text,
                      inlines: parse_markdown_inlines(text),
                    },
                    source_range: {
                      start: line.start,
                      end: lines[index + 1].end,
                    },
                    content_range: { start: line.start, end: line.end },
                  })
                  index = index + 1
                }
                None => {
                  let parsed = parse_markdown(line.text)
                  for block in parsed {
                    blocks.push({
                      block,
                      source_range: { start: line.start, end: line.end },
                      content_range: markdown_editor_content_range(
                        line,
                        block.kind,
                      ),
                    })
                  }
                }
              }
          }
      }
    }
    index = index + 1
  }
  if in_code {
    let text = markdown_join_lines(code_lines).trim().to_owned()
    let end = markdown_editor_text_length(source)
    blocks.push({
      block: markdown_block(MarkdownBlockKind::CodeBlock, text),
      source_range: { start: code_start, end },
      content_range: { start: code_content_start, end },
    })
  }
  blocks
}

///|
struct MarkdownEditorTableParseResult {
  block : MarkdownEditorBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_editor_table_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorTableParseResult? {
  if index + 1 >= lines.length() ||
    !markdown_editor_table_separator_line(lines[index + 1].text) {
    return None
  }
  let table_lines : Array[MarkdownLine] = [lines[index], lines[index + 1]]
  let mut next = index + 2
  while next < lines.length() &&
        markdown_editor_table_body_line(lines[next].text) {
    table_lines.push(lines[next])
    next = next + 1
  }
  let segment_lines : Array[String] = []
  for line in table_lines {
    segment_lines.push(line.text)
  }
  let segment = markdown_join_lines(segment_lines)
  match parse_markdown(segment) {
    [{ kind: MarkdownBlockKind::Table, .. } as block] => {
      let source_start = table_lines[0].start
      let source_end = table_lines[table_lines.length() - 1].end
      Some({
        block: {
          block,
          source_range: { start: source_start, end: source_end },
          content_range: { start: source_start, end: source_end },
        },
        end_index: next - 1,
      })
    }
    _ => None
  }
}

///|
fn markdown_editor_table_separator_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if !trimmed.contains("|") {
    return false
  }
  let cells = markdown_editor_split_table_cells(trimmed)
  if cells.length() == 0 {
    return false
  }
  for cell in cells {
    if !markdown_editor_table_separator_cell(cell.trim().to_owned()) {
      return false
    }
  }
  true
}

///|
fn markdown_editor_table_separator_cell(cell : String) -> Bool {
  let chars = cell.to_array()
  let mut dash_count = 0
  for ch in chars {
    if ch == '-' {
      dash_count = dash_count + 1
    } else if ch != ':' && ch != ' ' && ch != '\t' {
      return false
    }
  }
  dash_count >= 3
}

///|
fn markdown_editor_table_body_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed != "" && trimmed.contains("|")
}

///|
fn markdown_editor_split_table_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = line.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '|' {
    start = start + 1
  }
  if end > start && chars[end - 1] == '|' {
    end = end - 1
  }
  let current : Array[Char] = []
  let mut index = start
  while index < end {
    if chars[index] == '|' {
      cells.push(String::from_array(current))
      current.clear()
    } else {
      current.push(chars[index])
    }
    index = index + 1
  }
  cells.push(String::from_array(current))
  cells
}

///|
fn markdown_editor_setext_heading_level_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> Int? {
  if index + 1 >= lines.length() {
    return None
  }
  let text = lines[index].text.trim().to_owned()
  if text == "" ||
    markdown_editor_opening_code_fence_marker(lines[index].text) is Some(_) ||
    !markdown_editor_is_setext_paragraph_candidate(lines[index].text) {
    return None
  }
  markdown_editor_setext_underline_level(lines[index + 1].text)
}

///|
fn markdown_editor_is_setext_paragraph_candidate(line : String) -> Bool {
  match parse_markdown(line) {
    [{ kind: MarkdownBlockKind::Paragraph, .. }] => true
    _ => false
  }
}

///|
fn markdown_editor_setext_underline_level(line : String) -> Int? {
  let text = line.trim().to_owned()
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let marker = chars[0]
  if marker != '=' && marker != '-' {
    return None
  }
  for ch in chars {
    if ch != marker {
      return None
    }
  }
  Some(if marker == '=' { 1 } else { 2 })
}

///|
fn markdown_editor_closing_code_fence(line : String, fence : String) -> Bool {
  let chars = line.to_array()
  let fence_chars = fence.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if fence_chars.length() < 3 || chars.length() < indent + fence_chars.length() {
    return false
  }
  for index in 0..<fence_chars.length() {
    if chars[indent + index] != fence_chars[index] {
      return false
    }
  }
  let mut index = indent + fence_chars.length()
  while index < chars.length() && chars[index] == '`' {
    index = index + 1
  }
  while index < chars.length() {
    if chars[index] != ' ' && chars[index] != '\t' {
      return false
    }
    index = index + 1
  }
  true
}

///|
fn markdown_editor_blocks_to_rich_text(
  blocks : Array[MarkdownEditorBlock],
) -> @core.RichTextDocument {
  let rich_blocks : Array[@core.RichTextBlock] = []
  let base = @core.FontSpec::new()
  for block in blocks {
    rich_blocks.push(markdown_editor_block_to_rich_text(block, base))
  }
  @core.RichTextDocument::new(blocks=rich_blocks)
}

///|
fn markdown_editor_block_to_rich_text(
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
) -> @core.RichTextBlock {
  let block = markdown_block_to_rich_text(editor_block.block, base)
  {
    ..block,
    runs: markdown_editor_runs_with_source_ranges(block.runs, editor_block),
    source_range: Some(markdown_core_range(editor_block.source_range)),
    content_range: Some(markdown_core_range(editor_block.content_range)),
  }
}

///|
fn markdown_editor_runs_with_source_ranges(
  runs : Array[@core.RichTextRun],
  editor_block : MarkdownEditorBlock,
) -> Array[@core.RichTextRun] {
  let mapped : Array[@core.RichTextRun] = []
  let mut search = 0
  let content = markdown_editor_block_source_content(editor_block)
  for run in runs {
    let length = markdown_editor_text_length(run.text)
    let start = markdown_editor_find_run_source_offset(
      content,
      run.text,
      search,
    )
    let end = start + length
    mapped.push({
      ..run,
      source_range: Some({
        start: editor_block.content_range.start + start,
        end: editor_block.content_range.start + end,
      }),
    })
    search = end
  }
  mapped
}

///|
fn markdown_editor_block_source_content(
  editor_block : MarkdownEditorBlock,
) -> String {
  let source = editor_block.source_range
  let content = editor_block.content_range
  let chars = markdown_editor_block_source_text(editor_block).to_array()
  let start = markdown_editor_clamp_int(
    content.start - source.start,
    0,
    chars.length(),
  )
  let end = markdown_editor_clamp_int(
    content.end - source.start,
    start,
    chars.length(),
  )
  String::from_array(chars[start:end])
}

///|
fn markdown_editor_block_source_text(
  editor_block : MarkdownEditorBlock,
) -> String {
  let prefix_padding = markdown_editor_block_source_prefix_padding(editor_block)
  match editor_block.block.kind {
    Heading(level) =>
      prefix_padding +
      markdown_editor_heading_source(level, editor_block.block.text)
    UnorderedListItem =>
      prefix_padding +
      "- " +
      markdown_editor_inline_source(editor_block.block.inlines)
    TaskListItem(checked) =>
      if checked {
        prefix_padding +
        "- [x] " +
        markdown_editor_inline_source(editor_block.block.inlines)
      } else {
        prefix_padding +
        "- [ ] " +
        markdown_editor_inline_source(editor_block.block.inlines)
      }
    OrderedListItem(number) =>
      prefix_padding +
      number.to_string() +
      ". " +
      markdown_editor_inline_source(editor_block.block.inlines)
    Blockquote =>
      prefix_padding +
      "> " +
      markdown_editor_inline_source(editor_block.block.inlines)
    Paragraph =>
      prefix_padding + markdown_editor_inline_source(editor_block.block.inlines)
    CodeBlock | HorizontalRule | Table => editor_block.block.text
  }
}

///|
fn markdown_editor_block_source_prefix_padding(
  editor_block : MarkdownEditorBlock,
) -> String {
  let marker_length = match editor_block.block.kind {
    Heading(level) => level + 1
    UnorderedListItem => 2
    TaskListItem(_) => 6
    OrderedListItem(number) => markdown_editor_digit_count(number) + 2
    Blockquote => 2
    Paragraph | CodeBlock | HorizontalRule | Table => 0
  }
  let padding_length = markdown_editor_max_int(
    0,
    editor_block.content_range.start -
    editor_block.source_range.start -
    marker_length,
  )
  let chars : Array[Char] = []
  for _ in 0..<padding_length {
    chars.push(' ')
  }
  String::from_array(chars)
}

///|
fn markdown_editor_inline_source(inlines : Array[MarkdownInline]) -> String {
  let text = ""
  let parts : Array[String] = []
  for inline in inlines {
    match inline.kind {
      Plain => parts.push(inline.text)
      Bold => parts.push("**" + inline.text + "**")
      Italic => parts.push("*" + inline.text + "*")
      Code => parts.push("`" + inline.text + "`")
      Strikethrough => parts.push("~~" + inline.text + "~~")
      Link =>
        parts.push(
          "[" + inline.text + "](" + markdown_editor_inline_target(inline) + ")",
        )
      Autolink => parts.push("<" + markdown_editor_inline_target(inline) + ">")
      Image =>
        parts.push(
          "![" +
          inline.text +
          "](" +
          markdown_editor_inline_target(inline) +
          ")",
        )
    }
  }
  ignore(text)
  markdown_join_lines([markdown_join_strings(parts)])
}

///|
fn markdown_editor_inline_target(inline : MarkdownInline) -> String {
  match inline.target {
    Some(target) => target
    None => inline.text
  }
}

///|
fn markdown_join_strings(parts : Array[String]) -> String {
  let chars : Array[Char] = []
  for part in parts {
    chars.append(part.to_array())
  }
  String::from_array(chars)
}

///|
fn markdown_editor_heading_source(level : Int, text : String) -> String {
  let marks : Array[Char] = []
  for _ in 0..<level {
    marks.push('#')
  }
  String::from_array(marks) + " " + text
}

///|
fn markdown_editor_find_run_source_offset(
  content : String,
  run_text : String,
  start : Int,
) -> Int {
  let content_chars = content.to_array()
  let run_chars = run_text.to_array()
  if run_chars.length() == 0 {
    return markdown_editor_clamp_int(start, 0, content_chars.length())
  }
  let mut index = markdown_editor_clamp_int(start, 0, content_chars.length())
  while index + run_chars.length() <= content_chars.length() {
    if markdown_editor_chars_match(content_chars, index, run_chars) {
      return index
    }
    index = index + 1
  }
  markdown_editor_clamp_int(start, 0, content_chars.length())
}

///|
fn markdown_editor_chars_match(
  content : Array[Char],
  start : Int,
  target : Array[Char],
) -> Bool {
  if start + target.length() > content.length() {
    return false
  }
  for index in 0..<target.length() {
    if content[start + index] != target[index] {
      return false
    }
  }
  true
}

///|
fn markdown_core_range(
  range : MarkdownSourceRange,
) -> @core.RichTextSourceRange {
  { start: range.start, end: range.end }
}

///|
fn markdown_editor_active_heading(
  blocks : Array[MarkdownEditorBlock],
) -> String {
  for block in blocks {
    match block.block.kind {
      Heading(_) => return block.block.text
      _ => ()
    }
  }
  "Untitled"
}

///|
fn markdown_editor_block_kind_label(kind : MarkdownBlockKind) -> String {
  match kind {
    Heading(level) => "Heading " + level.to_string()
    UnorderedListItem => "Bullet list"
    TaskListItem(_) => "Task list"
    OrderedListItem(_) => "Ordered list"
    Blockquote => "Quote"
    CodeBlock => "Code block"
    HorizontalRule => "Rule"
    Table => "Table"
    Paragraph => "Paragraph"
  }
}

///|
fn markdown_editor_content_range(
  line : MarkdownLine,
  kind : MarkdownBlockKind,
) -> MarkdownSourceRange {
  let offset = match kind {
    Heading(_)
    | UnorderedListItem
    | TaskListItem(_)
    | OrderedListItem(_)
    | Blockquote => markdown_editor_marker_prefix_length(line.text)
    Paragraph | CodeBlock | HorizontalRule | Table => 0
  }
  {
    start: markdown_editor_min_int(line.start + offset, line.end),
    end: line.end,
  }
}

///|
fn markdown_editor_lines(source : String) -> Array[MarkdownLine] {
  let lines : Array[MarkdownLine] = []
  let current : Array[Char] = []
  let mut start = 0
  let mut offset = 0
  for ch in source {
    if ch == '\n' {
      lines.push({ text: String::from_array(current), start, end: offset })
      current.clear()
      offset = offset + 1
      start = offset
    } else {
      current.push(ch)
      offset = offset + 1
    }
  }
  lines.push({ text: String::from_array(current), start, end: offset })
  lines
}

///|
fn markdown_editor_text_length(source : String) -> Int {
  source.to_array().length()
}

///|
fn markdown_editor_substring(source : String, start : Int, end : Int) -> String {
  let chars = source.to_array()
  let start = clamp_example_int(start, 0, chars.length())
  let end = clamp_example_int(end, start, chars.length())
  String::from_array(chars[start:end])
}

///|
fn markdown_editor_digit_count(number : Int) -> Int {
  let mut value = number
  let mut count = 1
  while value >= 10 {
    value = value / 10
    count = count + 1
  }
  count
}

///|
fn markdown_editor_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
