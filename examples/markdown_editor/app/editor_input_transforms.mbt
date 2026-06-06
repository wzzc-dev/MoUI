///|
fn markdown_editor_transform_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  match
    markdown_editor_paste_footnote_definition(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match
    markdown_editor_paste_reference_over_selection(
      source, caret, selection, input,
    ) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_paste_autolink(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_paste_html_block(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match
    markdown_editor_skip_closing_delimiter(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_pair_delimiter_input(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_wrap_selection_input(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_table_cell_text_input(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match
    markdown_editor_paste_markdown_table_as_table(
      source, caret, selection, input,
    ) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_paste_tsv_as_table(source, caret, selection, input) {
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
    match
      markdown_editor_complete_quoted_code_fence_on_enter(
        chars, range, line, caret,
      ) {
      Some(transform) => return Some(transform)
      None => ()
    }
  }
  if markdown_editor_code_block_at_content_offset(source, caret, selection)
    is Some(block) {
    if input == "\n" {
      match
        markdown_editor_exit_empty_code_block_on_enter(source, block, caret) {
        Some(transform) => return Some(transform)
        None => ()
      }
      return Some(markdown_editor_code_block_enter(source, caret))
    }
    return None
  }
  match
    markdown_editor_quoted_code_block_at_content_offset(
      source, caret, selection,
    ) {
    Some(block) =>
      if input == "\n" {
        match
          markdown_editor_exit_empty_quoted_code_block_on_enter(
            source, block, caret,
          ) {
          Some(transform) => return Some(transform)
          None => ()
        }
        return Some(
          markdown_editor_quoted_code_block_enter(source, block, caret),
        )
      } else {
        return None
      }
    None => ()
  }
  if input == "\u{0008}" {
    match
      markdown_editor_backspace_empty_trailing_table_row(
        source, caret, selection,
      ) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match
      markdown_editor_backspace_empty_continuation(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match
      markdown_editor_backspace_empty_delimiter_pair(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match
      markdown_editor_backspace_empty_inline_marker_pair(
        source, caret, selection,
      ) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match markdown_editor_backspace_marker(source, caret, selection) {
      Some(transform) => return Some(transform)
      None =>
        return markdown_editor_backspace_merge_block(source, caret, selection)
    }
  }
  if input == "\u{007f}" {
    match
      markdown_editor_delete_empty_trailing_table_row(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match markdown_editor_delete_empty_continuation(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match
      markdown_editor_delete_empty_delimiter_pair(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match
      markdown_editor_delete_empty_inline_marker_pair(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match markdown_editor_delete_marker(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match markdown_editor_delete_quoted_inner_marker(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    return markdown_editor_delete_merge_block(source, caret, selection)
  }
  if input == " " {
    match
      markdown_editor_complete_setext_heading_on_space(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
    match markdown_editor_complete_rule_on_space(source, caret, selection) {
      Some(transform) => return Some(transform)
      None => ()
    }
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
  match markdown_editor_insert_table_row_on_enter(source, caret, selection) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match
    markdown_editor_complete_setext_heading_on_enter(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_complete_rule_on_enter(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_exit_empty_heading(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_exit_empty_continuation(chars, range, line) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match
    markdown_editor_complete_autolink_on_enter(source, caret, selection, line) {
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
fn markdown_editor_paste_footnote_definition(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
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
  let editor_selection = { caret, selection }
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
      let chars = source.to_array()
      let normalized = range.normalized()
      let start = markdown_editor_clamp_int(normalized.start, 0, chars.length())
      let end = markdown_editor_clamp_int(normalized.end, start, chars.length())
      let selected = String::from_array(chars[start:end])
      let marker = "[^" + definition.label + "]"
      let text = String::from_array(chars[:start]) +
        selected +
        marker +
        String::from_array(chars[end:])
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
  let chars = source.to_array()
  for line in markdown_editor_lines(source) {
    match markdown_editor_footnote_definition_line_text_range(line) {
      Some((definition_label, range)) =>
        if markdown_reference_label_key(definition_label) == key {
          let next_source = String::from_array(chars[:range.start]) +
            text +
            String::from_array(chars[range.end:])
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
) -> @core.RichTextInputTransform? {
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
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let insert = target.leading + "<" + target.target + ">" + target.trailing
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
) -> @core.RichTextInputTransform? {
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
struct MarkdownEditorAutolinkTarget {
  leading : String
  target : String
  trailing : String
} derive(Eq, Debug)

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
) -> @core.RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let html = match markdown_editor_pasted_html_block(input) {
    Some(html) => html
    None => return None
  }
  let editor_selection = { caret, selection }
  if markdown_editor_active_selection(selection) is None {
    match markdown_editor_html_block_at_selection(source, editor_selection) {
      Some(block) => {
        let chars = source.to_array()
        return Some(
          markdown_editor_transform_result(
            text=String::from_array(chars[:block.source_range.start]) +
              html +
              String::from_array(chars[block.source_range.end:]),
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
) -> @core.RichTextInputTransform? {
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
  let editor_selection = { caret, selection }
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      if paste.reference_style {
        return markdown_editor_paste_reference_label_over_selection(
          source, range, paste,
        )
      }
      let result = markdown_editor_set_reference_target(
        source,
        { caret: range.end, selection: Some(range) },
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
) -> @core.RichTextInputTransform? {
  let image = match paste.command {
    SetImageTarget(_) => true
    _ => false
  }
  let selection = { caret: range.end, selection: Some(range) }
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
) -> @core.RichTextInputTransform {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(replace_start, 0, chars.length())
  let end = markdown_editor_clamp_int(replace_end, start, chars.length())
  let visible_start = markdown_editor_clamp_int(visible_range.start, start, end)
  let visible_end = markdown_editor_clamp_int(
    visible_range.end,
    visible_start,
    end,
  )
  let selected = String::from_array(chars[visible_start:visible_end])
  let prefix = if image { "![" } else { "[" }
  let inserted = prefix + selected + "][" + label + "]"
  let next_selection = @core.TextRange::new(
    start=start + markdown_editor_text_length(prefix),
    end=start +
      markdown_editor_text_length(prefix) +
      markdown_editor_text_length(selected),
  )
  let base_text = String::from_array(chars[:start]) +
    inserted +
    String::from_array(chars[end:])
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

///|
fn markdown_editor_wrap_selection_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let marker = match input {
    "**" => "**"
    "__" => "__"
    "~~" => "~~"
    "`" => "`"
    "*" => "*"
    "_" => "_"
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
    None => markdown_editor_pair_inline_marker_input(source, marker, caret)
  }
}

///|
fn markdown_editor_pair_inline_marker_input(
  source : String,
  marker : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
  if marker == "" || marker == "*" || marker == "_" {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret]) +
        marker +
        marker +
        String::from_array(chars[caret:]),
      caret=caret + markdown_editor_text_length(marker),
    ),
  )
}

///|
fn markdown_editor_pair_delimiter_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let close = match input {
    "(" => ")"
    "[" => "]"
    "{" => "}"
    "\"" => "\""
    "'" =>
      if markdown_editor_apostrophe_in_word(source, caret, selection) {
        return None
      } else {
        "'"
      }
    "`" => "`"
    _ => return None
  }
  let chars = source.to_array()
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      let normalized = range.normalized()
      let text = String::from_array(chars[:normalized.start]) +
        input +
        String::from_array(chars[normalized.start:normalized.end]) +
        close +
        String::from_array(chars[normalized.end:])
      Some(
        markdown_editor_transform_result(
          text~,
          caret=normalized.end + markdown_editor_text_length(input),
          selection=Some(
            @core.TextRange::new(
              start=normalized.start + markdown_editor_text_length(input),
              end=normalized.end + markdown_editor_text_length(input),
            ),
          ),
        ),
      )
    }
    None => {
      let caret = markdown_editor_clamp_int(caret, 0, chars.length())
      let insert = input + close
      Some(
        markdown_editor_transform_result(
          text=String::from_array(chars[:caret]) +
            insert +
            String::from_array(chars[caret:]),
          caret=caret + markdown_editor_text_length(input),
        ),
      )
    }
  }
}

///|
fn markdown_editor_skip_closing_delimiter(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let close = match input {
    "**" => "**"
    "__" => "__"
    "~~" => "~~"
    "_" => "_"
    ")" => ")"
    "]" => "]"
    "}" => "}"
    "\"" => "\""
    "'" => "'"
    "`" => "`"
    _ => return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if close == "_" {
    match markdown_editor_find_inline_opening_marker(chars, caret, close) {
      Some(open_start) =>
        if !markdown_editor_inline_marker_pair_supported(
            chars,
            open_start,
            markdown_editor_text_length(close),
            caret,
            close,
          ) {
          return None
        }
      None => return None
    }
  }
  if markdown_editor_source_has_marker(chars, caret, close) {
    Some(
      markdown_editor_transform_result(
        text=source,
        caret=caret + markdown_editor_text_length(close),
      ),
    )
  } else {
    None
  }
}

///|
fn markdown_editor_apostrophe_in_word(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Bool {
  if markdown_editor_active_selection(selection) is Some(_) {
    return false
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  caret > 0 &&
  caret < chars.length() &&
  markdown_editor_ascii_word_char(chars[caret - 1]) &&
  markdown_editor_ascii_word_char(chars[caret])
}

///|
fn markdown_editor_ascii_word_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_'
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
fn markdown_editor_table_cell_at_text_offset(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Bool {
  let anchor = match markdown_editor_active_selection(selection) {
    Some(range) => range.normalized().start
    None => caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      anchor < block.source_range.start ||
      anchor > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    if markdown_editor_table_cell_index_at(cells, anchor) is Some(_) {
      return true
    }
  }
  false
}

///|
fn markdown_editor_hard_break_continuation_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let indent_text = String::from_array(chars[:indent])
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    let nested = String::from_array(chars[indent + 2:])
    indent_text + "> " + markdown_editor_hard_break_continuation_prefix(nested)
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
    indent_text + markdown_editor_spaces(6)
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    indent_text + markdown_editor_spaces(2)
  } else {
    let ordered_end = markdown_editor_ordered_marker_length(chars)
    if ordered_end > indent {
      indent_text + markdown_editor_spaces(ordered_end - indent)
    } else {
      indent_text
    }
  }
}

///|
fn markdown_editor_spaces(count : Int) -> String {
  let chars : Array[Char] = []
  let mut index = 0
  while index < count {
    chars.push(' ')
    index = index + 1
  }
  String::from_array(chars)
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
  let chars = trimmed.to_array()
  let explicit_pipe_table = chars.length() > 1 &&
    chars[0] == '|' &&
    chars[chars.length() - 1] == '|'
  for cell in cells {
    if !explicit_pipe_table && cell.trim().to_owned() == "" {
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
fn markdown_editor_is_multiline_input(input : String) -> Bool {
  input != "\n" && input.contains("\n")
}

///|
fn markdown_editor_backspace_empty_delimiter_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if caret <= 0 || caret >= chars.length() {
    return None
  }
  if !markdown_editor_empty_delimiter_pair_at(chars, caret) {
    return None
  }
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret - 1]) +
        String::from_array(chars[caret + 1:]),
      caret=caret - 1,
    ),
  )
}

///|
fn markdown_editor_empty_delimiter_pair_at(
  chars : Array[Char],
  caret : Int,
) -> Bool {
  if caret <= 0 || caret >= chars.length() {
    return false
  }
  let open = chars[caret - 1].to_int()
  let close = chars[caret].to_int()
  match open {
    40 => close == 41 // ()
    91 => close == 93 // []
    123 => close == 125 // {}
    34 => close == 34 // ""
    39 => close == 39 // ''
    96 => close == 96 // ``
    _ => false
  }
}

///|
fn markdown_editor_delete_empty_delimiter_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if caret + 1 >= chars.length() {
    return None
  }
  if !markdown_editor_empty_delimiter_pair_at(chars, caret + 1) {
    return None
  }
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret]) +
        String::from_array(chars[caret + 2:]),
      caret~,
    ),
  )
}

///|
fn markdown_editor_backspace_empty_inline_marker_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for marker in ["**", "__", "~~", "`"] {
    let marker_length = markdown_editor_text_length(marker)
    if caret >= marker_length &&
      markdown_editor_empty_inline_marker_pair_at(
        chars,
        caret - marker_length,
        marker,
      ) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars,
          caret - marker_length,
          marker_length,
        ),
      )
    }
    if caret >= marker_length * 2 &&
      markdown_editor_empty_inline_marker_pair_at(
        chars,
        caret - marker_length * 2,
        marker,
      ) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars,
          caret - marker_length * 2,
          marker_length,
        ),
      )
    }
  }
  None
}

///|
fn markdown_editor_delete_empty_inline_marker_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for marker in ["**", "__", "~~", "`"] {
    let marker_length = markdown_editor_text_length(marker)
    if markdown_editor_empty_inline_marker_pair_at(chars, caret, marker) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars, caret, marker_length,
        ),
      )
    }
    if caret >= marker_length &&
      markdown_editor_empty_inline_marker_pair_at(
        chars,
        caret - marker_length,
        marker,
      ) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars,
          caret - marker_length,
          marker_length,
        ),
      )
    }
  }
  None
}

///|
fn markdown_editor_empty_inline_marker_pair_at(
  chars : Array[Char],
  open_start : Int,
  marker : String,
) -> Bool {
  let marker_length = markdown_editor_text_length(marker)
  open_start >= 0 &&
  markdown_editor_source_has_marker(chars, open_start, marker) &&
  markdown_editor_source_has_marker(chars, open_start + marker_length, marker)
}

///|
fn markdown_editor_remove_empty_inline_marker_pair(
  chars : Array[Char],
  open_start : Int,
  marker_length : Int,
) -> @core.RichTextInputTransform {
  markdown_editor_transform_result(
    text=String::from_array(chars[:open_start]) +
      String::from_array(chars[open_start + marker_length * 2:]),
    caret=open_start,
  )
}

///|
fn markdown_editor_table_cell_text_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  match
    markdown_editor_table_cell_matrix_paste(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  if input == "\t" ||
    input == "\n" ||
    markdown_editor_active_selection(selection) is Some(_) ||
    (!input.contains("\n") && !input.contains("|")) {
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
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(_) => {
        let insert = markdown_editor_table_cell_safe_input(input)
        if insert == input {
          return None
        }
        return Some(
          markdown_editor_transform_result(
            text=String::from_array(chars[:caret]) +
              insert +
              String::from_array(chars[caret:]),
            caret=caret + markdown_editor_text_length(insert),
          ),
        )
      }
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_table_cell_matrix_paste(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if input == "\t" || markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let paste = match markdown_editor_table_matrix_paste(input) {
    Some(paste) => paste
    None => return None
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
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return Some(
          markdown_editor_apply_table_paste_grid(
            source,
            block,
            cells[index],
            paste.grid,
            paste.alignments,
            caret,
          ),
        )
      None => return None
    }
  }
  None
}

///|
priv struct MarkdownEditorTableMatrixPaste {
  grid : Array[Array[String]]
  alignments : Array[@core.TextAlign?]
}

///|
fn markdown_editor_table_matrix_paste(
  input : String,
) -> MarkdownEditorTableMatrixPaste? {
  if input.contains("\t") {
    let grid = markdown_editor_table_paste_grid(input)
    if grid.length() == 0 ||
      markdown_editor_table_paste_grid_column_count(grid) <= 1 {
      None
    } else {
      Some({ grid, alignments: [] })
    }
  } else {
    match markdown_editor_markdown_table_paste(input) {
      Some(table) => Some({ grid: table.grid, alignments: table.alignments })
      None => None
    }
  }
}

///|
fn markdown_editor_table_paste_grid(input : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for line in markdown_editor_paste_lines(input) {
    let row : Array[String] = []
    for cell in markdown_editor_split_tsv_cells(line) {
      row.push(markdown_editor_table_cell_safe_input(cell))
    }
    rows.push(row)
  }
  rows
}

///|
fn markdown_editor_split_tsv_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = line.to_array()
  let current : Array[Char] = []
  let mut index = 0
  while index <= chars.length() {
    if index == chars.length() || chars[index] == '\t' {
      cells.push(String::from_array(current))
      current.clear()
    } else {
      current.push(chars[index])
    }
    index = index + 1
  }
  cells
}

///|
fn markdown_editor_table_paste_grid_column_count(
  grid : Array[Array[String]],
) -> Int {
  let mut count = 0
  for row in grid {
    if row.length() > count {
      count = row.length()
    }
  }
  count
}

///|
fn markdown_editor_paste_tsv_as_table(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if input == "\t" ||
    !input.contains("\t") ||
    markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let grid = markdown_editor_table_paste_grid(input)
  if grid.length() == 0 ||
    markdown_editor_table_paste_grid_column_count(grid) <= 1 {
    return None
  }
  let table = markdown_editor_table_text_from_paste_grid(grid)
  markdown_editor_paste_table_text_as_block(source, caret, selection, table)
}

///|
fn markdown_editor_paste_markdown_table_as_table(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> @core.RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  match markdown_editor_markdown_table_paste(input) {
    Some(table) =>
      markdown_editor_paste_table_text_as_block(
        source,
        caret,
        selection,
        table.table_text,
      )
    None => None
  }
}

///|
fn markdown_editor_paste_table_text_as_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  table : String,
) -> @core.RichTextInputTransform? {
  markdown_editor_paste_block_text_as_block(source, caret, selection, table)
}

///|
fn markdown_editor_paste_block_text_as_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  block_text : String,
) -> @core.RichTextInputTransform? {
  let chars = source.to_array()
  let range = match markdown_editor_active_selection(selection) {
    Some(active) => active.normalized()
    None => {
      let caret = markdown_editor_clamp_int(caret, 0, chars.length())
      @core.TextRange::new(start=caret, end=caret)
    }
  }
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let prefix = markdown_editor_block_insert_prefix(chars, start)
  let suffix = markdown_editor_block_insert_suffix(chars, end)
  let text = String::from_array(chars[:start]) +
    prefix +
    block_text +
    suffix +
    String::from_array(chars[end:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=start +
        markdown_editor_text_length(prefix) +
        markdown_editor_text_length(block_text),
    ),
  )
}

///|
struct MarkdownEditorPastedMarkdownTable {
  grid : Array[Array[String]]
  alignments : Array[@core.TextAlign?]
  table_text : String
} derive(Eq, Debug)

///|
fn markdown_editor_markdown_table_paste(
  input : String,
) -> MarkdownEditorPastedMarkdownTable? {
  if !input.contains("|") || input.contains("\t") {
    return None
  }
  let source_lines = markdown_editor_paste_lines(input)
  let table_lines = markdown_editor_trim_blank_table_paste_lines(source_lines)
  if table_lines.length() < 2 ||
    !markdown_editor_table_header_candidate(table_lines[0]) ||
    !markdown_editor_table_separator_line(table_lines[1]) {
    return None
  }
  let header = markdown_editor_markdown_table_paste_cells(table_lines[0])
  if header.length() <= 1 {
    return None
  }
  let separator_cells = markdown_editor_split_table_cells(table_lines[1])
  if separator_cells.length() != header.length() {
    return None
  }
  let grid : Array[Array[String]] = [header]
  for index in 2..<table_lines.length() {
    let line = table_lines[index]
    if !markdown_editor_table_body_line(line) ||
      markdown_editor_table_separator_line(line) {
      return None
    }
    grid.push(markdown_editor_markdown_table_paste_cells(line))
  }
  Some({
    grid,
    alignments: markdown_table_alignments_for_separator(table_lines[1]),
    table_text: markdown_join_lines(table_lines),
  })
}

///|
fn markdown_editor_trim_blank_table_paste_lines(
  lines : Array[String],
) -> Array[String] {
  let mut start = 0
  let mut end = lines.length()
  while start < end && markdown_editor_blank_source_line(lines[start]) {
    start = start + 1
  }
  while end > start && markdown_editor_blank_source_line(lines[end - 1]) {
    end = end - 1
  }
  let trimmed : Array[String] = []
  for index in start..<end {
    trimmed.push(lines[index].trim().to_owned())
  }
  trimmed
}

///|
fn markdown_editor_markdown_table_paste_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  for cell in markdown_editor_split_table_cells(line) {
    cells.push(cell.trim().to_owned())
  }
  cells
}

///|
fn markdown_editor_table_text_from_paste_grid(
  grid : Array[Array[String]],
) -> String {
  let column_count = markdown_editor_table_paste_grid_column_count(grid)
  let lines : Array[String] = []
  lines.push(
    markdown_editor_table_paste_join_cells(
      markdown_editor_table_paste_padded_row(grid[0], column_count),
    ),
  )
  let separators : Array[String] = []
  for _ in 0..<column_count {
    separators.push("---")
  }
  lines.push(markdown_editor_table_paste_join_cells(separators))
  if grid.length() == 1 {
    let empty : Array[String] = []
    for _ in 0..<column_count {
      empty.push("")
    }
    lines.push(markdown_editor_table_paste_join_cells(empty))
  } else {
    for row_index in 1..<grid.length() {
      lines.push(
        markdown_editor_table_paste_join_cells(
          markdown_editor_table_paste_padded_row(grid[row_index], column_count),
        ),
      )
    }
  }
  markdown_join_lines(lines)
}

///|
fn markdown_editor_table_paste_padded_row(
  row : Array[String],
  column_count : Int,
) -> Array[String] {
  let cells : Array[String] = []
  for cell in row {
    cells.push(cell)
  }
  while cells.length() < column_count {
    cells.push("")
  }
  cells
}

///|
fn markdown_editor_block_insert_prefix(
  chars : Array[Char],
  start : Int,
) -> String {
  if start <= 0 {
    ""
  } else if chars[start - 1] == '\n' {
    if start >= 2 && chars[start - 2] == '\n' {
      ""
    } else {
      "\n"
    }
  } else {
    "\n\n"
  }
}

///|
fn markdown_editor_block_insert_suffix(
  chars : Array[Char],
  end : Int,
) -> String {
  if end >= chars.length() {
    ""
  } else if chars[end] == '\n' {
    if end + 1 < chars.length() && chars[end + 1] == '\n' {
      ""
    } else {
      "\n"
    }
  } else {
    "\n\n"
  }
}

///|
fn markdown_editor_apply_table_paste_grid(
  source : String,
  block : MarkdownEditorBlock,
  current : MarkdownEditorTableCellRange,
  grid : Array[Array[String]],
  alignments : Array[@core.TextAlign?],
  caret : Int,
) -> @core.RichTextInputTransform {
  let table_lines = markdown_editor_source_lines_for_range(
    source,
    block.source_range,
  )
  let existing_rows = markdown_editor_max_int(0, table_lines.length() - 1)
  let grid_columns = markdown_editor_table_paste_grid_column_count(grid)
  let column_count = markdown_editor_max_int(
    markdown_editor_table_column_count(
      markdown_editor_table_cells_for_block(source, block),
    ),
    current.column + grid_columns,
  )
  let row_count = markdown_editor_max_int(
    existing_rows,
    current.row + grid.length(),
  )
  let lines : Array[String] = []
  let first = markdown_editor_table_paste_row_line(
    table_lines, 0, column_count, current, grid, caret, source,
  )
  lines.push(first)
  lines.push(
    markdown_editor_table_paste_separator_line(
      table_lines, column_count, current, alignments,
    ),
  )
  for row in 1..<row_count {
    lines.push(
      markdown_editor_table_paste_row_line(
        table_lines, row, column_count, current, grid, caret, source,
      ),
    )
  }
  let table_text = markdown_join_lines(lines)
  let text = markdown_editor_substring(source, 0, block.source_range.start) +
    table_text +
    markdown_editor_substring(
      source,
      block.source_range.end,
      markdown_editor_text_length(source),
    )
  let target = markdown_editor_table_paste_last_target(current, grid)
  markdown_editor_transform_result(
    text~,
    caret=markdown_editor_table_paste_caret(
      table_text,
      block.source_range.start,
      target.row,
      target.column,
    ),
  )
}

///|
fn markdown_editor_source_lines_for_range(
  source : String,
  range : MarkdownSourceRange,
) -> Array[String] {
  let lines : Array[String] = []
  for line in markdown_editor_lines(source) {
    if line.start >= range.start && line.end <= range.end {
      lines.push(line.text)
    }
  }
  lines
}

///|
fn markdown_editor_table_paste_row_line(
  table_lines : Array[String],
  row : Int,
  column_count : Int,
  current : MarkdownEditorTableCellRange,
  grid : Array[Array[String]],
  caret : Int,
  source : String,
) -> String {
  let line_index = if row == 0 { 0 } else { row + 1 }
  let base = if line_index < table_lines.length() {
    table_lines[line_index]
  } else {
    ""
  }
  let cells = markdown_editor_table_paste_cells(base, column_count)
  let paste_row = row - current.row
  if paste_row >= 0 && paste_row < grid.length() {
    let pasted = grid[paste_row]
    for paste_column in 0..<pasted.length() {
      let column = current.column + paste_column
      if column < cells.length() {
        cells[column] = if paste_row == 0 && paste_column == 0 {
          markdown_editor_insert_table_paste_cell(
            markdown_editor_table_paste_cell_at(cells, column),
            pasted[paste_column],
            source,
            current,
            caret,
          )
        } else {
          pasted[paste_column]
        }
      }
    }
  }
  markdown_editor_table_paste_join_cells(cells)
}

///|
fn markdown_editor_table_paste_cells(
  line : String,
  column_count : Int,
) -> Array[String] {
  let cells : Array[String] = []
  if line != "" {
    for cell in markdown_editor_split_table_cells(line) {
      cells.push(cell.trim().to_owned())
    }
  }
  while cells.length() < column_count {
    cells.push("")
  }
  cells
}

///|
fn markdown_editor_table_paste_cell_at(
  cells : Array[String],
  column : Int,
) -> String {
  if column < cells.length() {
    cells[column]
  } else {
    ""
  }
}

///|
fn markdown_editor_insert_table_paste_cell(
  original : String,
  insert : String,
  source : String,
  current : MarkdownEditorTableCellRange,
  caret : Int,
) -> String {
  let content = markdown_editor_substring(
    source,
    current.content_start,
    current.content_end,
  )
  let local_offset = markdown_editor_clamp_int(
    caret - current.content_start,
    0,
    markdown_editor_text_length(content),
  )
  if content == original {
    markdown_editor_substring(content, 0, local_offset) +
    insert +
    markdown_editor_substring(
      content,
      local_offset,
      markdown_editor_text_length(content),
    )
  } else {
    markdown_editor_substring(original, 0, local_offset) +
    insert +
    markdown_editor_substring(
      original,
      local_offset,
      markdown_editor_text_length(original),
    )
  }
}

///|
fn markdown_editor_table_paste_separator_line(
  table_lines : Array[String],
  column_count : Int,
  current : MarkdownEditorTableCellRange,
  alignments : Array[@core.TextAlign?],
) -> String {
  let base = if table_lines.length() > 1 { table_lines[1] } else { "" }
  let cells = markdown_editor_table_paste_cells(base, column_count)
  for index in 0..<cells.length() {
    if cells[index] == "" {
      cells[index] = "---"
    }
  }
  for paste_column in 0..<alignments.length() {
    let column = current.column + paste_column
    if column >= 0 && column < cells.length() {
      cells[column] = markdown_editor_table_alignment_marker(
        alignments[paste_column],
      )
    }
  }
  markdown_editor_table_paste_join_cells(cells)
}

///|
fn markdown_editor_table_paste_join_cells(cells : Array[String]) -> String {
  "| " + cells.join(" | ") + " |"
}

///|
priv struct MarkdownEditorTablePasteTarget {
  row : Int
  column : Int
}

///|
fn markdown_editor_table_paste_last_target(
  current : MarkdownEditorTableCellRange,
  grid : Array[Array[String]],
) -> MarkdownEditorTablePasteTarget {
  if grid.length() == 0 {
    return { row: current.row, column: current.column }
  }
  let row = current.row + markdown_editor_max_int(0, grid.length() - 1)
  let last = grid[grid.length() - 1]
  let column = current.column + markdown_editor_max_int(0, last.length() - 1)
  { row, column }
}

///|
fn markdown_editor_table_paste_caret(
  table_text : String,
  table_start : Int,
  row : Int,
  column : Int,
) -> Int {
  let lines = markdown_editor_lines(table_text)
  let line_index = if row == 0 { 0 } else { row + 1 }
  if line_index >= lines.length() {
    return table_start + markdown_editor_text_length(table_text)
  }
  let line = lines[line_index]
  let cells = markdown_editor_table_cells_for_line(
    {
      text: line.text,
      start: table_start + line.start,
      end: table_start + line.end,
    },
    row,
  )
  for cell in cells {
    if cell.column == column {
      return cell.content_end
    }
  }
  table_start + line.end
}

///|
fn markdown_editor_table_cell_safe_input(input : String) -> String {
  let chars = input.to_array()
  let out : Array[Char] = []
  let mut index = 0
  let mut previous_was_space = false
  while index < chars.length() {
    let ch = chars[index]
    if ch == '\n' || ch == '\r' {
      if !previous_was_space {
        out.push(' ')
        previous_was_space = true
      }
    } else if ch == '|' && markdown_editor_table_pipe_is_separator(chars, index) {
      out.push('\\')
      out.push('|')
      previous_was_space = false
    } else {
      out.push(ch)
      previous_was_space = ch == ' ' || ch == '\t'
    }
    index = index + 1
  }
  String::from_array(out)
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
  match
    markdown_editor_backspace_quoted_inner_marker(chars, range, line, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
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
fn markdown_editor_backspace_quoted_inner_marker(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> @core.RichTextInputTransform? {
  let context_length = markdown_editor_block_command_context_prefix_length(line)
  let context_prefix = markdown_editor_substring(line, 0, context_length)
  if !markdown_editor_block_command_context_has_quote(context_prefix) {
    return None
  }
  let marker_length = markdown_editor_marker_prefix_length_after_context(
    line, context_length,
  )
  if marker_length <= context_length || caret != range.start + marker_length {
    return None
  }
  let line_chars = line.to_array()
  let text = String::from_array(chars[:range.start]) +
    String::from_array(line_chars[:context_length]) +
    String::from_array(line_chars[marker_length:]) +
    String::from_array(chars[range.end:])
  Some(
    markdown_editor_transform_result(text~, caret=range.start + context_length),
  )
}

///|
fn markdown_editor_delete_marker(
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
  let marker_length = markdown_editor_marker_prefix_length(line)
  let indent_length = markdown_editor_line_indent_prefix_length(line)
  if marker_length == 0 || caret != range.start + indent_length {
    return None
  }
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
fn markdown_editor_delete_quoted_inner_marker(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let current = { caret, selection }
  let range = markdown_editor_current_line_range(source, current)
  let line = String::from_array(chars[range.start:range.end])
  let context_length = markdown_editor_block_command_context_prefix_length(line)
  let context_prefix = markdown_editor_substring(line, 0, context_length)
  if !markdown_editor_block_command_context_has_quote(context_prefix) {
    return None
  }
  let marker_length = markdown_editor_marker_prefix_length_after_context(
    line, context_length,
  )
  if marker_length <= context_length || caret != range.start + context_length {
    return None
  }
  let line_chars = line.to_array()
  let text = String::from_array(chars[:range.start]) +
    String::from_array(line_chars[:context_length]) +
    String::from_array(line_chars[marker_length:]) +
    String::from_array(chars[range.end:])
  Some(
    markdown_editor_transform_result(text~, caret=range.start + context_length),
  )
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
  if markdown_editor_blank_source_line(current_line) {
    let text = String::from_array(chars[:previous_end]) +
      String::from_array(chars[range.end:])
    return Some(markdown_editor_transform_result(text~, caret=previous_end))
  }
  let previous_content = markdown_editor_strip_merge_block_marker(previous_line)
  let current_content = markdown_editor_strip_merge_block_marker(current_line)
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
  match markdown_editor_delete_inline_marker(source, chars, caret) {
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
  if markdown_editor_blank_source_line(next_line) {
    let text = String::from_array(chars[:range.end]) +
      String::from_array(chars[next_end:])
    return Some(markdown_editor_transform_result(text~, caret=range.end))
  }
  let current_content = markdown_editor_strip_merge_block_marker(current_line)
  let next_content = markdown_editor_strip_merge_block_marker(next_line)
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
fn markdown_editor_blank_source_line(line : String) -> Bool {
  line.trim().to_owned() == ""
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
      markdown_editor_merge_block_marker_prefix(first_line)
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
fn markdown_editor_strip_merge_block_marker(line : String) -> String {
  let offset = markdown_editor_merge_block_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[offset:])
}

///|
fn markdown_editor_merge_block_marker_prefix(line : String) -> String {
  let marker_length = markdown_editor_merge_block_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[:marker_length])
}

///|
fn markdown_editor_merge_block_marker_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    let nested = String::from_array(chars[indent + 2:])
    indent + 2 + markdown_editor_merge_block_marker_prefix_length(nested)
  } else {
    markdown_editor_marker_prefix_length(line)
  }
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
  match markdown_editor_backspace_footnote_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_backspace_autolink_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_backspace_reference_marker(source, chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  for marker in ["**", "__", "~~", "`", "*", "_"] {
    let marker_length = markdown_editor_text_length(marker)
    if caret >= marker_length &&
      markdown_editor_source_has_marker(chars, caret - marker_length, marker) {
      match
        markdown_editor_find_inline_opening_marker(
          chars,
          caret - marker_length,
          marker,
        ) {
        Some(open_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars,
              open_start,
              marker_length,
              caret - marker_length,
              marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars,
                open_start,
                marker_length,
                caret - marker_length,
              ),
            )
          }
        None => ()
      }
      match markdown_editor_find_inline_closing_marker(chars, caret, marker) {
        Some(close_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars,
              caret - marker_length,
              marker_length,
              close_start,
              marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars,
                caret - marker_length,
                marker_length,
                close_start,
              ),
            )
          }
        None => ()
      }
    }
  }
  None
}

///|
fn markdown_editor_delete_inline_marker(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  match markdown_editor_delete_footnote_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_delete_autolink_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_delete_reference_marker(source, chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  for marker in ["**", "__", "~~", "`", "*", "_"] {
    let marker_length = markdown_editor_text_length(marker)
    if markdown_editor_source_has_marker(chars, caret, marker) {
      match
        markdown_editor_find_inline_closing_marker(
          chars,
          caret + marker_length,
          marker,
        ) {
        Some(close_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars, caret, marker_length, close_start, marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars, caret, marker_length, close_start,
              ),
            )
          }
        None => ()
      }
      match markdown_editor_find_inline_opening_marker(chars, caret, marker) {
        Some(open_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars, open_start, marker_length, caret, marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars, open_start, marker_length, caret,
              ),
            )
          }
        None => ()
      }
    }
  }
  None
}

