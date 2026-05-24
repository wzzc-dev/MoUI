///|
fn markdown_editor_selected_link_target(
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
fn markdown_editor_selected_image_target(
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
fn markdown_editor_selected_code_language(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_code_block_at_selection(source, selection) {
    Some(block) => block.block.code_language
    None => None
  }
}

///|
fn markdown_editor_selected_footnote_text(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_footnote_label_at_selection(source, selection) {
    Some(label) => markdown_editor_footnote_definition_text(source, label)
    None => None
  }
}

///|
fn markdown_editor_selected_html_block_text(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_html_block_at_selection(source, selection) {
    Some(block) => Some(block.block.text)
    None => None
  }
}

///|
fn markdown_editor_active_block_label(
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
fn markdown_editor_code_block_at_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlock? {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return None
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if block.block.kind is MarkdownBlockKind::CodeBlock &&
      caret >= block.source_range.start &&
      caret <= block.source_range.end {
      return Some(block)
    }
  }
  None
}

///|
fn markdown_editor_html_block_at_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlock? {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return None
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if block.block.kind is MarkdownBlockKind::HtmlBlock &&
      caret >= block.source_range.start &&
      caret <= block.source_range.end {
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
struct MarkdownLinkBounds {
  open_start : Int
  close_start : Int
  target_end : Int
  target_start : Int
  definition_target_start : Int
  definition_target_end : Int
  reference_label : String
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
  if chars[open_start] != '[' || chars[range.end] != ']' {
    return None
  }
  if chars[range.end + 1] == '[' {
    return markdown_editor_reference_link_bounds(
      source,
      range,
      open_start,
      bang=false,
    )
  }
  if chars[range.end + 1] != '(' {
    return markdown_editor_shortcut_reference_link_bounds(
      source, range, open_start,
    )
  }
  let mut index = range.end + 2
  while index < chars.length() && chars[index] != ')' && chars[index] != '\n' {
    index = index + 1
  }
  if index < chars.length() && chars[index] == ')' {
    Some({
      open_start,
      close_start: range.end,
      target_start: range.end + 2,
      target_end: index,
      definition_target_start: -1,
      definition_target_end: -1,
      reference_label: "",
    })
  } else {
    None
  }
}

///|
fn markdown_editor_shortcut_reference_link_bounds(
  source : String,
  range : @core.TextRange,
  open_start : Int,
) -> MarkdownLinkBounds? {
  let chars = source.to_array()
  let label = String::from_array(chars[range.start:range.end])
  if label == "" {
    return None
  }
  match markdown_editor_reference_definition_target_range(source, label) {
    Some(target) =>
      Some({
        open_start,
        close_start: range.end,
        target_start: range.end,
        target_end: range.end,
        definition_target_start: target.start,
        definition_target_end: target.end,
        reference_label: label,
      })
    None =>
      Some({
        open_start,
        close_start: range.end,
        target_start: range.end,
        target_end: range.end,
        definition_target_start: -1,
        definition_target_end: -1,
        reference_label: label,
      })
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
    chars[range.end] != ']' {
    return None
  }
  if chars[range.end + 1] == '[' {
    return markdown_editor_reference_link_bounds(
      source,
      range,
      bang_start,
      bang=true,
    )
  }
  if chars[range.end + 1] != '(' {
    return None
  }
  let mut index = range.end + 2
  while index < chars.length() && chars[index] != ')' && chars[index] != '\n' {
    index = index + 1
  }
  if index < chars.length() && chars[index] == ')' {
    Some({
      open_start: bang_start,
      close_start: range.end,
      target_start: range.end + 2,
      target_end: index,
      definition_target_start: -1,
      definition_target_end: -1,
      reference_label: "",
    })
  } else {
    None
  }
}

///|
fn markdown_editor_reference_link_bounds(
  source : String,
  range : @core.TextRange,
  open_start : Int,
  bang~ : Bool,
) -> MarkdownLinkBounds? {
  let chars = source.to_array()
  let label_start = range.end + 2
  let mut label_end = label_start
  while label_end < chars.length() &&
        chars[label_end] != ']' &&
        chars[label_end] != '\n' {
    label_end = label_end + 1
  }
  if label_end >= chars.length() || chars[label_end] != ']' {
    return None
  }
  let fallback_start = if bang { open_start + 2 } else { open_start + 1 }
  let label = if label_end == label_start {
    String::from_array(chars[fallback_start:range.end])
  } else {
    String::from_array(chars[label_start:label_end])
  }
  match markdown_editor_reference_definition_target_range(source, label) {
    Some(target) =>
      Some({
        open_start,
        close_start: range.end,
        target_start: label_start,
        target_end: label_end,
        definition_target_start: target.start,
        definition_target_end: target.end,
        reference_label: label,
      })
    None =>
      Some({
        open_start,
        close_start: range.end,
        target_start: label_start,
        target_end: label_end,
        definition_target_start: -1,
        definition_target_end: -1,
        reference_label: label,
      })
  }
}

///|
fn markdown_editor_reference_definition_target_range(
  source : String,
  label : String,
) -> MarkdownSourceRange? {
  let key = markdown_reference_label_key(label)
  for line in markdown_editor_lines(source) {
    match markdown_editor_reference_definition_line_target_range(line) {
      Some((definition_label, target)) =>
        if markdown_reference_label_key(definition_label) == key {
          return Some(target)
        }
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_reference_definition_line_target_range(
  line : MarkdownLine,
) -> (String, MarkdownSourceRange)? {
  let chars = line.text.to_array()
  let start = markdown_editor_leading_indent_length(chars)
  if start >= chars.length() || chars[start] != '[' {
    return None
  }
  let mut close = start + 1
  while close < chars.length() && chars[close] != ']' {
    close = close + 1
  }
  if close <= start + 1 ||
    close + 1 >= chars.length() ||
    chars[close + 1] != ':' {
    return None
  }
  let mut target_start = close + 2
  while target_start < chars.length() &&
        (chars[target_start] == ' ' || chars[target_start] == '\t') {
    target_start = target_start + 1
  }
  if target_start >= chars.length() {
    return None
  }
  let mut target_end = target_start
  if chars[target_start] == '<' {
    target_start = target_start + 1
    target_end = target_start
    while target_end < chars.length() && chars[target_end] != '>' {
      target_end = target_end + 1
    }
  } else {
    while target_end < chars.length() &&
          chars[target_end] != ' ' &&
          chars[target_end] != '\t' {
      target_end = target_end + 1
    }
  }
  if target_end <= target_start {
    return None
  }
  Some(
    (
      String::from_array(chars[start + 1:close]),
      { start: line.start + target_start, end: line.start + target_end },
    ),
  )
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
  if bounds.definition_target_start < 0 && bounds.reference_label != "" {
    let text = source +
      markdown_editor_reference_definition_append_prefix(source) +
      "[" +
      bounds.reference_label +
      "]: " +
      target
    let next_selection = @core.TextRange::new(start=range.start, end=range.end)
    return {
      source: text,
      caret: next_selection.end,
      selection: Some(next_selection),
    }
  }
  let target_start = if bounds.definition_target_start >= 0 {
    bounds.definition_target_start
  } else {
    bounds.target_start
  }
  let target_end = if bounds.definition_target_end >= 0 {
    bounds.definition_target_end
  } else {
    bounds.target_end
  }
  let text = String::from_array(chars[:target_start]) +
    target +
    String::from_array(chars[target_end:])
  let next_selection = @core.TextRange::new(start=range.start, end=range.end)
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_reference_definition_append_prefix(
  source : String,
) -> String {
  if source == "" {
    ""
  } else if source.has_suffix("\n\n") {
    ""
  } else if source.has_suffix("\n") {
    "\n"
  } else {
    "\n\n"
  }
}

///|
fn markdown_editor_footnote_label_at_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  match markdown_editor_footnote_reference_label_at(source, anchor) {
    Some(label) => Some(label)
    None => markdown_editor_footnote_definition_label_at(source, anchor)
  }
}

///|
fn markdown_editor_footnote_reference_label_at(
  source : String,
  anchor : Int,
) -> String? {
  let chars = source.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut open = markdown_editor_clamp_int(anchor, 0, chars.length() - 1)
  while open > 0 && chars[open] != '[' {
    open = open - 1
  }
  if open + 3 >= chars.length() || chars[open] != '[' || chars[open + 1] != '^' {
    return None
  }
  let mut close = open + 2
  while close < chars.length() && chars[close] != ']' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() || chars[close] != ']' {
    return None
  }
  if anchor < open + 2 || anchor > close {
    return None
  }
  Some(String::from_array(chars[open + 2:close]))
}

///|
fn markdown_editor_footnote_definition_label_at(
  source : String,
  anchor : Int,
) -> String? {
  for line in markdown_editor_lines(source) {
    if anchor >= line.start && anchor <= line.end {
      match markdown_editor_footnote_definition_line_text_range(line) {
        Some((label, _)) => return Some(label)
        None => return None
      }
    }
  }
  None
}

///|
fn markdown_editor_footnote_definition_text(
  source : String,
  label : String,
) -> String? {
  let key = markdown_reference_label_key(label)
  let chars = source.to_array()
  for line in markdown_editor_lines(source) {
    match markdown_editor_footnote_definition_line_text_range(line) {
      Some((definition_label, range)) =>
        if markdown_reference_label_key(definition_label) == key {
          return Some(String::from_array(chars[range.start:range.end]))
        }
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_footnote_definition_line_text_range(
  line : MarkdownLine,
) -> (String, MarkdownSourceRange)? {
  let chars = line.text.to_array()
  let start = markdown_editor_leading_indent_length(chars)
  if start + 4 >= chars.length() ||
    chars[start] != '[' ||
    chars[start + 1] != '^' {
    return None
  }
  let mut close = start + 2
  while close < chars.length() && chars[close] != ']' {
    close = close + 1
  }
  if close <= start + 2 ||
    close + 1 >= chars.length() ||
    chars[close + 1] != ':' {
    return None
  }
  let mut text_start = close + 2
  while text_start < chars.length() &&
        (chars[text_start] == ' ' || chars[text_start] == '\t') {
    text_start = text_start + 1
  }
  Some(
    (
      String::from_array(chars[start + 2:close]),
      { start: line.start + text_start, end: line.end },
    ),
  )
}

///|
fn markdown_editor_set_footnote_text(
  source : String,
  selection : MarkdownEditorSelection,
  text : String,
) -> MarkdownEditorEditResult {
  match markdown_editor_footnote_label_at_selection(source, selection) {
    Some(label) =>
      match
        markdown_editor_replace_footnote_definition_text(source, label, text) {
        Some(result) => result
        None =>
          markdown_editor_append_footnote_definition(
            source, label, text, selection,
          )
      }
    None => markdown_editor_append_snippet(source, SetFootnoteText(text))
  }
}

///|
fn markdown_editor_replace_footnote_definition_text(
  source : String,
  label : String,
  text : String,
) -> MarkdownEditorEditResult? {
  let key = markdown_reference_label_key(label)
  let chars = source.to_array()
  for line in markdown_editor_lines(source) {
    match markdown_editor_footnote_definition_line_text_range(line) {
      Some((definition_label, range)) =>
        if markdown_reference_label_key(definition_label) == key {
          let next_source = String::from_array(chars[:range.start]) +
            text +
            String::from_array(chars[range.end:])
          return Some({
            source: next_source,
            caret: range.start + markdown_editor_text_length(text),
            selection: None,
          })
        }
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_append_footnote_definition(
  source : String,
  label : String,
  text : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let next_source = source +
    markdown_editor_reference_definition_append_prefix(source) +
    "[^" +
    label +
    "]: " +
    text
  {
    source: next_source,
    caret: selection.caret,
    selection: selection.selection,
  }
}

///|
fn markdown_editor_reference_target(
  source : String,
  bounds : MarkdownLinkBounds,
) -> String? {
  let chars = source.to_array()
  let start = if bounds.definition_target_start >= 0 {
    bounds.definition_target_start
  } else {
    bounds.target_start
  }
  let end = if bounds.definition_target_end >= 0 {
    bounds.definition_target_end
  } else {
    bounds.target_end
  }
  if start > end || end > chars.length() {
    None
  } else {
    Some(String::from_array(chars[start:end]))
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
