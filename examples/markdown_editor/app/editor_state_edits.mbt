///|
fn MarkdownEditorApp::clear_history(self : MarkdownEditorApp) -> Unit {
  self.undo_stack = []
  self.redo_stack = []
}

///|
fn MarkdownEditorApp::replace_document_source(
  self : MarkdownEditorApp,
  source : String,
  reason? : MarkdownEditReason = ReplaceEdit,
) -> Unit {
  let previous = self.document_session
  // A whole-source swap is a fresh document, not an edit: the shell parse
  // builds the session in one linear scan and blocks materialize on demand
  // (the apply() fallback would eagerly re-parse everything).
  self.document_session = previous.replace_source(source, reason~)
  self.document = source
  self.refresh_find_matches_if_visible()
}

///|
fn MarkdownEditorApp::apply_editor_transaction(
  self : MarkdownEditorApp,
  transaction : MarkdownEditTransaction,
) -> Unit {
  let anchor = self.editor_scroll
  let session = self.document_session
  let next = @moui_richtext.markdown_editor_probe_capture(
    "app.session.apply",
    fn() { session.apply(transaction) },
  )
  self.document_session = next
  self.document = next.source()
  @moui_richtext.markdown_editor_probe_capture(
    "app.refresh_find",
    fn() { self.refresh_find_matches_if_visible() },
  )
  self.selection = {
    caret: transaction.caret,
    selection: transaction.selection,
  }
  self.editor_scroll = anchor
  @moui_richtext.markdown_editor_probe_capture(
    "app.sync",
    fn() { self.sync_target_inputs() },
  )
  @moui_richtext.markdown_editor_probe_capture(
    "app.center",
    fn() { self.maybe_center_typewriter_selection() },
  )
}

///|
fn MarkdownEditorApp::apply_command_to_selection(
  self : MarkdownEditorApp,
  command : MarkdownEditorCommand,
) -> Unit {
  let before = self.pre_edit_state()
  let result = markdown_editor_apply_command_at(
    before.source,
    command,
    Some(before.selection),
  )
  if result.source == before.source &&
    result.selection == before.selection.selection &&
    result.caret == before.selection.caret {
    return
  }
  self.document_session = self.document_session.apply(
    MarkdownEditTransaction::from_edit_result(
      before.source,
      result,
      reason=CommandEdit,
    ),
  )
  self.record_edit_history(before~)
  self.document = result.source
  self.refresh_find_matches_if_visible()
  self.selection = { caret: result.caret, selection: result.selection }
  self.selection_engaged = true
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::apply_text_transform(
  self : MarkdownEditorApp,
  transform : @moui_richtext.RichTextInputTransform,
) -> Unit {
  let before = self.pre_edit_state()
  if transform.text == before.source &&
    transform.selection == before.selection.selection &&
    transform.caret == before.selection.caret {
    return
  }
  self.document_session = self.document_session.apply(
    MarkdownEditTransaction::from_input_transform(before.source, transform),
  )
  self.record_edit_history(before~)
  self.document = transform.text
  self.refresh_find_matches_if_visible()
  self.selection = { caret: transform.caret, selection: transform.selection }
  self.selection_engaged = true
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::shift_current_lines(
  self : MarkdownEditorApp,
  indent~ : Bool,
) -> Unit {
  let selection = self.selection
  if indent {
    self.apply_text_transform(
      markdown_editor_indent_lines(
        self.document,
        selection.caret,
        selection.selection,
      ),
    )
  } else {
    match
      markdown_editor_outdent_lines(
        self.document,
        selection.caret,
        selection.selection,
      ) {
      Some(transform) => self.apply_text_transform(transform)
      None => ()
    }
  }
}

///|
fn MarkdownEditorApp::insert_hard_break(self : MarkdownEditorApp) -> Unit {
  let selection = self.selection
  match
    markdown_editor_insert_hard_break(
      self.document,
      selection.caret,
      selection.selection,
    ) {
    Some(transform) => self.apply_text_transform(transform)
    None => ()
  }
}

///|
fn MarkdownEditorApp::undo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=true)
}

///|
fn MarkdownEditorApp::redo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=false)
}

///|
fn MarkdownEditorApp::set_selection(
  self : MarkdownEditorApp,
  caret : Int,
  selection : @text.TextRange?,
) -> Unit {
  self.selection = { caret, selection }
  self.selection_engaged = true
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::apply_link_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetLinkTarget(self.link_target))
}

///|
fn MarkdownEditorApp::apply_image_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetImageTarget(self.image_target))
}

///|
fn MarkdownEditorApp::apply_footnote_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetFootnoteText(self.footnote_text))
}

