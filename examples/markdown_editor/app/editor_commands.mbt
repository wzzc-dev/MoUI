///|
fn markdown_editor_apply_command_at(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection?,
) -> MarkdownEditorEditResult {
  let result = match command {
    Bold | Italic | Code | Strikethrough =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(range) =>
              markdown_editor_toggle_inline_range(
                source,
                range,
                markdown_editor_inline_marker(command),
              )
            None =>
              markdown_editor_toggle_inline_at_caret(
                source,
                selection.caret,
                command,
              )
          }
        None => markdown_editor_append_snippet(source, command)
      }
    Link | Image =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(range) =>
              if command == Image {
                markdown_editor_toggle_image_range(source, range)
              } else {
                markdown_editor_toggle_link_range(source, range)
              }
            None =>
              markdown_editor_toggle_reference_at_caret(
                source, selection, command,
              )
          }
        None => markdown_editor_append_snippet(source, command)
      }
    SetLinkTarget(target) | SetImageTarget(target) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_reference_target(
            source, selection, command, target,
          )
        None => markdown_editor_append_snippet(source, command)
      }
    SetCodeLanguage(language) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_code_language(source, selection, language)
        None => markdown_editor_append_snippet(source, command)
      }
    SetFootnoteText(text) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_footnote_text(source, selection, text)
        None => markdown_editor_append_snippet(source, command)
      }
    SetHtmlBlockText(text) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_html_block_text(source, selection, text)
        None => markdown_editor_append_snippet(source, command)
      }
    InsertTableRow =>
      match selection {
        Some(selection) => markdown_editor_insert_table_row(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    InsertTableColumn =>
      match selection {
        Some(selection) =>
          markdown_editor_insert_table_column(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    DeleteTableRow =>
      match selection {
        Some(selection) => markdown_editor_delete_table_row(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    DeleteTableColumn =>
      match selection {
        Some(selection) =>
          markdown_editor_delete_table_column(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    SetTableColumnAlignment(align) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_table_column_alignment(source, selection, align)
        None => markdown_editor_noop_result(source, selection)
      }
    InsertTableOfContents =>
      match selection {
        Some(selection) =>
          markdown_editor_insert_table_of_contents(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    InsertFrontMatter =>
      match selection {
        Some(_) => markdown_editor_insert_front_matter(source)
        None => markdown_editor_append_snippet(source, command)
      }
    DuplicateBlock =>
      match selection {
        Some(selection) =>
          markdown_editor_duplicate_current_block(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    MoveBlockUp =>
      match selection {
        Some(selection) =>
          markdown_editor_move_current_block(source, selection, up=true)
        None => markdown_editor_noop_result(source, selection)
      }
    MoveBlockDown =>
      match selection {
        Some(selection) =>
          markdown_editor_move_current_block(source, selection, up=false)
        None => markdown_editor_noop_result(source, selection)
      }
    Paragraph
    | Heading(_)
    | BulletList
    | TaskList
    | OrderedList
    | Quote
    | HorizontalRule
    | Table =>
      match selection {
        Some(selection) =>
          markdown_editor_transform_current_block(source, command, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    CodeBlock =>
      match selection {
        Some(selection) => markdown_editor_toggle_code_block(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
  }
  markdown_editor_normalize_ordered_edit_result(result)
}

///|
