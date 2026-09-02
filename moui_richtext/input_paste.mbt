///|
fn markdown_editor_paste_footnote_definition(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  let pasted = input.trim().to_owned()
  if markdown_editor_text_length(pasted) != markdown_editor_text_length(input) {
    return None
  }
  let definition = match markdown_editor_pasted_footnote_definition(pasted) {
    Some(definition) => definition
    None => return None
  }
  let caret = markdown_editor_clamp_int(
    caret,
    0,
    markdown_editor_text_length(source),
  )
  let editor_selection : MarkdownEditorSelection = { caret, selection }
  match markdown_editor_footnote_label_at_selection(source, editor_selection) {
    Some(label) => {
      let updated = markdown_editor_upsert_pasted_footnote_definition(
        source,
        label,
        definition.text,
        caret,
      )
      return Some(
        markdown_editor_transform_result(
          text=updated.source,
          caret=caret + updated.anchor_delta,
          selection~,
        ),
      )
    }
    None => ()
  }
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      let source_length = markdown_editor_text_length(source)
      let normalized = range.normalized()
      let start = markdown_editor_clamp_int(normalized.start, 0, source_length)
      let end = markdown_editor_clamp_int(normalized.end, start, source_length)
      let selected = markdown_editor_substring(source, start, end)
      let marker = "[^" + definition.label + "]"
      let text = markdown_editor_substring(source, 0, start) +
        selected +
        marker +
        markdown_editor_substring(source, end, source_length)
      let next_selection = @core.TextRange::new(
        start~,
        end=start + markdown_editor_text_length(selected),
      )
      let updated = markdown_editor_upsert_pasted_footnote_definition(
        text,
        definition.label,
        definition.text,
        next_selection.start,
      )
      let selection_shift = updated.anchor_delta
      Some(
        markdown_editor_transform_result(
          text=updated.source,
          caret=next_selection.end + selection_shift,
          selection=Some(
            @core.TextRange::new(
              start=next_selection.start + selection_shift,
              end=next_selection.end + selection_shift,
            ),
          ),
        ),
      )
    }
    None => None
  }
}

///|
fn markdown_editor_pasted_footnote_definition(
  text : String,
) -> MarkdownEditorPastedFootnoteDefinition? {
  if text.contains("\n") {
    return None
  }
  let line : MarkdownLine = {
    text,
    start: 0,
    end: markdown_editor_text_length(text),
  }
  match markdown_editor_footnote_definition_line_text_range(line) {
    Some((label, range)) =>
      Some({
        label,
        text: markdown_editor_substring(text, range.start, range.end),
      })
    None => None
  }
}

///|
fn markdown_editor_upsert_pasted_footnote_definition(
  source : String,
  label : String,
  text : String,
  anchor : Int,
) -> MarkdownEditorFootnoteDefinitionEdit {
  let key = markdown_reference_label_key(label)
  let source_length = markdown_editor_text_length(source)
  for line in markdown_editor_lines(source) {
    match markdown_editor_footnote_definition_line_text_range(line) {
      Some((definition_label, range)) =>
        if markdown_reference_label_key(definition_label) == key {
          let next_source = markdown_editor_substring(source, 0, range.start) +
            text +
            markdown_editor_substring(source, range.end, source_length)
          let delta = markdown_editor_text_length(text) -
            (range.end - range.start)
          return {
            source: next_source,
            anchor_delta: if range.end <= anchor {
              delta
            } else {
              0
            },
          }
        }
      None => ()
    }
  }
  {
    source: source +
    markdown_editor_reference_definition_append_prefix(source) +
    "[^" +
    label +
    "]: " +
    text,
    anchor_delta: 0,
  }
}

