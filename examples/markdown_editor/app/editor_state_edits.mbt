fn MarkdownEditorApp::clear_history(self : MarkdownEditorApp) -> Unit {
  self.undo_stack.set([])
  self.redo_stack.set([])
}

///|
fn MarkdownEditorApp::apply_command_to_selection(
  self : MarkdownEditorApp,
  command : MarkdownEditorCommand,
) -> Unit {
  let before = self.history_entry()
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
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(result.source)
  self.selection.set({ caret: result.caret, selection: result.selection })
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::apply_text_transform(
  self : MarkdownEditorApp,
  transform : @core.RichTextInputTransform,
) -> Unit {
  let before = self.history_entry()
  if transform.text == before.source &&
    transform.selection == before.selection.selection &&
    transform.caret == before.selection.caret {
    return
  }
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(transform.text)
  self.selection.set({ caret: transform.caret, selection: transform.selection })
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::shift_current_lines(
  self : MarkdownEditorApp,
  indent~ : Bool,
) -> Unit {
  let selection = self.selection.get()
  if indent {
    self.apply_text_transform(
      markdown_editor_indent_lines(
        self.document.get(),
        selection.caret,
        selection.selection,
      ),
    )
  } else {
    match
      markdown_editor_outdent_lines(
        self.document.get(),
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
  let selection = self.selection.get()
  match
    markdown_editor_insert_hard_break(
      self.document.get(),
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
  selection : @core.TextRange?,
) -> Unit {
  self.selection.set({ caret, selection })
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|

fn MarkdownEditorApp::set_document_from_input(
  self : MarkdownEditorApp,
  value : String,
) -> Unit {
  self.document.set(value)
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::apply_link_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetLinkTarget(self.link_target.get()))
}

///|
fn MarkdownEditorApp::apply_image_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetImageTarget(self.image_target.get()))
}

///|
fn MarkdownEditorApp::apply_footnote_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetFootnoteText(self.footnote_text.get()))
}

///|
fn MarkdownEditorApp::apply_html_block_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetHtmlBlockText(self.html_block_text.get()))
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
    self.format_palette_query.get(),
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
    self.toggle_find()
    true
  } else if action == "new-document" {
    self.new_document()
    true
  } else if action == "open-document" {
    ignore(self.update(OpenDocument))
    true
  } else if action == "save" {
    ignore(self.update(SaveDocument))
    true
  } else if action == "save-as" {
    ignore(self.update(SaveDocumentAs))
    true
  } else if action == "clipboard-import" {
    ignore(self.update(ImportFromClipboard))
    true
  } else if action == "clipboard-export" {
    ignore(self.update(ExportToClipboard))
    true
  } else if action == "html-export" {
    ignore(self.update(ExportHtmlToClipboard))
    true
  } else if action == "toggle-task" {
    ignore(self.update(ToggleCurrentTask))
    true
  } else if action == "indent-lines" {
    ignore(self.update(IndentLines))
    true
  } else if action == "outdent-lines" {
    ignore(self.update(OutdentLines))
    true
  } else if action == "open-target" {
    ignore(self.update(OpenTarget))
    true
  } else if action == "next-heading" {
    ignore(self.update(JumpToNextHeading))
    true
  } else if action == "previous-heading" {
    ignore(self.update(JumpToPreviousHeading))
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
fn MarkdownEditorApp::history_entry(
  self : MarkdownEditorApp,
) -> MarkdownEditorHistoryEntry {
  { source: self.document.get(), selection: self.selection.get() }
}

///|
fn MarkdownEditorApp::push_undo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.undo_stack.get()
  stack.push(entry)
  self.undo_stack.set(stack)
}

///|
fn MarkdownEditorApp::push_redo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.redo_stack.get()
  stack.push(entry)
  self.redo_stack.set(stack)
}

///|
fn MarkdownEditorApp::restore_history(
  self : MarkdownEditorApp,
  undo~ : Bool,
) -> Bool {
  let stack = if undo { self.undo_stack.get() } else { self.redo_stack.get() }
  if stack.length() == 0 {
    return false
  }
  let entry = stack[stack.length() - 1]
  ignore(stack.pop())
  if undo {
    self.undo_stack.set(stack)
    self.push_redo(self.history_entry())
  } else {
    self.redo_stack.set(stack)
    self.push_undo(self.history_entry())
  }
  self.document.set(entry.source)
  self.selection.set(entry.selection)
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
  true
}

///|

fn MarkdownEditorApp::toggle_task_at(
  self : MarkdownEditorApp,
  content_offset : Int,
) -> Unit {
  match markdown_editor_toggle_task_at(self.document.get(), content_offset) {
    Some(result) => {
      self.push_undo(self.history_entry())
      self.redo_stack.set([])
      self.document.set(result.source)
      self.selection.set({ caret: result.caret, selection: result.selection })
      self.sync_target_inputs()
      self.maybe_center_typewriter_selection()
    }
    None => ()
  }
}

///|
fn MarkdownEditorApp::toggle_current_task(self : MarkdownEditorApp) -> Unit {
  match
    markdown_editor_toggle_current_task(
      self.document.get(),
      self.selection.get(),
    ) {
    Some(result) => {
      self.push_undo(self.history_entry())
      self.redo_stack.set([])
      self.document.set(result.source)
      self.selection.set({ caret: result.caret, selection: result.selection })
      self.sync_target_inputs()
      self.maybe_center_typewriter_selection()
    }
    None => ()
  }
}

///|

