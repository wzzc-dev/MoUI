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
  match markdown_editor_setext_block_at_selection(source, selection) {
    Some(block) =>
      match command {
        Paragraph
        | Heading(_)
        | BulletList
        | TaskList
        | OrderedList
        | Quote
        | HorizontalRule
        | Table =>
          return markdown_editor_transform_setext_block(
            source, command, selection, block,
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
  let parts = markdown_editor_line_block_parts(line)
  if command == Paragraph {
    let replacement = markdown_editor_paragraph_line_text(line, parts)
    let next_source = String::from_array(chars[:range.start]) +
      replacement +
      String::from_array(chars[range.end:])
    let paragraph_offset = if markdown_editor_line_block_parts_has_inner_marker(
        parts,
      ) &&
      markdown_editor_block_command_context_has_quote(parts.context_prefix) {
      markdown_editor_text_length(parts.context_prefix) +
      markdown_editor_caret_offset_in_line_block_parts(
        parts,
        selection.caret - range.start,
      )
    } else {
      markdown_editor_caret_offset_in_stripped_line(
        line,
        selection.caret - range.start,
      )
    }
    let next_caret = range.start + paragraph_offset
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
  } else if markdown_editor_block_command_context_has_quote(
      parts.context_prefix,
    ) &&
    (
      command == BulletList ||
      command == TaskList ||
      command == OrderedList ||
      command is Heading(_)
    ) {
    let has_same_marker = markdown_editor_line_has_same_block_marker_after_context(
      line,
      command,
      parts.context_prefix,
    )
    let marker = if has_same_marker { "" } else { prefix }
    let replacement = parts.context_prefix + marker + parts.content
    let next_source = String::from_array(chars[:range.start]) +
      replacement +
      String::from_array(chars[range.end:])
    let next_caret = range.start +
      markdown_editor_text_length(parts.context_prefix) +
      markdown_editor_text_length(marker) +
      markdown_editor_caret_offset_in_line_block_parts(
        parts,
        selection.caret - range.start,
      )
    { source: next_source, caret: next_caret, selection: None }
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
fn markdown_editor_setext_block_at_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlock? {
  let anchor = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Heading(_)) ||
      anchor < block.source_range.start ||
      anchor > block.content_range.end ||
      block.source_range.end <= block.content_range.end {
      continue
    }
    return Some(block)
  }
  None
}

///|
fn markdown_editor_transform_setext_block(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection,
  block : MarkdownEditorBlock,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let text = block.block.text
  let replacement = markdown_editor_setext_block_replacement(text, command)
  let next_source = String::from_array(chars[:block.source_range.start]) +
    replacement +
    String::from_array(chars[block.source_range.end:])
  let caret = if command == Table {
    block.source_range.start + 2
  } else if command == HorizontalRule {
    block.source_range.start + 3
  } else {
    let offset = markdown_editor_clamp_int(
      selection.caret - block.content_range.start,
      0,
      markdown_editor_text_length(text),
    )
    block.source_range.start +
    markdown_editor_text_length(replacement) -
    markdown_editor_text_length(text) +
    offset
  }
  { source: next_source, caret, selection: None }
}

///|
fn markdown_editor_setext_block_replacement(
  text : String,
  command : MarkdownEditorCommand,
) -> String {
  match command {
    Paragraph => text
    Heading(level) =>
      markdown_editor_heading_marker(level) +
      " " +
      markdown_editor_setext_atx_heading_text(text)
    BulletList | TaskList | OrderedList | Quote =>
      markdown_editor_transform_line_segment(text, command)
    HorizontalRule => "---"
    Table => markdown_editor_command_snippet(Table)
    _ => text
  }
}

///|
fn markdown_editor_setext_atx_heading_text(text : String) -> String {
  let parts : Array[String] = []
  for line in markdown_split_lines(text) {
    let trimmed = line.trim().to_owned()
    if trimmed != "" {
      parts.push(trimmed)
    }
  }
  parts.join(" ")
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
  let ordered_contexts : Array[MarkdownEditorOrderedRenumberContext] = []
  for line in lines {
    let parts = markdown_editor_line_block_parts(line.text.to_owned())
    let content_is_blank = parts.content.trim().to_owned() == ""
    match command {
      Paragraph =>
        transformed.push(
          markdown_editor_paragraph_line_text(line.text.to_owned(), parts),
        )
      BulletList =>
        if content_is_blank {
          transformed.push(markdown_editor_block_command_blank_line(parts))
        } else {
          transformed.push(parts.context_prefix + "- " + parts.content)
        }
      TaskList =>
        if content_is_blank {
          transformed.push(markdown_editor_block_command_blank_line(parts))
        } else {
          transformed.push(parts.context_prefix + "- [ ] " + parts.content)
        }
      OrderedList =>
        if content_is_blank {
          transformed.push(markdown_editor_block_command_blank_line(parts))
        } else {
          let number = markdown_editor_next_selected_ordered_number(
            ordered_contexts,
            parts.context_prefix,
          )
          transformed.push(
            parts.context_prefix + number.to_string() + ". " + parts.content,
          )
        }
      Quote =>
        if markdown_editor_block_command_context_has_quote(parts.context_prefix) {
          transformed.push(line.text.to_owned())
        } else {
          transformed.push(parts.context_prefix + "> " + parts.content)
        }
      _ => transformed.push(line.text.to_owned())
    }
  }
  markdown_join_lines(transformed)
}

///|
priv struct MarkdownEditorLineBlockParts {
  context_prefix : String
  content_start : Int
  content : String
}

///|
fn markdown_editor_line_block_parts(
  line : String,
) -> MarkdownEditorLineBlockParts {
  let chars = line.to_array()
  let context_length = markdown_editor_block_command_context_prefix_length(line)
  let marker_length = markdown_editor_marker_prefix_length_after_context(
    line, context_length,
  )
  let content_start = if marker_length > 0 {
    marker_length
  } else {
    context_length
  }
  {
    context_prefix: String::from_array(chars[:context_length]),
    content_start,
    content: String::from_array(chars[content_start:]),
  }
}

///|
fn markdown_editor_caret_offset_in_line_block_parts(
  parts : MarkdownEditorLineBlockParts,
  caret_offset : Int,
) -> Int {
  markdown_editor_clamp_int(
    caret_offset - parts.content_start,
    0,
    markdown_editor_text_length(parts.content),
  )
}

///|
fn markdown_editor_paragraph_line_text(
  line : String,
  parts : MarkdownEditorLineBlockParts,
) -> String {
  if markdown_editor_line_block_parts_has_inner_marker(parts) &&
    markdown_editor_block_command_context_has_quote(parts.context_prefix) {
    parts.context_prefix + parts.content
  } else {
    markdown_editor_strip_block_marker(line)
  }
}

///|
fn markdown_editor_line_block_parts_has_inner_marker(
  parts : MarkdownEditorLineBlockParts,
) -> Bool {
  parts.content_start > markdown_editor_text_length(parts.context_prefix)
}

///|
fn markdown_editor_block_command_blank_line(
  parts : MarkdownEditorLineBlockParts,
) -> String {
  if markdown_editor_block_command_context_has_quote(parts.context_prefix) {
    parts.context_prefix
  } else {
    ""
  }
}

///|
fn markdown_editor_block_command_context_has_quote(prefix : String) -> Bool {
  let chars = prefix.to_array()
  for index in 0..<chars.length() {
    if chars[index] == '>' {
      return true
    }
  }
  false
}

///|
fn markdown_editor_line_has_same_block_marker_after_context(
  line : String,
  command : MarkdownEditorCommand,
  context_prefix : String,
) -> Bool {
  let chars = line.to_array()
  let context_length = markdown_editor_text_length(context_prefix)
  markdown_editor_line_has_same_block_marker(
    String::from_array(chars[context_length:]),
    command,
  )
}

///|
fn markdown_editor_block_command_context_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let mut index = 0
  let mut scanning = true
  while scanning {
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index + 1 < chars.length() &&
      chars[index] == '>' &&
      chars[index + 1] == ' ' {
      index = index + 2
    } else {
      scanning = false
    }
  }
  index
}

///|
fn markdown_editor_marker_prefix_length_after_context(
  line : String,
  context_length : Int,
) -> Int {
  let chars = line.to_array()
  let nested_marker_length = markdown_editor_marker_prefix_length(
    String::from_array(chars[context_length:]),
  )
  if nested_marker_length > 0 {
    context_length + nested_marker_length
  } else {
    0
  }
}

///|
fn markdown_editor_next_selected_ordered_number(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  context_prefix : String,
) -> Int {
  let indent = markdown_editor_text_length(context_prefix)
  markdown_editor_trim_ordered_renumber_contexts(contexts, indent)
  if contexts.length() > 0 &&
    contexts[contexts.length() - 1].indent == indent &&
    contexts[contexts.length() - 1].context_prefix == context_prefix {
    let context = contexts[contexts.length() - 1]
    ignore(contexts.pop())
    contexts.push({ indent, context_prefix, expected: context.expected + 1 })
    context.expected
  } else {
    while contexts.length() > 0 &&
          contexts[contexts.length() - 1].indent >= indent {
      ignore(contexts.pop())
    }
    contexts.push({ indent, context_prefix, expected: 2 })
    1
  }
}

///|
priv struct MarkdownEditorBlockPosition {
  block : MarkdownEditorBlock
  index : Int
}

///|
priv struct MarkdownEditorBlockGroup {
  start_index : Int
  end_index : Int
  source_start : Int
  source_end : Int
}

///|
fn markdown_editor_noop_result(
  source : String,
  selection : MarkdownEditorSelection?,
) -> MarkdownEditorEditResult {
  match selection {
    Some(selection) =>
      { source, caret: selection.caret, selection: selection.selection }
    None =>
      { source, caret: markdown_editor_text_length(source), selection: None }
  }
}

///|
fn markdown_editor_duplicate_current_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  match markdown_editor_active_edit_group(source, selection) {
    Some(group) => {
      let blocks = parse_markdown_editor_blocks(source)
      let chars = source.to_array()
      let block_text = String::from_array(
        chars[group.source_start:group.source_end],
      )
      if block_text == "" {
        return markdown_editor_noop_result(source, Some(selection))
      }
      let separator = markdown_editor_duplicate_group_separator(blocks, group)
      let duplicate_start = group.source_end +
        markdown_editor_text_length(separator)
      let next_source = String::from_array(chars[:group.source_end]) +
        separator +
        block_text +
        String::from_array(chars[group.source_end:])
      {
        source: next_source,
        caret: markdown_editor_map_offset_to_group(
          selection.caret,
          group,
          duplicate_start,
        ),
        selection: markdown_editor_map_selection_to_group(
          selection.selection,
          group,
          duplicate_start,
        ),
      }
    }
    None => markdown_editor_noop_result(source, Some(selection))
  }
}