///|
fn markdown_editor_paste_autolink(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) ||
    markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  if markdown_editor_text_length(input.trim().to_owned()) !=
    markdown_editor_text_length(input) {
    return None
  }
  let target = markdown_editor_autolink_target_with_trailing_punctuation(input)
  if target.target == "" {
    return None
  }
  let source_length = markdown_editor_text_length(source)
  let caret = markdown_editor_clamp_int(caret, 0, source_length)
  let insert = target.leading + "<" + target.target + ">" + target.trailing
  Some(
    markdown_editor_transform_result(
      text=markdown_editor_substring(source, 0, caret) +
        insert +
        markdown_editor_substring(source, caret, source_length),
      caret=caret + markdown_editor_text_length(insert),
    ),
  )
}

///|
fn markdown_editor_complete_autolink_on_space(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) ||
    markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let start = markdown_editor_previous_token_start(chars, caret)
  if start == caret || (start > 0 && chars[start - 1] == '<') {
    return None
  }
  let token = String::from_array(chars[start:caret])
  let target = markdown_editor_autolink_target_with_trailing_punctuation(token)
  if target.target == "" {
    return None
  }
  let replacement = target.leading +
    "<" +
    target.target +
    ">" +
    target.trailing +
    " "
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
fn markdown_editor_complete_autolink_on_enter(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  line : String,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) ||
    markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let start = markdown_editor_previous_token_start(chars, caret)
  if start == caret || (start > 0 && chars[start - 1] == '<') {
    return None
  }
  let token = String::from_array(chars[start:caret])
  let target = markdown_editor_autolink_target_with_trailing_punctuation(token)
  if target.target == "" {
    return None
  }
  let replacement = target.leading +
    "<" +
    target.target +
    ">" +
    target.trailing +
    "\n" +
    markdown_editor_continuation_marker(line)
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
priv struct MarkdownEditorAutolinkTarget {
  leading : String
  target : String
  trailing : String
}

///|
fn markdown_editor_autolink_target_with_trailing_punctuation(
  token : String,
) -> MarkdownEditorAutolinkTarget {
  let chars = token.to_array()
  let empty = { leading: "", target: "", trailing: "" }
  if chars.length() > 0 &&
    !markdown_editor_autolink_trailing_punctuation(chars[chars.length() - 1]) &&
    markdown_editor_is_autolink_target(token) {
    return { leading: "", target: token, trailing: "" }
  }
  let mut start = 0
  while start < chars.length() &&
        markdown_editor_autolink_leading_wrapper(chars[start]) {
    start = start + 1
  }
  let mut end = chars.length()
  while end > start &&
        markdown_editor_autolink_trailing_punctuation(chars[end - 1]) {
    end = end - 1
  }
  let wrapper_end = end
  if start > 0 {
    while end > start &&
          markdown_editor_autolink_trailing_wrapper(chars[end - 1]) {
      end = end - 1
    }
  }
  if start == 0 && end == chars.length() {
    return empty
  }
  if !markdown_editor_autolink_wrappers_balanced(chars, start, end, wrapper_end) {
    return empty
  }
  let target = String::from_array(chars[start:end])
  if !markdown_editor_is_autolink_target(target) {
    return empty
  }
  {
    leading: String::from_array(chars[:start]),
    target,
    trailing: String::from_array(chars[end:]),
  }
}

///|
fn markdown_editor_autolink_leading_wrapper(ch : Char) -> Bool {
  ch == '(' || ch == '[' || ch == '{'
}

///|
fn markdown_editor_autolink_trailing_wrapper(ch : Char) -> Bool {
  ch == ')' || ch == ']' || ch == '}'
}

///|
fn markdown_editor_autolink_wrappers_balanced(
  chars : Array[Char],
  start : Int,
  end : Int,
  wrapper_end : Int,
) -> Bool {
  let trailing = wrapper_end - end
  if start > trailing {
    return false
  }
  for index in 0..<start {
    let close_index = wrapper_end - 1 - index
    if !markdown_editor_autolink_wrapper_pair(chars[index], chars[close_index]) {
      return false
    }
  }
  true
}

///|
fn markdown_editor_autolink_wrapper_pair(open : Char, close : Char) -> Bool {
  (open == '(' && close == ')') ||
  (open == '[' && close == ']') ||
  (open == '{' && close == '}')
}

