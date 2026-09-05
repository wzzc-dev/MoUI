///|
fn markdown_editor_complete_code_fence_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
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
fn markdown_editor_complete_quoted_code_fence_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
  if caret != range.end {
    return None
  }
  let nested = match markdown_editor_quoted_code_nested_text(line) {
    Some(nested) => nested
    None => return None
  }
  let fence = match markdown_editor_opening_code_fence_marker(nested) {
    Some(fence) => fence.marker
    None => return None
  }
  let content_prefix = match markdown_editor_quoted_code_content_prefix(line) {
    Some(prefix) => prefix
    None => return None
  }
  let insert = "\n" + content_prefix + "\n" + content_prefix + fence
  let text = String::from_array(chars[:caret]) +
    insert +
    String::from_array(chars[caret:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=caret + 1 + markdown_editor_text_length(content_prefix),
    ),
  )
}

///|
fn markdown_editor_exit_empty_code_block_on_enter(
  source : String,
  block : MarkdownEditorBlock,
  caret : Int,
) -> RichTextInputTransform? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current_line = markdown_editor_current_line_range(source, {
    caret,
    selection: None,
  })
  let line = String::from_array(chars[current_line.start:current_line.end])
  if line.trim().to_owned() != "" {
    return None
  }
  if current_line.start < block.content_range.start ||
    current_line.end > block.content_range.end {
    return None
  }
  let opening_line_end = markdown_editor_next_line_end(
    chars,
    block.source_range.start,
  )
  let opening_line = String::from_array(
    chars[block.source_range.start:opening_line_end],
  )
  let fence = match markdown_editor_opening_code_fence_marker(opening_line) {
    Some(fence) => fence.marker
    None => return None
  }
  let closing_start = current_line.end + 1
  if closing_start >= chars.length() || closing_start > block.source_range.end {
    return None
  }
  let closing_end = markdown_editor_next_line_end(chars, closing_start)
  let closing_line = String::from_array(chars[closing_start:closing_end])
  if !markdown_editor_closing_code_fence(closing_line, fence) {
    return None
  }
  let exit_indent = markdown_editor_line_indent_prefix(closing_line)
  if closing_end >= chars.length() {
    let insert = "\n" + exit_indent
    Some(
      markdown_editor_transform_result(
        text=source + insert,
        caret=closing_end + markdown_editor_text_length(insert),
      ),
    )
  } else {
    let after_close = closing_end + 1
    if after_close >= chars.length() {
      if exit_indent == "" {
        Some(markdown_editor_transform_result(text=source, caret=after_close))
      } else {
        Some(
          markdown_editor_transform_result(
            text=source + exit_indent,
            caret=after_close + markdown_editor_text_length(exit_indent),
          ),
        )
      }
    } else {
      let insert = exit_indent + "\n"
      Some(
        markdown_editor_transform_result(
          text=String::from_array(chars[:after_close]) +
            insert +
            String::from_array(chars[after_close:]),
          caret=after_close + markdown_editor_text_length(exit_indent),
        ),
      )
    }
  }
}

///|
fn markdown_editor_quoted_code_block_at_content_offset(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> MarkdownEditorQuotedCodeBlock? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let caret = markdown_editor_clamp_int(
    caret,
    0,
    markdown_editor_text_length(source),
  )
  match
    markdown_editor_containing_quoted_code_block(
      source,
      ({ caret, selection } : MarkdownEditorSelection),
    ) {
    Some(block) =>
      if caret >= block.content_range.start && caret <= block.content_range.end {
        Some(block)
      } else {
        None
      }
    None => None
  }
}