///|
fn markdown_editor_duplicate_group_separator(
  blocks : Array[MarkdownEditorBlock],
  group : MarkdownEditorBlockGroup,
) -> String {
  if group.start_index < 0 ||
    group.end_index >= blocks.length() ||
    group.start_index > group.end_index {
    return "\n"
  }
  let first = blocks[group.start_index]
  let last = blocks[group.end_index]
  if markdown_editor_duplicate_kind_needs_blank_separator(first.block.kind) ||
    markdown_editor_duplicate_kind_needs_blank_separator(last.block.kind) {
    "\n\n"
  } else {
    "\n"
  }
}

///|
fn markdown_editor_duplicate_kind_needs_blank_separator(
  kind : MarkdownBlockKind,
) -> Bool {
  match kind {
    Paragraph | Table => true
    _ => false
  }
}

///|
fn markdown_editor_move_current_block(
  source : String,
  selection : MarkdownEditorSelection,
  up~ : Bool,
) -> MarkdownEditorEditResult {
  match markdown_editor_active_edit_group(source, selection) {
    Some(group) => {
      let blocks = parse_markdown_editor_blocks(source)
      let chars = source.to_array()
      if up {
        match markdown_editor_previous_edit_block(blocks, group.start_index) {
          Some(previous) => {
            let previous_text = String::from_array(
              chars[previous.source_range.start:previous.source_range.end],
            )
            let group_text = String::from_array(
              chars[group.source_start:group.source_end],
            )
            let gap = String::from_array(
              chars[previous.source_range.end:group.source_start],
            )
            let next_source = String::from_array(
                chars[:previous.source_range.start],
              ) +
              group_text +
              gap +
              previous_text +
              String::from_array(chars[group.source_end:])
            markdown_editor_moved_group_result(
              next_source,
              selection,
              group,
              new_start=previous.source_range.start,
            )
          }
          None => markdown_editor_noop_result(source, Some(selection))
        }
      } else {
        match markdown_editor_next_edit_block(blocks, group.end_index) {
          Some(next) => {
            let group_text = String::from_array(
              chars[group.source_start:group.source_end],
            )
            let next_text = String::from_array(
              chars[next.source_range.start:next.source_range.end],
            )
            let gap = String::from_array(
              chars[group.source_end:next.source_range.start],
            )
            let new_start = group.source_start +
              markdown_editor_text_length(next_text) +
              markdown_editor_text_length(gap)
            let next_source = String::from_array(chars[:group.source_start]) +
              next_text +
              gap +
              group_text +
              String::from_array(chars[next.source_range.end:])
            markdown_editor_moved_group_result(
              next_source,
              selection,
              group,
              new_start~,
            )
          }
          None => markdown_editor_noop_result(source, Some(selection))
        }
      }
    }
    None => markdown_editor_noop_result(source, Some(selection))
  }
}

