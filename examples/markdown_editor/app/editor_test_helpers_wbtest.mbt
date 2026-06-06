///|
fn MarkdownEditorApp::document(self : MarkdownEditorApp) -> String {
  self.document.get()
}

///|
fn MarkdownEditorApp::set_document(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.load_document(text, path="")
}

///|
fn MarkdownEditorApp::load_document_for_test(
  self : MarkdownEditorApp,
  text : String,
  path~ : String,
) -> Unit {
  self.load_document(text, path~)
}

///|
fn MarkdownEditorApp::edit_document(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.set_document_from_input(text)
}

///|
fn MarkdownEditorApp::clear(self : MarkdownEditorApp) -> Unit {
  self.new_document()
}

///|
fn MarkdownEditorApp::apply_action(
  self : MarkdownEditorApp,
  action : String,
) -> Unit {
  if action == "source-preview" {
    self.toggle_source_preview()
  } else if action == "outline" {
    self.toggle_outline()
  } else if action == "find" {
    self.toggle_find()
  } else if action == "new-document" {
    self.new_document()
  } else if action == "open-document" {
    ignore(self.update(OpenDocument))
  } else if action == "save" {
    ignore(self.update(SaveDocument))
  } else if action == "save-as" {
    ignore(self.update(SaveDocumentAs))
  } else if action == "clipboard-import" {
    ignore(self.update(ImportFromClipboard))
  } else if action == "clipboard-export" {
    ignore(self.update(ExportToClipboard))
  } else if action == "toggle-task" {
    ignore(self.update(ToggleCurrentTask))
  } else if action == "indent-lines" {
    ignore(self.update(IndentLines))
  } else if action == "outdent-lines" {
    ignore(self.update(OutdentLines))
  } else if action == "open-target" {
    ignore(self.update(OpenTarget))
  } else if action == "next-heading" {
    ignore(self.update(JumpToNextHeading))
  } else if action == "previous-heading" {
    ignore(self.update(JumpToPreviousHeading))
  } else {
    match markdown_command_from_action(action) {
      Some(command) => self.apply_command_to_selection(command)
      None => ()
    }
  }
}

///|
fn MarkdownEditorApp::source_preview_visible(self : MarkdownEditorApp) -> Bool {
  self.source_preview_visible.get()
}

///|
fn MarkdownEditorApp::outline_visible(self : MarkdownEditorApp) -> Bool {
  self.outline_visible.get()
}

///|
fn MarkdownEditorApp::find_visible(self : MarkdownEditorApp) -> Bool {
  self.find_visible.get()
}

///|
fn MarkdownEditorApp::find_query(self : MarkdownEditorApp) -> String {
  self.find_query.get()
}

///|
fn MarkdownEditorApp::replace_text(self : MarkdownEditorApp) -> String {
  self.replace_text.get()
}

///|
fn MarkdownEditorApp::transfer_status_label_for_test(
  self : MarkdownEditorApp,
) -> String {
  self.transfer_status_label()
}

///|
fn MarkdownEditorApp::import_clipboard_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_clipboard_import(services)
}

///|
fn MarkdownEditorApp::export_clipboard_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_clipboard_export(services)
}

///|
fn MarkdownEditorApp::save_as_dialog_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_file_save_as(services)
}

///|
fn MarkdownEditorApp::open_target_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_open_target(services)
}

///|
fn MarkdownEditorApp::set_find_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.find_query.set(query)
}

///|
fn MarkdownEditorApp::update_find_query_for_test(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  ignore(self.update(UpdateFindQuery(query)))
}

///|
fn MarkdownEditorApp::set_replace_text(
  self : MarkdownEditorApp,
  replacement : String,
) -> Unit {
  self.replace_text.set(replacement)
}

///|
fn MarkdownEditorApp::find_next_for_test(self : MarkdownEditorApp) -> Unit {
  self.find_next()
}

///|
fn MarkdownEditorApp::find_previous_for_test(self : MarkdownEditorApp) -> Unit {
  self.find_previous()
}

///|
fn MarkdownEditorApp::replace_current_find_match_for_test(
  self : MarkdownEditorApp,
) -> Unit {
  self.replace_current_find_match()
}

///|
fn MarkdownEditorApp::replace_all_find_matches_for_test(
  self : MarkdownEditorApp,
) -> Unit {
  self.replace_all_find_matches()
}

///|
fn MarkdownEditorApp::set_outline_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.outline_visible.set(visible)
}

///|
fn MarkdownEditorApp::set_source_preview_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.source_preview_visible.set(visible)
}

///|
fn MarkdownEditorApp::can_undo(self : MarkdownEditorApp) -> Bool {
  self.undo_stack.get().length() > 0
}

///|
fn MarkdownEditorApp::can_redo(self : MarkdownEditorApp) -> Bool {
  self.redo_stack.get().length() > 0
}

///|
fn MarkdownEditorApp::set_link_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.link_target.set(target)
}

///|
fn MarkdownEditorApp::set_image_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.image_target.set(target)
}

///|
fn MarkdownEditorApp::set_footnote_text(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.footnote_text.set(text)
}

