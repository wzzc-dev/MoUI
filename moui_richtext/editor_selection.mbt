///|
pub fn markdown_editor_selected_link_target(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_link_context(source, selection) {
    Some(context) => markdown_editor_reference_target(source, context.bounds)
    None => None
  }
}

///|
pub fn markdown_editor_selected_image_target(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_image_context(source, selection) {
    Some(context) => markdown_editor_reference_target(source, context.bounds)
    None => None
  }
}

///|
pub(all) struct MarkdownReferenceContext {
  range : @core.TextRange
  bounds : MarkdownLinkBounds
} derive(Eq, Debug)

///|
pub fn markdown_editor_link_context(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownReferenceContext? {
  match markdown_editor_active_selection(selection.selection) {
    Some(range) => {
      let range = range.normalized()
      match markdown_editor_range_link_bounds(source, range) {
        Some(bounds) => Some({ range, bounds })
        None => None
      }
    }
    None => markdown_editor_link_context_at_caret(source, selection.caret)
  }
}

///|
pub fn markdown_editor_image_context(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownReferenceContext? {
  match markdown_editor_active_selection(selection.selection) {
    Some(range) => {
      let range = range.normalized()
      match markdown_editor_range_image_bounds(source, range) {
        Some(bounds) => Some({ range, bounds })
        None => None
      }
    }
    None => markdown_editor_image_context_at_caret(source, selection.caret)
  }
}

///|
fn markdown_editor_link_context_at_caret(
  source : String,
  caret : Int,
) -> MarkdownReferenceContext? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_autolink_context_at_caret(source, chars, caret) {
    Some(context) => return Some(context)
    None => ()
  }
  match
    markdown_editor_bracketed_reference_range_at_caret(
      chars,
      caret,
      image=false,
    ) {
    Some(range) =>
      match markdown_editor_range_link_bounds(source, range) {
        Some(bounds) => Some({ range, bounds })
        None => None
      }
    None => None
  }
}

///|
fn markdown_editor_image_context_at_caret(
  source : String,
  caret : Int,
) -> MarkdownReferenceContext? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match
    markdown_editor_bracketed_reference_range_at_caret(chars, caret, image=true) {
    Some(range) =>
      match markdown_editor_range_image_bounds(source, range) {
        Some(bounds) => Some({ range, bounds })
        None => None
      }
    None => None
  }
}