///|
fn markdown_editor_autolink_trailing_punctuation(ch : Char) -> Bool {
  ch == '.' || ch == ',' || ch == ';' || ch == ':' || ch == '!' || ch == '?'
}

///|
fn markdown_editor_paste_html_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let html = match markdown_editor_pasted_html_block(input) {
    Some(html) => html
    None => return None
  }
  let editor_selection : MarkdownEditorSelection = { caret, selection }
  if markdown_editor_active_selection(selection) is None {
    match markdown_editor_html_block_at_selection(source, editor_selection) {
      Some(block) => {
        let source_length = markdown_editor_text_length(source)
        return Some(
          markdown_editor_transform_result(
            text=markdown_editor_substring(source, 0, block.source_range.start) +
              html +
              markdown_editor_substring(
                source,
                block.source_range.end,
                source_length,
              ),
            caret=block.source_range.start + markdown_editor_text_length(html),
          ),
        )
      }
      None => ()
    }
  }
  markdown_editor_paste_block_text_as_block(source, caret, selection, html)
}

///|
fn markdown_editor_pasted_html_block(input : String) -> String? {
  let text = input.trim().to_owned()
  if text == "" || !markdown_editor_pasted_html_block_head_supported(text) {
    return None
  }
  let blocks = parse_markdown(text)
  if blocks.length() != 1 {
    return None
  }
  match blocks[0].kind {
    MarkdownBlockKind::HtmlBlock => Some(text)
    _ => None
  }
}

///|
fn markdown_editor_pasted_html_block_head_supported(text : String) -> Bool {
  let chars = text.to_array()
  let mut start = 0
  while start < chars.length() && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  if start + 4 <= chars.length() &&
    chars[start] == '<' &&
    chars[start + 1] == '!' &&
    chars[start + 2] == '-' &&
    chars[start + 3] == '-' {
    return true
  }
  if start + 2 <= chars.length() &&
    chars[start] == '<' &&
    (chars[start + 1] == '!' || chars[start + 1] == '?') {
    return true
  }
  if start + 2 >= chars.length() || chars[start] != '<' {
    return false
  }
  let name_start = start + 1
  if chars[name_start] == '/' ||
    !markdown_html_tag_name_start_char(chars[name_start]) {
    return false
  }
  let mut name_end = name_start + 1
  while name_end < chars.length() &&
        markdown_html_tag_name_char(chars[name_end]) {
    name_end = name_end + 1
  }
  markdown_editor_html_block_tag_name_supported(
    String::from_array(chars[name_start:name_end]).to_lower(),
  )
}

///|
fn markdown_editor_html_block_tag_name_supported(name : String) -> Bool {
  for
    candidate in [
      "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption",
      "center", "col", "colgroup", "dd", "details", "dialog", "dir", "div", "dl",
      "dt", "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset",
      "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe",
      "legend", "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol",
      "optgroup", "option", "p", "param", "pre", "script", "search", "section", "style",
      "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track",
      "ul",
    ] {
    if name == candidate {
      return true
    }
  }
  false
}