///|
fn markdown_editor_moved_group_result(
  source : String,
  selection : MarkdownEditorSelection,
  group : MarkdownEditorBlockGroup,
  new_start~ : Int,
) -> MarkdownEditorEditResult {
  {
    source,
    caret: markdown_editor_map_offset_to_group(
      selection.caret,
      group,
      new_start,
    ),
    selection: markdown_editor_map_selection_to_group(
      selection.selection,
      group,
      new_start,
    ),
  }
}

///|
fn markdown_editor_active_edit_group(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlockGroup? {
  let blocks = parse_markdown_editor_blocks(source)
  match markdown_editor_active_selection(selection.selection) {
    Some(range) => {
      let normalized = range.normalized()
      let mut start_index = -1
      let mut end_index = -1
      for index in 0..<blocks.length() {
        let block = blocks[index]
        if markdown_editor_empty_line_block_for_edit(block) {
          continue
        }
        if normalized.start < block.source_range.end &&
          normalized.end > block.source_range.start {
          if start_index < 0 {
            start_index = index
          }
          end_index = index
        }
      }
      if start_index >= 0 && end_index >= start_index {
        return Some({
          start_index,
          end_index,
          source_start: blocks[start_index].source_range.start,
          source_end: blocks[end_index].source_range.end,
        })
      }
    }
    None => ()
  }
  match
    markdown_editor_active_edit_block_from_blocks(blocks, source, selection) {
    Some(current) =>
      Some({
        start_index: current.index,
        end_index: current.index,
        source_start: current.block.source_range.start,
        source_end: current.block.source_range.end,
      })
    None => None
  }
}

///|
fn markdown_editor_active_edit_block_from_blocks(
  blocks : Array[MarkdownEditorBlock],
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlockPosition? {
  let chars = source.to_array()
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(anchor, 0, chars.length())
  for index in 0..<blocks.length() {
    let block = blocks[index]
    if markdown_editor_empty_line_block_for_edit(block) {
      continue
    }
    if anchor >= block.source_range.start && anchor <= block.source_range.end {
      return Some({ block, index })
    }
  }
  None
}

///|
fn markdown_editor_previous_edit_block(
  blocks : Array[MarkdownEditorBlock],
  index : Int,
) -> MarkdownEditorBlock? {
  let mut candidate = index - 1
  while candidate >= 0 {
    let block = blocks[candidate]
    if !markdown_editor_empty_line_block_for_edit(block) {
      return Some(block)
    }
    candidate = candidate - 1
  }
  None
}

///|
fn markdown_editor_next_edit_block(
  blocks : Array[MarkdownEditorBlock],
  index : Int,
) -> MarkdownEditorBlock? {
  let mut candidate = index + 1
  while candidate < blocks.length() {
    let block = blocks[candidate]
    if !markdown_editor_empty_line_block_for_edit(block) {
      return Some(block)
    }
    candidate = candidate + 1
  }
  None
}

///|
fn markdown_editor_empty_line_block_for_edit(
  block : MarkdownEditorBlock,
) -> Bool {
  block.source_range.start == block.source_range.end && block.block.text == ""
}

///|
fn markdown_editor_map_offset_to_group(
  offset : Int,
  group : MarkdownEditorBlockGroup,
  group_start : Int,
) -> Int {
  group_start +
  markdown_editor_clamp_int(
    offset - group.source_start,
    0,
    group.source_end - group.source_start,
  )
}

///|
fn markdown_editor_map_selection_to_group(
  selection : @core.TextRange?,
  group : MarkdownEditorBlockGroup,
  group_start : Int,
) -> @core.TextRange? {
  match markdown_editor_active_selection(selection) {
    Some(range) =>
      if range.start >= group.source_start && range.end <= group.source_end {
        Some(
          @core.TextRange::new(
            start=markdown_editor_map_offset_to_group(
              range.start,
              group,
              group_start,
            ),
            end=markdown_editor_map_offset_to_group(
              range.end,
              group,
              group_start,
            ),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn markdown_editor_block_prefix(command : MarkdownEditorCommand) -> String {
  match command {
    Paragraph => ""
    Heading(level) => markdown_editor_heading_marker(level) + " "
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
fn markdown_editor_marker_prefix_length(line : StringView) -> Int {
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
    (chars[index] == '.' || chars[index] == ')') &&
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
