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
fn markdown_editor_toggle_inline_at_caret(
  source : String,
  caret : Int,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  let marker = markdown_editor_inline_marker(command)
  match markdown_editor_inline_marker_pair_at_caret(source, caret, marker) {
    Some(range) => markdown_editor_unwrap_range(source, range, marker)
    None => markdown_editor_append_snippet(source, command)
  }
}

///|
pub fn markdown_editor_inline_marker_pair_at_caret(
  source : String,
  caret : Int,
  marker : String,
) -> @core.TextRange? {
  let marker_length = markdown_editor_text_length(marker)
  if marker_length == 0 {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_find_inline_opening_marker(chars, caret, marker) {
    Some(open_start) =>
      match
        markdown_editor_find_inline_closing_marker(
          chars,
          open_start + marker_length,
          marker,
        ) {
        Some(close_start) =>
          if caret >= open_start + marker_length &&
            caret <= close_start &&
            markdown_editor_inline_marker_pair_supported(
              chars, open_start, marker_length, close_start, marker,
            ) {
            Some(
              @core.TextRange::new(
                start=open_start + marker_length,
                end=close_start,
              ),
            )
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
pub fn markdown_editor_range_has_inline_marker(
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
pub fn markdown_editor_inline_marker(command : MarkdownEditorCommand) -> String {
  match command {
    Bold => "**"
    Italic => "*"
    Code => "`"
    Strikethrough => "~~"
    _ => ""
  }
}

///|
fn markdown_editor_command_snippet(command : MarkdownEditorCommand) -> String {
  match command {
    Bold => "**bold text**"
    Italic => "*italic text*"
    Code => "`code`"
    Strikethrough => "~~old text~~"
    Link => "[link text](https://example.com)"
    Image => "![image alt](image.png)"
    SetLinkTarget(target) => "[link text](" + target + ")"
    SetImageTarget(target) => "![image alt](" + target + ")"
    SetCodeLanguage(target) => "```" + target + "\ncode block\n```"
    SetFootnoteText(text) => "[^note]: " + text
    SetHtmlBlockText(text) => text
    Paragraph => "Paragraph"
    Heading(level) =>
      markdown_editor_heading_marker(level) +
      " " +
      markdown_editor_heading_snippet_text(level)
    BulletList => "- List item"
    TaskList => "- [ ] Task item"
    OrderedList => "1. List item"
    Quote => "> Quote"
    CodeBlock => "```\ncode block\n```"
    HorizontalRule => "---"
    Table => "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    InsertTableOfContents => "## Contents\n\n- [Section](#section)"
    InsertFrontMatter => "---\ntitle: Untitled\ntags: []\n---"
    DuplicateBlock | MoveBlockUp | MoveBlockDown => ""
    InsertTableRow =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    InsertTableColumn =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    DeleteTableRow =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    DeleteTableColumn =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    SetTableColumnAlignment(_) =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
  }
}

///|
fn markdown_editor_heading_marker(level : Int) -> String {
  let count = markdown_editor_clamp_int(level, 1, 6)
  let chars : Array[Char] = []
  for _ in 0..<count {
    chars.push('#')
  }
  String::from_array(chars)
}

///|
fn markdown_editor_heading_snippet_text(level : Int) -> String {
  if level <= 1 {
    "Heading"
  } else if level == 2 {
    "Section"
  } else if level == 3 {
    "Detail"
  } else if level == 4 {
    "Subdetail"
  } else if level == 5 {
    "Note"
  } else {
    "Caption"
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
  for block in parse_markdown_editor_blocks(source) {
    match block.block.kind {
      TaskListItem(checked) =>
        if content_offset == block.content_range.start {
          return markdown_editor_toggle_task_block(source, block, checked)
        }
      _ => ()
    }
  }
  None
}

///|
pub fn markdown_editor_toggle_current_task(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult? {
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    match block.block.kind {
      TaskListItem(checked) =>
        if caret >= block.source_range.start && caret <= block.source_range.end {
          return markdown_editor_toggle_task_block(source, block, checked)
        }
      _ => ()
    }
  }
  None
}

///|
fn markdown_editor_toggle_task_block(
  source : String,
  block : MarkdownEditorBlock,
  checked : Bool,
) -> MarkdownEditorEditResult? {
  let chars = source.to_array()
  let marker_index = block.content_range.start - 3
  if marker_index < 0 || marker_index >= chars.length() {
    return None
  }
  let next = if checked { ' ' } else { 'x' }
  let text = String::from_array(chars[:marker_index]) +
    String::from_array([next]) +
    String::from_array(chars[marker_index + 1:])
  Some({ source: text, caret: block.content_range.start, selection: None })
}

///|