///|
fn markdown_editor_paste_reference_over_selection(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  let target = input.trim().to_owned()
  if markdown_editor_text_length(target) != markdown_editor_text_length(input) {
    return None
  }
  let paste = match markdown_editor_reference_command_for_paste_target(target) {
    Some(paste) => paste
    None => return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let editor_selection : MarkdownEditorSelection = { caret, selection }
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      if paste.reference_style {
        return markdown_editor_paste_reference_label_over_selection(
          source, range, paste,
        )
      }
      let result = markdown_editor_set_reference_target(
        source,
        ({ caret: range.end, selection: Some(range) } : MarkdownEditorSelection),
        paste.command,
        paste.target,
      )
      Some(
        markdown_editor_transform_result(
          text=result.source,
          caret=result.caret,
          selection=result.selection,
        ),
      )
    }
    None => {
      if paste.reference_style {
        let image = match paste.command {
          SetImageTarget(_) => true
          _ => false
        }
        let context = if image {
          markdown_editor_image_context(source, editor_selection)
        } else {
          markdown_editor_link_context(source, editor_selection)
        }
        match context {
          Some(context) =>
            return Some(
              markdown_editor_reference_label_transform(
                source,
                context.range,
                context.bounds.open_start,
                markdown_editor_reference_bounds_full_end(context.bounds),
                paste.target,
                paste.definition_text,
                image~,
              ),
            )
          None => ()
        }
        return None
      }
      let has_context = match paste.command {
        SetImageTarget(_) =>
          markdown_editor_image_context(source, editor_selection) is Some(_)
        SetLinkTarget(_) =>
          markdown_editor_link_context(source, editor_selection) is Some(_)
        _ => false
      }
      if !has_context {
        return None
      }
      let result = markdown_editor_set_reference_target(
        source,
        editor_selection,
        paste.command,
        paste.target,
      )
      Some(
        markdown_editor_transform_result(
          text=result.source,
          caret=result.caret,
          selection=result.selection,
        ),
      )
    }
  }
}

///|
priv struct MarkdownEditorPasteReferenceCommand {
  command : MarkdownEditorCommand
  target : String
  reference_style : Bool
  definition_text : String
}

///|
fn markdown_editor_reference_command_for_paste_target(
  text : String,
) -> MarkdownEditorPasteReferenceCommand? {
  match markdown_editor_pasted_reference_definition(text) {
    Some(definition) =>
      return Some({
        command: SetLinkTarget(definition.target),
        target: definition.label,
        reference_style: true,
        definition_text: definition.definition_text,
      })
    None => ()
  }
  match markdown_editor_pasted_reference_target(text) {
    Some(reference) =>
      if reference.image {
        Some({
          command: SetImageTarget(reference.target),
          target: reference.target,
          reference_style: reference.reference_style,
          definition_text: "",
        })
      } else {
        Some({
          command: SetLinkTarget(reference.target),
          target: reference.target,
          reference_style: reference.reference_style,
          definition_text: "",
        })
      }
    None =>
      if markdown_editor_is_image_source(text) {
        Some({
          command: SetImageTarget(text),
          target: text,
          reference_style: false,
          definition_text: "",
        })
      } else if markdown_editor_is_autolink_target(text) {
        Some({
          command: SetLinkTarget(text),
          target: text,
          reference_style: false,
          definition_text: "",
        })
      } else {
        None
      }
  }
}

///|
priv struct MarkdownEditorPastedReferenceTarget {
  target : String
  image : Bool
  reference_style : Bool
}

///|
priv struct MarkdownEditorPastedReferenceDefinition {
  label : String
  target : String
  definition_text : String
}

///|
fn markdown_editor_pasted_reference_definition(
  text : String,
) -> MarkdownEditorPastedReferenceDefinition? {
  if text.contains("\n") {
    return None
  }
  let line : MarkdownLine = {
    text,
    start: 0,
    end: markdown_editor_text_length(text),
  }
  match markdown_editor_reference_definition_line_target_range(line) {
    Some((label, target_range)) => {
      if label.has_prefix("^") {
        return None
      }
      Some({
        label,
        target: markdown_editor_substring(
          text,
          target_range.start,
          target_range.end,
        ),
        definition_text: text,
      })
    }
    None => None
  }
}

