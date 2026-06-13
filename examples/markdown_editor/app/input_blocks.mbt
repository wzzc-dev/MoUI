///|
fn markdown_editor_complete_rule_on_space(
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
  let line = String::from_array(chars[range.start:range.end])
  markdown_editor_complete_rule_on_enter(chars, range, line, caret)
}

///|
fn markdown_editor_complete_setext_heading_on_space(
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
fn markdown_editor_insert_hard_break(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
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
  let current = { caret: replace_range.start, selection: None }
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
fn markdown_editor_complete_quoted_code_fence_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
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
) -> @core.RichTextInputTransform? {
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
    markdown_editor_containing_quoted_code_block(source, { caret, selection }) {
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
) -> @core.RichTextInputTransform? {
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
) -> @core.RichTextInputTransform {
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
  line : String,
) -> MarkdownCodeFenceInfo? {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() < indent + 3 {
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
fn markdown_editor_complete_setext_heading_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
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
fn markdown_editor_renumber_ordered_lists(
  source : String,
) -> MarkdownEditorRenumberResult {
  let lines = markdown_editor_lines(source)
  let rendered : Array[String] = []
  let replacements : Array[MarkdownEditorOffsetReplacement] = []
  let contexts : Array[MarkdownEditorOrderedRenumberContext] = []
  for line in lines {
    match markdown_editor_ordered_line_info(line.text) {
      Some(info) => {
        markdown_editor_trim_ordered_renumber_contexts(contexts, info.indent)
        let next_number = markdown_editor_next_ordered_number(contexts, info)
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
        markdown_editor_reset_ordered_renumber_contexts(contexts, line.text)
        rendered.push(line.text)
      }
    }
  }
  { text: markdown_join_lines(rendered), replacements }
}

///|
struct MarkdownEditorOrderedRenumberContext {
  indent : Int
  context_prefix : String
  expected : Int
} derive(Eq, Debug)

///|
fn markdown_editor_trim_ordered_renumber_contexts(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  indent : Int,
) -> Unit {
  while contexts.length() > 0 && contexts[contexts.length() - 1].indent > indent {
    ignore(contexts.pop())
  }
}

///|
fn markdown_editor_next_ordered_number(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  info : MarkdownEditorOrderedLineInfo,
) -> Int {
  if contexts.length() > 0 &&
    contexts[contexts.length() - 1].indent == info.indent &&
    contexts[contexts.length() - 1].context_prefix == info.context_prefix {
    let context = contexts[contexts.length() - 1]
    ignore(contexts.pop())
    contexts.push({
      indent: info.indent,
      context_prefix: info.context_prefix,
      expected: context.expected + 1,
    })
    context.expected
  } else {
    while contexts.length() > 0 &&
          contexts[contexts.length() - 1].indent >= info.indent {
      ignore(contexts.pop())
    }
    contexts.push({
      indent: info.indent,
      context_prefix: info.context_prefix,
      expected: info.number + 1,
    })
    info.number
  }
}

///|
fn markdown_editor_reset_ordered_renumber_contexts(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  line : String,
) -> Unit {
  if contexts.length() == 0 || markdown_editor_ordered_renumber_blank_line(line) {
    return
  }
  let indent = markdown_editor_ordered_line_context_indent(line)
  if indent > contexts[contexts.length() - 1].indent {
    return
  }
  contexts.clear()
}

///|
fn markdown_editor_ordered_renumber_blank_line(line : String) -> Bool {
  let chars = line.to_array()
  let indent = markdown_editor_ordered_line_context_indent(line)
  String::from_array(chars[indent:]).trim().to_owned() == ""
}

///|
struct MarkdownEditorOrderedLineInfo {
  indent : Int
  context_prefix : String
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
  let indent = markdown_editor_ordered_line_context_indent(line)
  let digit_end = markdown_editor_ordered_digit_end_at(chars, indent)
  if digit_end <= indent ||
    digit_end + 1 >= chars.length() ||
    chars[digit_end] != '.' ||
    chars[digit_end + 1] != ' ' {
    None
  } else {
    Some({
      indent,
      context_prefix: String::from_array(chars[:indent]),
      digit_start: indent,
      digit_end,
      digits: String::from_array(chars[indent:digit_end]),
      number: markdown_editor_parse_digits(chars, indent, digit_end),
    })
  }
}

///|
fn markdown_editor_ordered_line_context_indent(line : String) -> Int {
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
fn markdown_editor_ordered_digit_end_at(
  chars : Array[Char],
  start : Int,
) -> Int {
  let mut index = markdown_editor_clamp_int(start, 0, chars.length())
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  index
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
        None =>
          match
            markdown_editor_quoted_code_block_at_content_offset(
              source, caret, selection,
            ) {
            Some(block) =>
              markdown_editor_quoted_code_block_paste_insert(
                source, block, caret, input,
              )
            None => markdown_editor_contextual_paste_insert(line, input)
          }
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
fn markdown_editor_quoted_code_block_paste_insert(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
  caret : Int,
  input : String,
) -> String {
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
  markdown_editor_join_paste_lines(
    markdown_editor_prefix_paste_continuation_lines(input, prefix),
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
    let stripped = markdown_editor_strip_block_marker(lines[index])
    if stripped.trim().to_owned() == "" {
      formatted.push(markdown_editor_blank_paste_continuation_prefix(line))
      continue
    }
    if markdown_editor_line_indent_prefix_length(lines[index]) > 0 {
      formatted.push(markdown_editor_quote_context_prefix(line) + lines[index])
      continue
    }
    let prefix = if ordered_number > 0 {
      let marker = markdown_editor_ordered_paste_prefix(line, ordered_number)
      ordered_number = ordered_number + 1
      marker
    } else {
      continuation
    }
    formatted.push(prefix + stripped)
  }
  markdown_editor_join_paste_lines(formatted)
}

///|
fn markdown_editor_quote_context_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    String::from_array(chars[:indent + 2]) +
    markdown_editor_quote_context_prefix(String::from_array(chars[indent + 2:]))
  } else {
    ""
  }
}

///|
fn markdown_editor_blank_paste_continuation_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    return String::from_array(chars[:indent + 2]) +
      markdown_editor_blank_paste_continuation_prefix(
        String::from_array(chars[indent + 2:]),
      )
  }
  ""
}

///|
fn markdown_editor_ordered_continuation_number(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    return markdown_editor_ordered_continuation_number(
      String::from_array(chars[indent + 2:]),
    )
  }
  if markdown_editor_ordered_marker_length(chars) > 0 {
    markdown_editor_parse_digits(
      chars,
      indent,
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
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    return String::from_array(chars[:indent + 2]) +
      markdown_editor_ordered_paste_prefix(
        String::from_array(chars[indent + 2:]),
        number,
      )
  }
  String::from_array(chars[:indent]) + number.to_string() + ". "
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
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let range = markdown_editor_current_line_range(source, { caret, selection })
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
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let range = markdown_editor_current_line_range(source, { caret, selection })
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
) -> @core.RichTextInputTransform? {
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