///|
fn markdown_editor_autolink_context_at_caret(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> MarkdownReferenceContext? {
  let mut open = caret
  while open > 0 && chars[open - 1] != '<' && chars[open - 1] != '\n' {
    open = open - 1
  }
  if open <= 0 || chars[open - 1] != '<' {
    return None
  }
  let mut close = caret
  while close < chars.length() && chars[close] != '>' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() || chars[close] != '>' {
    return None
  }
  let range = @core.TextRange::new(start=open, end=close)
  match markdown_editor_range_link_bounds(source, range) {
    Some(bounds) => Some({ range, bounds })
    None => None
  }
}

///|
fn markdown_editor_bracketed_reference_range_at_caret(
  chars : Array[Char],
  caret : Int,
  image~ : Bool,
) -> @core.TextRange? {
  let mut open = caret
  while open > 0 && chars[open - 1] != '[' && chars[open - 1] != '\n' {
    open = open - 1
  }
  if open <= 0 || chars[open - 1] != '[' {
    return None
  }
  let open_start = open - 1
  if image {
    if open_start <= 0 || chars[open_start - 1] != '!' {
      return None
    }
  } else if open_start > 0 && chars[open_start - 1] == '!' {
    return None
  }
  let mut close = open
  while close < chars.length() && chars[close] != ']' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() || chars[close] != ']' || caret > close {
    return None
  }
  Some(@core.TextRange::new(start=open, end=close))
}

///|
pub fn markdown_editor_selected_footnote_text(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_footnote_label_at_selection(source, selection) {
    Some(label) => markdown_editor_footnote_definition_text(source, label)
    None => None
  }
}

///|
pub fn markdown_editor_selected_html_block_text(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  match markdown_editor_html_block_at_selection(source, selection) {
    Some(block) => Some(block.block.text)
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
fn markdown_editor_code_block_at_content_offset(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  context? : MarkdownEditorInputContext? = None,
) -> MarkdownEditorBlock? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let caret = markdown_editor_clamp_int(
    caret,
    0,
    markdown_editor_text_length(source),
  )
  // With the session's blocks at hand, scanning them is O(blocks) over
  // ranges that are already exact; only callers without a session pay for
  // the whole-document parse.
  let blocks = match context {
    Some(context) => context.blocks
    None => parse_markdown_editor_blocks(source)
  }
  for block in blocks {
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
) -> RichTextInputTransform {
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
pub(all) struct MarkdownLinkBounds {
  open_start : Int
  close_start : Int
  target_end : Int
  target_start : Int
  definition_target_start : Int
  definition_target_end : Int
  reference_label : String
} derive(Eq, Debug)

///|
/// Whole-source entry for the command and hit-test paths, which run once
/// per interaction; the reveal path calls the windowed core directly with
/// a block-sized window instead of materializing the whole document.
fn markdown_editor_range_link_bounds(
  source : String,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  markdown_editor_range_link_bounds_in(
    source,
    chars=markdown_editor_source_chars_all(source),
    range,
  )
}

///|
fn markdown_editor_range_link_bounds_in(
  source : String,
  chars~ : MarkdownSourceChars,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  match markdown_editor_range_autolink_bounds_in(chars~, range) {
    Some(bounds) => return Some(bounds)
    None => ()
  }
  if range.start < 1 || range.end + 2 > chars.length() {
    return None
  }
  let open_start = range.start - 1
  // `open_start - 1 == range.start - 2` is inside the window whenever it
  // is >= 0: the near window begins at `range.start - 2`, the all window
  // at 0.
  let bang_before = match chars.get(open_start - 1) {
    Some(ch) => ch == '!'
    None => false
  }
  if open_start > 0 && bang_before {
    return None
  }
  let open_char = match chars.get(open_start) {
    Some(ch) => ch
    None => return None
  }
  let close_char = match chars.get(range.end) {
    Some(ch) => ch
    None => return None
  }
  if open_char != '[' || close_char != ']' {
    return None
  }
  match chars.get(range.end + 1) {
    Some('[') =>
      return markdown_editor_reference_link_bounds_in(
        source,
        chars~,
        range,
        open_start,
        bang=false,
      )
    Some('(') => ()
    // The window tail ends on blank lines, so an out-of-window read plays
    // the role the '\n' terminator played in the whole-source scan.
    _ =>
      return markdown_editor_shortcut_reference_link_bounds_in(
        source,
        chars~,
        range,
        open_start,
      )
  }
  let mut index = range.end + 2
  let mut found = false
  while index < chars.length() {
    match chars.get(index) {
      Some(')') => {
        found = true
        break
      }
      Some('\n') => break
      Some(_) => index = index + 1
      None => break
    }
  }
  if found {
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
fn markdown_editor_range_autolink_bounds_in(
  chars~ : MarkdownSourceChars,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  if range.start < 1 || range.end >= chars.length() {
    return None
  }
  let open_char = match chars.get(range.start - 1) {
    Some(ch) => ch
    None => return None
  }
  let close_char = match chars.get(range.end) {
    Some(ch) => ch
    None => return None
  }
  if open_char != '<' || close_char != '>' {
    return None
  }
  let target = match chars.slice(range.start, range.end) {
    Some(slice) => String::from_array(slice)
    None => return None
  }
  if !markdown_editor_is_autolink_target(target) {
    return None
  }
  Some({
    open_start: range.start - 1,
    close_start: range.end,
    target_start: range.start,
    target_end: range.end,
    definition_target_start: -1,
    definition_target_end: -1,
    reference_label: "",
  })
}

///|
fn markdown_editor_shortcut_reference_link_bounds_in(
  source : String,
  chars~ : MarkdownSourceChars,
  range : @core.TextRange,
  open_start : Int,
) -> MarkdownLinkBounds? {
  let label = match chars.slice(range.start, range.end) {
    Some(slice) => String::from_array(slice)
    None => return None
  }
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
/// Whole-source entry; see `markdown_editor_range_link_bounds`.
fn markdown_editor_range_image_bounds(
  source : String,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  markdown_editor_range_image_bounds_in(
    source,
    chars=markdown_editor_source_chars_all(source),
    range,
  )
}

///|
fn markdown_editor_range_image_bounds_in(
  source : String,
  chars~ : MarkdownSourceChars,
  range : @core.TextRange,
) -> MarkdownLinkBounds? {
  if range.start < 2 || range.end + 2 > chars.length() {
    return None
  }
  let bang_start = range.start - 2
  let open_start = range.start - 1
  let bang_char = match chars.get(bang_start) {
    Some(ch) => ch
    None => return None
  }
  let open_char = match chars.get(open_start) {
    Some(ch) => ch
    None => return None
  }
  let close_char = match chars.get(range.end) {
    Some(ch) => ch
    None => return None
  }
  if bang_char != '!' || open_char != '[' || close_char != ']' {
    return None
  }
  match chars.get(range.end + 1) {
    Some('[') =>
      return markdown_editor_reference_link_bounds_in(
        source,
        chars~,
        range,
        bang_start,
        bang=true,
      )
    Some('(') => ()
    _ => return None
  }
  let mut index = range.end + 2
  let mut found = false
  while index < chars.length() {
    match chars.get(index) {
      Some(')') => {
        found = true
        break
      }
      Some('\n') => break
      Some(_) => index = index + 1
      None => break
    }
  }
  if found {
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
fn markdown_editor_reference_link_bounds_in(
  source : String,
  chars~ : MarkdownSourceChars,
  range : @core.TextRange,
  open_start : Int,
  bang~ : Bool,
) -> MarkdownLinkBounds? {
  let label_start = range.end + 2
  let mut label_end = label_start
  let mut closed = false
  while label_end < chars.length() {
    match chars.get(label_end) {
      Some(']') => {
        closed = true
        break
      }
      Some('\n') => break
      Some(_) => label_end = label_end + 1
      None => break
    }
  }
  if !closed {
    return None
  }
  let fallback_start = if bang { open_start + 2 } else { open_start + 1 }
  let label = if label_end == label_start {
    match chars.slice(fallback_start, range.end) {
      Some(slice) => String::from_array(slice)
      None => return None
    }
  } else {
    match chars.slice(label_start, label_end) {
      Some(slice) => String::from_array(slice)
      None => return None
    }
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
  let source_length = markdown_editor_text_length(source)
  let start = markdown_editor_clamp_int(range.start, 0, source_length)
  let end = markdown_editor_clamp_int(range.end, start, source_length)
  let selected = markdown_editor_substring(source, start, end)
  let text = markdown_editor_substring(source, 0, start) +
    "[" +
    selected +
    "](" +
    target +
    ")" +
    markdown_editor_substring(source, end, source_length)
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
  let source_length = markdown_editor_text_length(source)
  let start = markdown_editor_clamp_int(range.start, 0, source_length)
  let end = markdown_editor_clamp_int(range.end, start, source_length)
  let selected = markdown_editor_substring(source, start, end)
  let text = markdown_editor_substring(source, 0, start) +
    "![" +
    selected +
    "](" +
    target +
    ")" +
    markdown_editor_substring(source, end, source_length)
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
  let source_length = markdown_editor_text_length(source)
  let text = markdown_editor_substring(source, 0, target_start) +
    target +
    markdown_editor_substring(source, target_end, source_length)
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
  let source_length = markdown_editor_text_length(source)
  if start > end || end > source_length {
    None
  } else {
    Some(markdown_editor_substring(source, start, end))
  }
}

///|
fn markdown_editor_unwrap_link_range(
  source : String,
  range : @core.TextRange,
  bounds : MarkdownLinkBounds,
) -> MarkdownEditorEditResult {
  let source_length = markdown_editor_text_length(source)
  let text = markdown_editor_substring(source, 0, bounds.open_start) +
    markdown_editor_substring(source, range.start, range.end) +
    markdown_editor_substring(source, bounds.target_end + 1, source_length)
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
  let source_length = markdown_editor_text_length(source)
  let text = markdown_editor_substring(source, 0, bounds.open_start) +
    markdown_editor_substring(source, range.start, range.end) +
    markdown_editor_substring(source, bounds.target_end + 1, source_length)
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
  markdown_editor_current_line_range_from_chars(chars, selection)
}

///|
fn markdown_editor_current_line_range_from_chars(
  chars : Array[Char],
  selection : MarkdownEditorSelection,
) -> MarkdownSourceRange {
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
pub fn markdown_editor_active_selection(
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