///|
fn markdown_editor_pasted_reference_target(
  text : String,
) -> MarkdownEditorPastedReferenceTarget? {
  if text.contains("\n") {
    return None
  }
  let chars = text.to_array()
  let (image, label_start) = if chars.length() >= 4 &&
    chars[0] == '!' &&
    chars[1] == '[' {
    (true, 2)
  } else if chars.length() >= 3 && chars[0] == '[' {
    (false, 1)
  } else {
    return None
  }
  let close = match
    markdown_editor_find_unescaped_char(chars, label_start, ']') {
    Some(index) => index
    None => return None
  }
  if close + 1 == chars.length() {
    let target = markdown_editor_markdown_reference_label_token(
      String::from_array(chars[label_start:close]),
    )
    if target == "" {
      return None
    }
    return Some({ target, image, reference_style: true })
  }
  if chars[close + 1] == '[' {
    let reference_start = close + 2
    let reference_close = match
      markdown_editor_find_unescaped_char(chars, reference_start, ']') {
      Some(index) => index
      None => return None
    }
    if reference_close != chars.length() - 1 {
      return None
    }
    let explicit = markdown_editor_markdown_reference_label_token(
      String::from_array(chars[reference_start:reference_close]),
    )
    let target = if explicit == "" {
      markdown_editor_markdown_reference_label_token(
        String::from_array(chars[label_start:close]),
      )
    } else {
      explicit
    }
    if target == "" {
      return None
    }
    return Some({ target, image, reference_style: true })
  }
  if close + 2 >= chars.length() ||
    chars[close + 1] != '(' ||
    chars[chars.length() - 1] != ')' ||
    markdown_editor_char_is_escaped(chars, chars.length() - 1) {
    return None
  }
  let target = markdown_editor_markdown_reference_target_token(
    String::from_array(chars[close + 2:chars.length() - 1]),
  )
  if target == "" {
    return None
  }
  if image && !markdown_editor_is_image_source(target) {
    return None
  }
  Some({ target, image, reference_style: false })
}

///|
fn markdown_editor_markdown_reference_target_token(raw : String) -> String {
  let text = raw.trim().to_owned()
  if text == "" || text.contains("\n") {
    return ""
  }
  let chars = text.to_array()
  if chars[0] == '<' {
    match markdown_editor_find_unescaped_char(chars, 1, '>') {
      Some(close) =>
        if close == 1 {
          ""
        } else {
          String::from_array(chars[1:close])
        }
      None => ""
    }
  } else {
    let token : Array[Char] = []
    let mut index = 0
    while index < chars.length() && chars[index] != ' ' && chars[index] != '\t' {
      token.push(chars[index])
      index = index + 1
    }
    String::from_array(token)
  }
}

///|
fn markdown_editor_markdown_reference_label_token(raw : String) -> String {
  let text = raw.trim().to_owned()
  if text == "" || text.contains("\n") {
    ""
  } else {
    text
  }
}

///|
fn markdown_editor_paste_reference_label_over_selection(
  source : String,
  range : @core.TextRange,
  paste : MarkdownEditorPasteReferenceCommand,
) -> RichTextInputTransform? {
  let image = match paste.command {
    SetImageTarget(_) => true
    _ => false
  }
  let selection : MarkdownEditorSelection = {
    caret: range.end,
    selection: Some(range),
  }
  let context = if image {
    markdown_editor_image_context(source, selection)
  } else {
    markdown_editor_link_context(source, selection)
  }
  match context {
    Some(context) =>
      Some(
        markdown_editor_reference_label_transform(
          source,
          context.range,
          context.bounds.open_start,
          markdown_editor_reference_bounds_full_end(context.bounds),
          paste.target,
          paste.definition_text,
          image~,
        ),
      )
    None => {
      let normalized = range.normalized()
      Some(
        markdown_editor_reference_label_transform(
          source,
          normalized,
          normalized.start,
          normalized.end,
          paste.target,
          paste.definition_text,
          image~,
        ),
      )
    }
  }
}

