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
fn markdown_editor_insert_table_of_contents(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let toc = markdown_editor_table_of_contents_markdown(source)
  let range = markdown_editor_active_selection(selection.selection)
    .unwrap_or(@core.TextRange::new(start=selection.caret, end=selection.caret))
    .normalized()
  markdown_editor_replace_with_block(source, range, toc)
}

///|
fn markdown_editor_insert_front_matter(
  source : String,
) -> MarkdownEditorEditResult {
  let blocks = parse_markdown_editor_blocks(source)
  if blocks.length() > 0 && blocks[0].block.kind is FrontMatter {
    return {
      source,
      caret: blocks[0].content_range.end,
      selection: Some(
        @core.TextRange::new(
          start=blocks[0].content_range.start,
          end=blocks[0].content_range.end,
        ),
      ),
    }
  }
  let snippet = markdown_editor_command_snippet(InsertFrontMatter)
  let text = if source == "" { snippet } else { snippet + "\n\n" + source }
  { source: text, caret: markdown_editor_text_length(snippet), selection: None }
}

///|
fn markdown_editor_table_of_contents_markdown(source : String) -> String {
  let outline = MarkdownEditorSnapshot::parse(source).outline
  if outline.length() == 0 {
    return markdown_editor_command_snippet(InsertTableOfContents)
  }
  let rows : Array[String] = ["## Contents"]
  for item in outline {
    let title = if item.title.trim().to_owned() == "" {
      "Untitled"
    } else {
      item.title.trim().to_owned()
    }
    let indent = markdown_editor_toc_indent(item.level)
    rows.push(
      indent +
      "- [" +
      markdown_editor_toc_escape_link_text(title) +
      "](#" +
      markdown_editor_toc_slug(title) +
      ")",
    )
  }
  markdown_join_lines(rows)
}

///|
fn markdown_editor_replace_with_block(
  source : String,
  range : @core.TextRange,
  block : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let before = String::from_array(chars[:start])
  let after = String::from_array(chars[end:])
  let prefix = markdown_editor_block_insert_prefix(chars, start)
  let suffix = markdown_editor_block_insert_suffix(chars, end)
  let text = before + prefix + block + suffix + after
  let caret = markdown_editor_text_length(before + prefix + block)
  { source: text, caret, selection: None }
}

///|
fn markdown_editor_toc_indent(level : Int) -> String {
  let spaces : Array[Char] = []
  let count = markdown_editor_max_int(0, level - 1) * 2
  for _ in 0..<count {
    spaces.push(' ')
  }
  String::from_array(spaces)
}

///|
fn markdown_editor_toc_escape_link_text(text : String) -> String {
  let chars : Array[Char] = []
  for ch in text {
    if ch == '[' || ch == ']' || ch == '\\' {
      chars.push('\\')
    }
    chars.push(ch)
  }
  String::from_array(chars)
}

///|
fn markdown_editor_toc_slug(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_dash = false
  for ch in text.to_lower() {
    if markdown_editor_toc_slug_char(ch) {
      chars.push(ch)
      previous_dash = false
    } else if ch.is_ascii_whitespace() || ch == '-' {
      if !previous_dash && chars.length() > 0 {
        chars.push('-')
        previous_dash = true
      }
    }
  }
  while chars.length() > 0 && chars[chars.length() - 1] == '-' {
    ignore(chars.pop())
  }
  if chars.length() == 0 {
    "section"
  } else {
    String::from_array(chars)
  }
}

///|
fn markdown_editor_toc_slug_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_'
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
fn markdown_editor_toggle_reference_at_caret(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  if command == Image {
    match markdown_editor_image_context(source, selection) {
      Some(context) =>
        markdown_editor_unwrap_image_range(
          source,
          context.range,
          context.bounds,
        )
      None => markdown_editor_append_snippet(source, command)
    }
  } else {
    match markdown_editor_link_context(source, selection) {
      Some(context) =>
        markdown_editor_unwrap_link_range(source, context.range, context.bounds)
      None => markdown_editor_append_snippet(source, command)
    }
  }
}

///|
fn markdown_editor_set_reference_target(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
  target : String,
) -> MarkdownEditorEditResult {
  let active = markdown_editor_active_selection(selection.selection)
  let range = active
    .unwrap_or(@core.TextRange::new(start=selection.caret, end=selection.caret))
    .normalized()
  if command == SetImageTarget(target) {
    match markdown_editor_image_context(source, selection) {
      Some(context) =>
        return markdown_editor_replace_reference_target(
          source,
          context.range,
          context.bounds,
          target,
        )
      None =>
        match active {
          Some(_) =>
            return markdown_editor_wrap_image_range_with_target(
              source, range, target,
            )
          None => return markdown_editor_append_snippet(source, command)
        }
    }
  }
  match markdown_editor_link_context(source, selection) {
    Some(context) =>
      markdown_editor_replace_reference_target(
        source,
        context.range,
        context.bounds,
        target,
      )
    None =>
      match active {
        Some(_) =>
          markdown_editor_wrap_link_range_with_target(source, range, target)
        None => markdown_editor_append_snippet(source, command)
      }
  }
}

///|