///|
fn markdown_editor_any_code_block_at_content_offset(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Bool {
  markdown_editor_code_block_at_content_offset(source, caret, selection)
  is Some(_) ||
  markdown_editor_quoted_code_block_at_content_offset(source, caret, selection)
  is Some(_)
}

///|
fn markdown_editor_exit_empty_quoted_code_block_on_enter(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
  caret : Int,
) -> RichTextInputTransform? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current_line = markdown_editor_current_line_range(source, {
    caret,
    selection: None,
  })
  let line = String::from_array(chars[current_line.start:current_line.end])
  let nested = match markdown_editor_quoted_code_nested_text(line) {
    Some(nested) => nested
    None => return None
  }
  if nested.trim().to_owned() != "" {
    return None
  }
  if current_line.start < block.content_range.start ||
    current_line.end > block.content_range.end {
    return None
  }
  let opening_line_end = markdown_editor_next_line_end(
    chars,
    block.source_range.start,
  )
  let opening_line = String::from_array(
    chars[block.source_range.start:opening_line_end],
  )
  let opening = match markdown_editor_quoted_code_fence_opening(opening_line) {
    Some(opening) => opening
    None => return None
  }
  let closing_start = current_line.end + 1
  if closing_start >= chars.length() || closing_start > block.source_range.end {
    return None
  }
  let closing_end = markdown_editor_next_line_end(chars, closing_start)
  let closing_line = String::from_array(chars[closing_start:closing_end])
  if !markdown_editor_quoted_code_fence_closing(closing_line, opening) {
    return None
  }
  let exit_indent = match
    markdown_editor_quoted_code_content_prefix(closing_line) {
    Some(prefix) => prefix
    None => opening.quote_prefix
  }
  if closing_end >= chars.length() {
    let insert = "\n" + exit_indent
    Some(
      markdown_editor_transform_result(
        text=source + insert,
        caret=closing_end + markdown_editor_text_length(insert),
      ),
    )
  } else {
    let after_close = closing_end + 1
    if after_close >= chars.length() {
      Some(
        markdown_editor_transform_result(
          text=source + exit_indent,
          caret=after_close + markdown_editor_text_length(exit_indent),
        ),
      )
    } else {
      let insert = exit_indent + "\n"
      Some(
        markdown_editor_transform_result(
          text=String::from_array(chars[:after_close]) +
            insert +
            String::from_array(chars[after_close:]),
          caret=after_close + markdown_editor_text_length(exit_indent),
        ),
      )
    }
  }
}

///|
fn markdown_editor_quoted_code_block_enter(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
  caret : Int,
) -> RichTextInputTransform {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current_line = markdown_editor_current_line_range(source, {
    caret,
    selection: None,
  })
  let line = String::from_array(chars[current_line.start:current_line.end])
  let prefix = match markdown_editor_quoted_code_content_prefix(line) {
    Some(prefix) => prefix
    None =>
      markdown_editor_quoted_code_block_opening_content_prefix(source, block)
  }
  let insert = "\n" + prefix
  markdown_editor_transform_result(
    text=String::from_array(chars[:caret]) +
      insert +
      String::from_array(chars[caret:]),
    caret=caret + markdown_editor_text_length(insert),
  )
}

///|
fn markdown_editor_quoted_code_block_opening_content_prefix(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
) -> String {
  let chars = source.to_array()
  let opening_line_end = markdown_editor_next_line_end(
    chars,
    block.source_range.start,
  )
  let opening_line = String::from_array(
    chars[block.source_range.start:opening_line_end],
  )
  match markdown_editor_quoted_code_content_prefix(opening_line) {
    Some(prefix) => prefix
    None => ""
  }
}

///|
fn markdown_editor_quoted_code_nested_text(line : String) -> String? {
  let quote_prefix = markdown_editor_quote_context_prefix(line)
  if quote_prefix == "" {
    return None
  }
  Some(
    markdown_editor_substring(
      line,
      markdown_editor_text_length(quote_prefix),
      markdown_editor_text_length(line),
    ),
  )
}

///|
fn markdown_editor_quoted_code_content_prefix(line : String) -> String? {
  let quote_prefix = markdown_editor_quote_context_prefix(line)
  if quote_prefix == "" {
    return None
  }
  let nested = markdown_editor_substring(
    line,
    markdown_editor_text_length(quote_prefix),
    markdown_editor_text_length(line),
  )
  Some(quote_prefix + markdown_editor_line_indent_prefix(nested))
}

///|
fn markdown_editor_opening_code_fence_marker(
  line : StringView,
) -> MarkdownCodeFenceInfo? {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if !markdown_editor_code_fence_indent_allowed(chars, indent) ||
    chars.length() < indent + 3 {
    return None
  }
  let fence_char = chars[indent]
  if (fence_char != '`' && fence_char != '~') ||
    chars[indent + 1] != fence_char ||
    chars[indent + 2] != fence_char {
    return None
  }
  let mut fence_end = indent + 3
  while fence_end < chars.length() && chars[fence_end] == fence_char {
    fence_end = fence_end + 1
  }
  for index in fence_end..<chars.length() {
    if fence_char == '`' && chars[index] == fence_char {
      return None
    }
  }
  Some({
    marker: String::from_array(chars[indent:fence_end]),
    info: markdown_code_fence_info(chars, fence_end),
  })
}

///|
fn markdown_editor_code_fence_indent_allowed(
  chars : Array[Char],
  indent : Int,
) -> Bool {
  if indent > 3 {
    return false
  }
  for index in 0..<indent {
    if chars[index] == '\t' {
      return false
    }
  }
  true
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