///|
fn markdown_editor_backspace_footnote_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret <= 0 {
    return None
  }
  if caret >= 2 && chars[caret - 2] == '[' && chars[caret - 1] == '^' {
    match markdown_editor_footnote_close_after(chars, caret) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 2,
            caret,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  if chars[caret - 1] == ']' {
    match markdown_editor_footnote_open_before(chars, caret - 1) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 2,
            caret - 1,
            caret - 1,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_delete_footnote_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret >= chars.length() {
    return None
  }
  if chars[caret] == '[' &&
    caret + 1 < chars.length() &&
    chars[caret + 1] == '^' {
    match markdown_editor_footnote_close_after(chars, caret + 2) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret,
            caret + 2,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  if chars[caret] == ']' {
    match markdown_editor_footnote_open_before(chars, caret) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 2,
            caret,
            caret,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_footnote_close_after(
  chars : Array[Char],
  content_start : Int,
) -> Int? {
  let mut close_start = content_start
  while close_start < chars.length() &&
        chars[close_start] != ']' &&
        chars[close_start] != '\n' {
    close_start = close_start + 1
  }
  if close_start <= content_start ||
    close_start >= chars.length() ||
    chars[close_start] != ']' {
    None
  } else {
    Some(close_start)
  }
}

///|
fn markdown_editor_footnote_open_before(
  chars : Array[Char],
  close_start : Int,
) -> Int? {
  if close_start >= chars.length() || chars[close_start] != ']' {
    return None
  }
  let mut content_start = close_start
  while content_start > 0 &&
        chars[content_start - 1] != '[' &&
        chars[content_start - 1] != '\n' {
    content_start = content_start - 1
  }
  if content_start <= 0 || chars[content_start - 1] != '[' {
    return None
  }
  let open_start = content_start - 1
  if content_start >= close_start ||
    content_start >= chars.length() ||
    chars[content_start] != '^' ||
    content_start + 1 >= close_start {
    None
  } else {
    Some(open_start)
  }
}

///|
fn markdown_editor_backspace_autolink_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret <= 0 {
    return None
  }
  if chars[caret - 1] == '>' {
    match markdown_editor_autolink_open_before(chars, caret - 1) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 1,
            caret - 1,
            caret - 1,
          ),
        )
      None => ()
    }
  }
  if chars[caret - 1] == '<' {
    match markdown_editor_autolink_close_after(chars, caret) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 1,
            caret,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_delete_autolink_marker(
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret >= chars.length() {
    return None
  }
  if chars[caret] == '<' {
    match markdown_editor_autolink_close_after(chars, caret + 1) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret,
            caret + 1,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  if chars[caret] == '>' {
    match markdown_editor_autolink_open_before(chars, caret) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 1,
            caret,
            caret,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_autolink_close_after(
  chars : Array[Char],
  content_start : Int,
) -> Int? {
  let mut close = content_start
  while close < chars.length() && chars[close] != '>' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() || chars[close] != '>' {
    return None
  }
  let target = String::from_array(chars[content_start:close])
  if markdown_editor_is_autolink_target(target) {
    Some(close)
  } else {
    None
  }
}

///|
fn markdown_editor_autolink_open_before(
  chars : Array[Char],
  close_start : Int,
) -> Int? {
  let mut open = close_start
  while open > 0 && chars[open - 1] != '<' && chars[open - 1] != '\n' {
    open = open - 1
  }
  if open <= 0 || chars[open - 1] != '<' {
    return None
  }
  let target = String::from_array(chars[open:close_start])
  if markdown_editor_is_autolink_target(target) {
    Some(open - 1)
  } else {
    None
  }
}

///|
fn markdown_editor_delete_reference_marker(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret >= chars.length() {
    return None
  }
  if chars[caret] == '[' ||
    (
      chars[caret] == '!' &&
      caret + 1 < chars.length() &&
      chars[caret + 1] == '['
    ) {
    let content_start = if chars[caret] == '!' { caret + 2 } else { caret + 1 }
    match markdown_editor_reference_close_after(source, chars, content_start) {
      Some(bounds) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            bounds.open_start,
            content_start,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      None => ()
    }
  }
  if chars[caret] != ']' {
    return None
  }
  match markdown_editor_reference_open_before(source, chars, caret) {
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
  source : String,
  chars : Array[Char],
  close_start : Int,
) -> MarkdownLinkBounds? {
  if close_start >= chars.length() || chars[close_start] != ']' {
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
  let content_start = bracket_start + 1
  let target = match
    markdown_editor_reference_marker_target_after(
      source, chars, close_start, content_start,
    ) {
    Some(target) => target
    None => return None
  }
  Some({
    open_start,
    close_start,
    target_start: target.start,
    target_end: target.end,
    definition_target_start: -1,
    definition_target_end: -1,
    reference_label: target.label,
  })
}

///|
fn markdown_editor_backspace_reference_marker(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> @core.RichTextInputTransform? {
  if caret > 0 {
    match
      markdown_editor_reference_bounds_full_end_before(source, chars, caret) {
      Some(bounds) => {
        let mut content_start = bounds.open_start + 1
        if chars[bounds.open_start] == '!' {
          content_start = bounds.open_start + 2
        }
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            bounds.open_start,
            content_start,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      }
      None => ()
    }
  }
  if caret >= 2 && chars[caret - 2] == '!' && chars[caret - 1] == '[' {
    match markdown_editor_reference_close_after(source, chars, caret) {
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
    match markdown_editor_reference_close_after(source, chars, caret) {
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
fn markdown_editor_reference_bounds_full_end_before(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> MarkdownLinkBounds? {
  if caret <= 0 {
    return None
  }
  let end = caret - 1
  if chars[end] == ')' {
    let mut open = end
    while open > 0 && chars[open - 1] != '(' && chars[open - 1] != '\n' {
      open = open - 1
    }
    if open <= 0 || chars[open - 1] != '(' {
      return None
    }
    let close_start = open - 2
    if close_start < 0 || chars[close_start] != ']' {
      return None
    }
    match markdown_editor_reference_open_before(source, chars, close_start) {
      Some(bounds) => if bounds.target_end == end { Some(bounds) } else { None }
      None => None
    }
  } else if chars[end] == ']' {
    let mut label_open = end
    while label_open > 0 &&
          chars[label_open - 1] != '[' &&
          chars[label_open - 1] != '\n' {
      label_open = label_open - 1
    }
    if label_open <= 0 || chars[label_open - 1] != '[' {
      return None
    }
    let close_start = if label_open >= 2 && chars[label_open - 2] == ']' {
      label_open - 2
    } else {
      end
    }
    match markdown_editor_reference_open_before(source, chars, close_start) {
      Some(bounds) => if bounds.target_end == end { Some(bounds) } else { None }
      None => None
    }
  } else {
    None
  }
}

///|
fn markdown_editor_reference_close_after(
  source : String,
  chars : Array[Char],
  content_start : Int,
) -> MarkdownLinkBounds? {
  let mut close_start = content_start
  while close_start < chars.length() &&
        chars[close_start] != ']' &&
        chars[close_start] != '\n' {
    close_start = close_start + 1
  }
  if close_start >= chars.length() || chars[close_start] != ']' {
    return None
  }
  let open_start = if content_start >= 2 &&
    chars[content_start - 2] == '!' &&
    chars[content_start - 1] == '[' {
    content_start - 2
  } else {
    content_start - 1
  }
  let target = match
    markdown_editor_reference_marker_target_after(
      source, chars, close_start, content_start,
    ) {
    Some(target) => target
    None => return None
  }
  Some({
    open_start,
    close_start,
    target_start: target.start,
    target_end: target.end,
    definition_target_start: -1,
    definition_target_end: -1,
    reference_label: target.label,
  })
}

///|
priv struct MarkdownEditorReferenceMarkerTarget {
  start : Int
  end : Int
  label : String
}

///|
fn markdown_editor_reference_marker_target_after(
  source : String,
  chars : Array[Char],
  close_start : Int,
  content_start : Int,
) -> MarkdownEditorReferenceMarkerTarget? {
  if close_start + 1 < chars.length() && chars[close_start + 1] == '(' {
    let mut target_end = close_start + 2
    while target_end < chars.length() &&
          chars[target_end] != ')' &&
          chars[target_end] != '\n' {
      target_end = target_end + 1
    }
    if target_end < chars.length() && chars[target_end] == ')' {
      Some({ start: close_start + 2, end: target_end, label: "" })
    } else {
      None
    }
  } else if close_start + 1 < chars.length() && chars[close_start + 1] == '[' {
    let mut target_end = close_start + 2
    while target_end < chars.length() &&
          chars[target_end] != ']' &&
          chars[target_end] != '\n' {
      target_end = target_end + 1
    }
    if target_end < chars.length() && chars[target_end] == ']' {
      Some({
        start: close_start + 2,
        end: target_end,
        label: String::from_array(chars[close_start + 2:target_end]),
      })
    } else {
      None
    }
  } else {
    let label = String::from_array(chars[content_start:close_start])
    if label == "" ||
      markdown_editor_reference_definition_target_range(source, label) is None {
      None
    } else {
      Some({ start: close_start, end: close_start, label })
    }
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
fn markdown_editor_inline_marker_pair_supported(
  chars : Array[Char],
  open_start : Int,
  marker_length : Int,
  close_start : Int,
  marker : String,
) -> Bool {
  if marker != "_" {
    return true
  }
  let before_open_is_word = open_start > 0 &&
    markdown_editor_ascii_word_char(chars[open_start - 1])
  let after_close = close_start + marker_length
  let after_close_is_word = after_close < chars.length() &&
    markdown_editor_ascii_word_char(chars[after_close])
  !before_open_is_word && !after_close_is_word
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
