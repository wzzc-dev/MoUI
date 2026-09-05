///|
/// Block structure and text store handed to the transform chain so the
/// code-block lookups resolve against the session's current blocks instead
/// of re-parsing (and re-line-splitting) the whole source on every
/// keystroke. Callers must pass the blocks of exactly the text handed to
/// the chain (the pre-edit session state).
pub(all) struct MarkdownEditorInputContext {
  blocks : Array[MarkdownEditorBlock]
  store : MarkdownDocumentTextStore
}

///|
pub fn markdown_editor_transform_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
  context? : MarkdownEditorInputContext? = None,
) -> RichTextInputTransform? {
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
    let current : MarkdownEditorSelection = { caret, selection }
    let range = markdown_editor_current_line_range_from_chars(chars, current)
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
  if markdown_editor_code_block_at_content_offset(
    source, caret, selection, context=context,
  ) is Some(block) {
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
      source,
      caret,
      selection,
      context=context,
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
  let chars = source.to_array()
  let current : MarkdownEditorSelection = { caret, selection }
  let range = markdown_editor_current_line_range_from_chars(chars, current)
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

///|
fn markdown_editor_is_multiline_input(input : String) -> Bool {
  input != "\n" && input.contains("\n")
}

///|