///|
fn MarkdownEditorApp::apply_html_block_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetHtmlBlockText(self.html_block_text))
}

///|
fn MarkdownEditorApp::apply_format_palette_action(
  self : MarkdownEditorApp,
  action : String,
) -> Unit {
  if self.apply_named_editor_action(action) {
    self.reset_format_palette()
  }
}

///|
fn MarkdownEditorApp::apply_first_format_palette_action(
  self : MarkdownEditorApp,
) -> Unit {
  let items = markdown_editor_format_palette_filtered_items(
    self.format_palette_query,
  )
  if items.length() > 0 {
    self.apply_format_palette_action(items[0].action)
  }
}

///|
fn MarkdownEditorApp::apply_named_editor_action(
  self : MarkdownEditorApp,
  action : String,
) -> Bool {
  if action == "source-preview" {
    self.toggle_source_preview()
    true
  } else if action == "source-mode" {
    self.toggle_source_mode()
    true
  } else if action == "outline" {
    self.toggle_outline()
    true
  } else if action == "files" {
    self.toggle_file_sidebar()
    true
  } else if action == "document-info" {
    self.toggle_document_info()
    true
  } else if action == "focus-mode" {
    self.toggle_focus_mode()
    true
  } else if action == "typewriter-mode" {
    self.toggle_typewriter_mode()
    true
  } else if action == "zen-mode" {
    self.toggle_zen_mode()
    true
  } else if action == "format-palette" {
    self.toggle_format_palette()
    true
  } else if action == "look" {
    self.cycle_writing_appearance()
    true
  } else if action == "look-paper" {
    self.set_writing_appearance(PaperAppearance)
    true
  } else if action == "look-warm" {
    self.set_writing_appearance(WarmAppearance)
    true
  } else if action == "look-wide" {
    self.set_writing_appearance(WideAppearance)
    true
  } else if action == "find" {
    self.update_in_place(ToggleFind)
    true
  } else if action == "new-document" {
    self.new_document()
    true
  } else if action == "open-document" {
    self.update_in_place(OpenDocument)
    true
  } else if action == "save" {
    self.update_in_place(SaveDocument)
    true
  } else if action == "save-as" {
    self.update_in_place(SaveDocumentAs)
    true
  } else if action == "undo" {
    self.update_in_place(Undo)
    true
  } else if action == "redo" {
    self.update_in_place(Redo)
    true
  } else if action == "clipboard-import" {
    self.update_in_place(ImportFromClipboard)
    true
  } else if action == "clipboard-export" {
    self.update_in_place(ExportToClipboard)
    true
  } else if action == "html-export" {
    self.update_in_place(ExportHtmlToClipboard)
    true
  } else if action == "toggle-task" {
    self.update_in_place(ToggleCurrentTask)
    true
  } else if action == "indent-lines" {
    self.update_in_place(IndentLines)
    true
  } else if action == "outdent-lines" {
    self.update_in_place(OutdentLines)
    true
  } else if action == "open-target" {
    self.update_in_place(OpenTarget)
    true
  } else if action == "next-heading" {
    self.update_in_place(JumpToNextHeading)
    true
  } else if action == "previous-heading" {
    self.update_in_place(JumpToPreviousHeading)
    true
  } else if action == "image-center" {
    self.update_in_place(ToggleImageCenter)
    true
  } else {
    match markdown_editor_command_from_action(action) {
      Some(command) => {
        self.apply_command_to_selection(command)
        true
      }
      None => false
    }
  }
}

///|
/// Pre-edit document/selection snapshot captured transiently by each
/// command path; once the command lands, `record_edit_history` converts
/// it into a delta entry and the snapshot is dropped.
priv struct MarkdownEditorPreEdit {
  source : String
  selection : MarkdownEditorSelection
}

///|
fn MarkdownEditorApp::pre_edit_state(
  self : MarkdownEditorApp,
) -> MarkdownEditorPreEdit {
  { source: self.document_session.source(), selection: self.selection }
}

///|
/// Push the completed command as a delta undo entry (and clear the
/// redo branch), diffing the captured pre-edit source against the
/// current document.
fn MarkdownEditorApp::record_edit_history(
  self : MarkdownEditorApp,
  before~ : MarkdownEditorPreEdit,
) -> Unit {
  let (start, removed, inserted) = @core.text_history_delta(
    before.source,
    self.document_session.source(),
  )
  self.push_undo({
    delta: {
      start,
      before: removed,
      after: inserted,
      caret: before.selection.caret,
      selection: before.selection.selection,
    },
    selection: before.selection,
  })
  self.redo_stack = []
}

///|
fn MarkdownEditorApp::push_undo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.undo_stack
  stack.push(entry)
  self.undo_stack = stack
}

