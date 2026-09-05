///|
fn markdown_editor_set_code_language(
  source : String,
  selection : MarkdownEditorSelection,
  language : String,
) -> MarkdownEditorEditResult {
  match markdown_editor_code_block_at_selection(source, selection) {
    Some(block) =>
      markdown_editor_replace_code_language(source, selection, block, language)
    None => markdown_editor_append_snippet(source, SetCodeLanguage(language))
  }
}

///|
fn markdown_editor_set_html_block_text(
  source : String,
  selection : MarkdownEditorSelection,
  text : String,
) -> MarkdownEditorEditResult {
  match markdown_editor_html_block_at_selection(source, selection) {
    Some(block) =>
      markdown_editor_replace_html_block_text(source, selection, block, text)
    None => markdown_editor_append_snippet(source, SetHtmlBlockText(text))
  }
}

///|
fn markdown_editor_replace_html_block_text(
  source : String,
  selection : MarkdownEditorSelection,
  block : MarkdownEditorBlock,
  text : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let next_source = String::from_array(chars[:block.source_range.start]) +
    text +
    String::from_array(chars[block.source_range.end:])
  let caret = block.source_range.start + markdown_editor_text_length(text)
  { source: next_source, caret, selection: selection.selection }
}

///|
fn markdown_editor_replace_code_language(
  source : String,
  selection : MarkdownEditorSelection,
  block : MarkdownEditorBlock,
  language : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let marker_end = markdown_editor_code_fence_marker_end(source, block)
  let language = language.trim().to_owned()
  let text = String::from_array(chars[:marker_end]) +
    language +
    String::from_array(chars[block.content_range.start - 1:])
  let delta = markdown_editor_text_length(language) -
    (block.content_range.start - 1 - marker_end)
  let caret = if selection.caret >= block.content_range.start {
    selection.caret + delta
  } else {
    selection.caret
  }
  { source: text, caret, selection: selection.selection }
}

///|
fn markdown_editor_code_fence_marker_end(
  source : String,
  block : MarkdownEditorBlock,
) -> Int {
  let chars = source.to_array()
  let mut index = block.source_range.start
  while index < chars.length() && chars[index] != '`' {
    index = index + 1
  }
  while index < chars.length() && chars[index] == '`' {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_toggle_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if source == "" {
    return markdown_editor_append_snippet(source, CodeBlock)
  }
  match markdown_editor_containing_quoted_code_block(source, selection) {
    Some(block) =>
      return markdown_editor_unwrap_quoted_code_block(source, block, selection)
    None => ()
  }
  match markdown_editor_containing_code_block(source, selection) {
    Some(block) => markdown_editor_unwrap_code_block(source, block, selection)
    None => markdown_editor_wrap_lines_in_code_block(source, selection)
  }
}

///|
priv struct MarkdownEditorQuotedCodeBlock {
  source_range : MarkdownSourceRange
  content_range : MarkdownSourceRange
}

///|
priv struct MarkdownEditorQuotedCodeFence {
  quote_prefix : String
  fence : String
}

///|
fn markdown_editor_containing_quoted_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorQuotedCodeBlock? {
  let lines = markdown_editor_lines(source)
  if lines.length() < 2 {
    return None
  }
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  let anchor_line = markdown_editor_line_index_at_offset(lines, anchor)
  let mut open_index = anchor_line
  while open_index >= 0 {
    match
      markdown_editor_quoted_code_fence_opening(
        lines[open_index].text.to_owned(),
      ) {
      Some(opening) =>
        for close_index in (open_index + 1)..<lines.length() {
          if markdown_editor_quoted_code_fence_closing(
              lines[close_index].text.to_owned(),
              opening,
            ) {
            if anchor >= lines[open_index].start &&
              anchor <= lines[close_index].end {
              let content_start = if close_index > open_index + 1 {
                lines[open_index + 1].start
              } else {
                lines[close_index].start
              }
              let content_end = if close_index > open_index + 1 {
                lines[close_index - 1].end
              } else {
                lines[close_index].start
              }
              return Some({
                source_range: {
                  start: lines[open_index].start,
                  end: lines[close_index].end,
                },
                content_range: { start: content_start, end: content_end },
              })
            }
            break
          }
        }
      None => ()
    }
    if open_index == 0 {
      break
    }
    open_index = open_index - 1
  }
  None
}

///|
fn markdown_editor_line_index_at_offset(
  lines : Array[MarkdownLine],
  offset : Int,
) -> Int {
  let mut result = 0
  for index in 0..<lines.length() {
    if offset >= lines[index].start && offset <= lines[index].end {
      return index
    }
    if offset > lines[index].end {
      result = index
    }
  }
  result
}

///|
fn markdown_editor_quoted_code_fence_opening(
  line : String,
) -> MarkdownEditorQuotedCodeFence? {
  let quote_prefix = markdown_editor_quote_context_prefix(line)
  if quote_prefix == "" {
    return None
  }
  let nested = markdown_editor_substring(
    line,
    markdown_editor_text_length(quote_prefix),
    markdown_editor_text_length(line),
  )
  match markdown_editor_opening_code_fence_marker(nested) {
    Some(fence) => Some({ quote_prefix, fence: fence.marker })
    None => None
  }
}

///|
fn markdown_editor_quoted_code_fence_closing(
  line : String,
  opening : MarkdownEditorQuotedCodeFence,
) -> Bool {
  let chars = line.to_array()
  if !markdown_editor_source_has_marker(chars, 0, opening.quote_prefix) {
    return false
  }
  let nested = markdown_editor_substring(
    line,
    markdown_editor_text_length(opening.quote_prefix),
    markdown_editor_text_length(line),
  )
  markdown_editor_closing_code_fence(nested, opening.fence)
}

///|
fn markdown_editor_unwrap_quoted_code_block(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let text = String::from_array(chars[:block.source_range.start]) +
    String::from_array(chars[block.content_range.start:block.content_range.end]) +
    String::from_array(chars[block.source_range.end:])
  let removed_before_content = block.content_range.start -
    block.source_range.start
  let removed_total = removed_before_content +
    block.source_range.end -
    block.content_range.end
  let caret = markdown_editor_unwrapped_quoted_code_offset(
    selection.caret,
    block,
    removed_before_content,
    removed_total,
  )
  let next_selection = match
    markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      Some(
        @core.TextRange::new(
          start=markdown_editor_unwrapped_quoted_code_offset(
            range.start,
            block,
            removed_before_content,
            removed_total,
          ),
          end=markdown_editor_unwrapped_quoted_code_offset(
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
fn markdown_editor_unwrapped_quoted_code_offset(
  offset : Int,
  block : MarkdownEditorQuotedCodeBlock,
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
    block.content_range.start,
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
  let quote_prefix = markdown_editor_code_block_quote_prefix(selected)
  let prefix = quote_prefix + "```\n"
  let suffix = "\n" + quote_prefix + "```"
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
fn markdown_editor_code_block_quote_prefix(selected : String) -> String {
  let lines = markdown_editor_lines(selected)
  if lines.length() == 0 {
    return ""
  }
  let prefix = markdown_editor_quote_context_prefix(lines[0].text.to_owned())
  if prefix == "" {
    return ""
  }
  for line in lines {
    let text = line.text
    if text.trim().to_owned() == "" {
      continue
    }
    let line_chars = text.to_array()
    if !markdown_editor_source_has_marker(line_chars, 0, prefix) {
      return ""
    }
  }
  prefix
}

///|
