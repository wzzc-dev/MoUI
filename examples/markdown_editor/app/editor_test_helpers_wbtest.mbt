///|
fn MarkdownEditorApp::document(self : MarkdownEditorApp) -> String {
  self.document.get()
}

///|
fn MarkdownEditorApp::set_document(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.document.set(text)
  self.selection.set({ caret: 0, selection: None })
  self.clear_history()
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::clear(self : MarkdownEditorApp) -> Unit {
  self.document.set("")
  self.selection.set({ caret: 0, selection: None })
  self.clear_history()
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::apply_action(
  self : MarkdownEditorApp,
  action : String,
) -> Unit {
  if action == "source-preview" {
    self.toggle_source_preview()
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
fn MarkdownEditorApp::set_source_preview_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.source_preview_visible.set(visible)
}

///|
fn MarkdownEditorApp::clear_history(self : MarkdownEditorApp) -> Unit {
  self.undo_stack.set([])
  self.redo_stack.set([])
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
fn MarkdownEditorApp::set_code_language(
  self : MarkdownEditorApp,
  language : String,
) -> Unit {
  self.code_language.set(language)
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
fn MarkdownEditorApp::code_language(self : MarkdownEditorApp) -> String {
  self.code_language.get()
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
  } else {
    None
  }
}