///|
fn markdown_editor_reference_label_transform(
  source : String,
  visible_range : @core.TextRange,
  replace_start : Int,
  replace_end : Int,
  label : String,
  definition_text : String,
  image~ : Bool,
) -> RichTextInputTransform {
  let source_length = markdown_editor_text_length(source)
  let start = markdown_editor_clamp_int(replace_start, 0, source_length)
  let end = markdown_editor_clamp_int(replace_end, start, source_length)
  let visible_start = markdown_editor_clamp_int(visible_range.start, start, end)
  let visible_end = markdown_editor_clamp_int(
    visible_range.end,
    visible_start,
    end,
  )
  let selected = markdown_editor_substring(source, visible_start, visible_end)
  let prefix = if image { "![" } else { "[" }
  let inserted = prefix + selected + "][" + label + "]"
  let next_selection = @core.TextRange::new(
    start=start + markdown_editor_text_length(prefix),
    end=start +
      markdown_editor_text_length(prefix) +
      markdown_editor_text_length(selected),
  )
  let base_text = markdown_editor_substring(source, 0, start) +
    inserted +
    markdown_editor_substring(source, end, source_length)
  let text = markdown_editor_append_pasted_reference_definition(
    base_text, source, label, definition_text,
  )
  markdown_editor_transform_result(
    text~,
    caret=next_selection.end,
    selection=Some(next_selection),
  )
}

///|
fn markdown_editor_append_pasted_reference_definition(
  text : String,
  original_source : String,
  label : String,
  definition_text : String,
) -> String {
  if definition_text == "" ||
    markdown_editor_reference_definition_target_range(original_source, label)
    is Some(_) {
    text
  } else {
    text +
    markdown_editor_reference_definition_append_prefix(text) +
    definition_text
  }
}

///|
fn markdown_editor_reference_bounds_full_end(
  bounds : MarkdownLinkBounds,
) -> Int {
  markdown_editor_max_int(bounds.close_start, bounds.target_end) + 1
}

///|
fn markdown_editor_find_unescaped_char(
  chars : Array[Char],
  start : Int,
  target : Char,
) -> Int? {
  let mut index = start
  while index < chars.length() {
    if chars[index] == target && !markdown_editor_char_is_escaped(chars, index) {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn markdown_editor_char_is_escaped(chars : Array[Char], index : Int) -> Bool {
  let mut slash_count = 0
  let mut cursor = index - 1
  while cursor >= 0 && chars[cursor] == '\\' {
    slash_count = slash_count + 1
    cursor = cursor - 1
  }
  slash_count % 2 == 1
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
fn markdown_editor_is_autolink_target(text : String) -> Bool {
  markdown_editor_is_plain_url(text) || markdown_editor_is_plain_email(text)
}

///|
fn markdown_editor_is_plain_email(text : String) -> Bool {
  if text == "" ||
    text.contains("\n") ||
    text.contains(" ") ||
    text.contains("<") ||
    text.contains(">") {
    return false
  }
  let chars = text.to_array()
  let mut at_index = -1
  for index in 0..<chars.length() {
    if chars[index] == '@' {
      if at_index >= 0 {
        return false
      }
      at_index = index
    }
  }
  if at_index <= 0 || at_index + 1 >= chars.length() {
    return false
  }
  let local_name = String::from_array(chars[:at_index])
  let domain = String::from_array(chars[at_index + 1:])
  markdown_editor_email_part_supported(local_name, local_part=true) &&
  markdown_editor_email_part_supported(domain, local_part=false) &&
  markdown_editor_email_domain_has_dot(domain)
}

///|
fn markdown_editor_email_part_supported(
  text : String,
  local_part~ : Bool,
) -> Bool {
  if text == "" || text.has_prefix(".") || text.has_suffix(".") {
    return false
  }
  let chars = text.to_array()
  let mut previous_dot = false
  for ch in chars {
    if ch == '.' {
      if previous_dot {
        return false
      }
      previous_dot = true
    } else if markdown_editor_email_char_supported(ch, local_part~) {
      previous_dot = false
    } else {
      return false
    }
  }
  true
}

///|
fn markdown_editor_email_char_supported(ch : Char, local_part~ : Bool) -> Bool {
  markdown_editor_ascii_word_char(ch) ||
  ch == '-' ||
  (local_part && (ch == '+' || ch == '%'))
}

///|
fn markdown_editor_email_domain_has_dot(domain : String) -> Bool {
  let chars = domain.to_array()
  for index in 1..<(chars.length() - 1) {
    if chars[index] == '.' {
      return true
    }
  }
  false
}