///|
fn MarkdownEditorApp::push_redo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.redo_stack
  stack.push(entry)
  self.redo_stack = stack
}

///|
fn MarkdownEditorApp::restore_history(
  self : MarkdownEditorApp,
  undo~ : Bool,
) -> Bool {
  let stack = if undo { self.undo_stack } else { self.redo_stack }
  if stack.length() == 0 {
    return false
  }
  let entry = stack[stack.length() - 1]
  ignore(stack.pop())
  if undo {
    self.undo_stack = stack
  } else {
    self.redo_stack = stack
  }
  let current = self.pre_edit_state()
  let restored_source = if undo {
    entry.delta.undo_text(current.source)
  } else {
    entry.delta.redo_text(current.source)
  }
  // The opposite stack receives the same delta with the position this
  // restore leaves behind, so stepping back forward is exact.
  let repositioned : MarkdownEditorHistoryEntry = {
    delta: {
      ..entry.delta,
      caret: current.selection.caret,
      selection: current.selection.selection,
    },
    selection: current.selection,
  }
  if undo {
    self.push_redo(repositioned)
  } else {
    self.push_undo(repositioned)
  }
  self.replace_document_source(restored_source, reason=ReplaceEdit)
  self.selection = entry.selection
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
  true
}

///|
fn MarkdownEditorApp::toggle_task_at(
  self : MarkdownEditorApp,
  content_offset : Int,
) -> Unit {
  match markdown_editor_toggle_task_at(self.document, content_offset) {
    Some(result) => {
      let before = self.pre_edit_state()
      self.document_session = self.document_session.apply(
        MarkdownEditTransaction::from_edit_result(
          self.document,
          result,
          reason=ToggleTaskEdit,
        ),
      )
      self.record_edit_history(before~)

      self.document = result.source
      self.refresh_find_matches_if_visible()
      self.selection = { caret: result.caret, selection: result.selection }
      self.sync_target_inputs()
      self.maybe_center_typewriter_selection()
    }
    None => ()
  }
}

///|
fn MarkdownEditorApp::toggle_current_task(self : MarkdownEditorApp) -> Unit {
  match markdown_editor_toggle_current_task(self.document, self.selection) {
    Some(result) => {
      let before = self.pre_edit_state()
      self.document_session = self.document_session.apply(
        MarkdownEditTransaction::from_edit_result(
          self.document,
          result,
          reason=ToggleTaskEdit,
        ),
      )
      self.record_edit_history(before~)

      self.document = result.source
      self.refresh_find_matches_if_visible()
      self.selection = { caret: result.caret, selection: result.selection }
      self.sync_target_inputs()
      self.maybe_center_typewriter_selection()
    }
    None => ()
  }
}

///|
/// Search source for first line containing `![` (image markdown),
/// then wrap or unwrap it with `<center>` tags depending on `wrap`.
fn markdown_editor_toggle_image_center(source : String, wrap : Bool) -> String {
  let lines = source.split("\n").to_array()
  let line_views : Array[String] = []
  for line in lines {
    line_views.push(line.to_owned())
  }
  let mut img_idx : Int? = None
  for i in 0..<line_views.length() {
    if line_views[i].contains("![") {
      img_idx = Some(i)
      break
    }
  }
  match img_idx {
    Some(idx) =>
      if wrap {
        let result = StringBuilder()
        for j in 0..<idx {
          if j > 0 {
            result.write_char('\n')
          }
          result.write_string(line_views[j])
        }
        if idx > 0 {
          result.write_char('\n')
        }
        result.write_string("<center>")
        result.write_char('\n')
        result.write_string(line_views[idx])
        result.write_char('\n')
        result.write_string("</center>")
        for j in (idx + 1)..<line_views.length() {
          result.write_char('\n')
          result.write_string(line_views[j])
        }
        result.to_string()
      } else {
        // Unwrap: need <center> and </center> around
        if idx > 0 && idx + 1 < line_views.length() {
          let prev_chars = line_views[idx - 1].to_array()
          let next_chars = line_views[idx + 1].to_array()
          if String::from_array(prev_chars).trim().to_owned() == "<center>" &&
            String::from_array(next_chars).trim().to_owned() == "</center>" {
            let result = StringBuilder()
            for j in 0..<(idx - 1) {
              if j > 0 {
                result.write_char('\n')
              }
              result.write_string(line_views[j])
            }
            if idx - 1 > 0 {
              result.write_char('\n')
            }
            result.write_string(line_views[idx])
            for j in (idx + 2)..<line_views.length() {
              result.write_char('\n')
              result.write_string(line_views[j])
            }
            return result.to_string()
          }
        }
        source
      }
    None => source
  }
}

///|