///|
fn MarkdownEditorApp::set_html_block_text(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.html_block_text.set(text)
}

///|
fn MarkdownEditorApp::link_target(self : MarkdownEditorApp) -> String {
  self.link_target.get()
}

///|
fn MarkdownEditorApp::image_target(self : MarkdownEditorApp) -> String {
  self.image_target.get()
}

///|
fn MarkdownEditorApp::footnote_text(self : MarkdownEditorApp) -> String {
  self.footnote_text.get()
}

///|
fn MarkdownEditorApp::html_block_text(self : MarkdownEditorApp) -> String {
  self.html_block_text.get()
}

///|
fn MarkdownEditorApp::target_kind(
  self : MarkdownEditorApp,
) -> MarkdownEditorTargetKind {
  self.target_kind.get()
}

///|
fn MarkdownEditorApp::block_label(self : MarkdownEditorApp) -> String {
  self.block_label.get()
}

///|
fn MarkdownEditorApp::selection_caret(self : MarkdownEditorApp) -> Int {
  self.selection.get().caret
}

///|
fn MarkdownEditorApp::editor_scroll_y(self : MarkdownEditorApp) -> Double {
  self.editor_scroll.offset().y
}

///|
fn MarkdownEditorApp::document_path(self : MarkdownEditorApp) -> String {
  self.document_path.get()
}

///|
fn MarkdownEditorApp::saved_document(self : MarkdownEditorApp) -> String {
  self.saved_document.get()
}

///|
fn MarkdownEditorApp::dirty(self : MarkdownEditorApp) -> Bool {
  self.is_dirty()
}

///|
fn MarkdownEditorApp::mark_saved_for_test(self : MarkdownEditorApp) -> Unit {
  self.mark_document_saved()
}

///|
fn MarkdownEditorApp::save_as_for_test(
  self : MarkdownEditorApp,
  path : String,
) -> Unit {
  self.save_document_as(path)
}

///|
fn MarkdownEditorApp::document_status_label_for_test(
  self : MarkdownEditorApp,
) -> String {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  self.document_status_label(
    snapshot,
    self.block_label.get(),
    self.selection.get(),
  )
}

///|
fn MarkdownEditorApp::jump_to_outline_for_test(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  self.jump_to_outline(source_start)
}

///|
fn markdown_editor_apply_command(
  source : String,
  command : MarkdownEditorCommand,
) -> String {
  markdown_editor_apply_command_at(source, command, None).source
}

///|
fn markdown_to_rich_text(text : String) -> @core.RichTextDocument {
  let blocks : Array[@core.RichTextBlock] = []
  let base = @core.FontSpec::new()
  for block in parse_markdown(text) {
    blocks.push(markdown_block_to_rich_text(block, base))
  }
  @core.RichTextDocument::new(blocks~)
}

///|
fn markdown_command_from_action(action : String) -> MarkdownEditorCommand? {
  if action == "bold" {
    Some(Bold)
  } else if action == "italic" {
    Some(Italic)
  } else if action == "code" {
    Some(Code)
  } else if action == "strike" {
    Some(Strikethrough)
  } else if action == "link" {
    Some(Link)
  } else if action == "link-target" {
    Some(SetLinkTarget("https://moui.dev"))
  } else if action == "image" {
    Some(Image)
  } else if action == "image-target" {
    Some(SetImageTarget("assets/image.png"))
  } else if action == "code-language" {
    Some(SetCodeLanguage("moonbit"))
  } else if action == "paragraph" {
    Some(Paragraph)
  } else if action == "h1" {
    Some(Heading(1))
  } else if action == "h2" {
    Some(Heading(2))
  } else if action == "h3" {
    Some(Heading(3))
  } else if action == "h4" {
    Some(Heading(4))
  } else if action == "h5" {
    Some(Heading(5))
  } else if action == "h6" {
    Some(Heading(6))
  } else if action == "ul" {
    Some(BulletList)
  } else if action == "task" {
    Some(TaskList)
  } else if action == "ol" {
    Some(OrderedList)
  } else if action == "quote" {
    Some(Quote)
  } else if action == "rule" {
    Some(HorizontalRule)
  } else if action == "table" {
    Some(Table)
  } else if action == "table-row" {
    Some(InsertTableRow)
  } else if action == "table-column" {
    Some(InsertTableColumn)
  } else if action == "table-row-delete" {
    Some(DeleteTableRow)
  } else if action == "table-column-delete" {
    Some(DeleteTableColumn)
  } else if action == "table-align-left" {
    Some(SetTableColumnAlignment(Some(@core.TextAlign::TextStart)))
  } else if action == "table-align-center" {
    Some(SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)))
  } else if action == "table-align-right" {
    Some(SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)))
  } else if action == "table-align-auto" {
    Some(SetTableColumnAlignment(None))
  } else if action == "codeblock" {
    Some(CodeBlock)
  } else if action == "duplicate-block" {
    Some(DuplicateBlock)
  } else if action == "move-block-up" {
    Some(MoveBlockUp)
  } else if action == "move-block-down" {
    Some(MoveBlockDown)
  } else {
    None
  }
}
