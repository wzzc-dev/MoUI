///|
fn markdown_editor_command_from_action(
  action : String,
) -> MarkdownEditorCommand? {
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
  } else if action == "toc" {
    Some(InsertTableOfContents)
  } else if action == "front-matter" {
    Some(InsertFrontMatter)
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

///|
fn markdown_editor_command_active(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> Bool {
  match command {
    Bold | Italic | Code | Strikethrough =>
      markdown_editor_inline_command_active(source, selection, command)
    Link => markdown_editor_link_context(source, selection) is Some(_)
    Image => markdown_editor_image_context(source, selection) is Some(_)
    Heading(level) =>
      markdown_editor_active_block_label(source, selection) ==
      "Heading " + level.to_string()
    BulletList =>
      markdown_editor_active_block_label(source, selection) == "Bullet list"
    TaskList =>
      markdown_editor_active_block_label(source, selection) == "Task list"
    OrderedList =>
      markdown_editor_active_block_label(source, selection) == "Ordered list"
    Quote => markdown_editor_active_block_label(source, selection) == "Quote"
    CodeBlock =>
      markdown_editor_active_block_label(source, selection) == "Code block"
    HorizontalRule =>
      markdown_editor_active_block_label(source, selection) == "Rule"
    Table => markdown_editor_active_block_label(source, selection) == "Table"
    _ => false
  }
}

///|
fn markdown_editor_active_format_suffix(
  source : String,
  selection : MarkdownEditorSelection,
) -> String {
  let labels : Array[String] = []
  if markdown_editor_command_active(source, selection, Bold) {
    labels.push("Bold")
  }
  if markdown_editor_command_active(source, selection, Italic) {
    labels.push("Italic")
  }
  if markdown_editor_command_active(source, selection, Code) {
    labels.push("Code")
  }
  if markdown_editor_command_active(source, selection, Strikethrough) {
    labels.push("Strike")
  }
  if markdown_editor_command_active(source, selection, Link) {
    labels.push("Link")
  }
  if markdown_editor_command_active(source, selection, Image) {
    labels.push("Image")
  }
  if labels.length() == 0 {
    ""
  } else {
    " / Active: " + labels.join(", ")
  }
}

///|
fn markdown_editor_inline_command_active(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> Bool {
  let marker = markdown_editor_inline_marker(command)
  match markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      markdown_editor_range_has_inline_marker(
        source,
        range.normalized(),
        marker,
      ) &&
      markdown_editor_inline_active_marker_supported(
        source,
        range.normalized(),
        marker,
      )
    None =>
      markdown_editor_inline_marker_pair_at_caret(
        source,
        selection.caret,
        marker,
      )
      is Some(range) &&
      markdown_editor_inline_active_marker_supported(source, range, marker)
  }
}

///|
fn markdown_editor_inline_active_marker_supported(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> Bool {
  if marker != "*" {
    return true
  }
  let chars = source.to_array()
  let open = range.start - 1
  let close = range.end
  let doubled_open = open > 0 && chars[open - 1] == '*'
  let doubled_close = close + 1 < chars.length() && chars[close + 1] == '*'
  !doubled_open && !doubled_close
}

///|
fn markdown_editor_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true),
  )
}

///|
fn markdown_editor_plain_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(key~)
}

///|
fn markdown_editor_plain_shift_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(shift=true),
  )
}

///|
fn markdown_editor_shift_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true, shift=true),
  )
}

///|
fn markdown_editor_control_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true),
  )
}

///|
fn markdown_editor_control_shift_shortcut(
  key : String,
) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true, shift=true),
  )
}

///|
fn markdown_editor_alt_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(key~, modifiers=@core.KeyModifiers::new(alt=true))
}

///|
fn markdown_editor_meta_alt_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true, alt=true),
  )
}

///|
fn markdown_editor_control_alt_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true, alt=true),
  )
}

///|
fn markdown_editor_command_binding(
  label : String,
  shortcut : @core.KeyboardShortcut,
  action : () -> Unit,
  context_menu? : Bool = true,
) -> @core.CommandBinding {
  @core.CommandBinding::new(
    command=@core.ActionCommand::new(
      intent=@core.CommandIntent::Activate,
      label~,
      shortcut=Some(shortcut),
      context_menu~,
    ),
    handle=action,
  )
}

///|
pub fn MarkdownEditorApp::action_commands(
  self : MarkdownEditorApp,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
) -> @core.ActionCommandMap {
  @core.ActionCommandMap::new(bindings=[
    markdown_editor_command_binding(
      "New Document",
      markdown_editor_shortcut("n"),
      () => ignore(self.update(NewDocument)),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "New Document",
      markdown_editor_control_shortcut("n"),
      () => ignore(self.update(NewDocument)),
    ),
    markdown_editor_command_binding(
      "Open Document",
      markdown_editor_shortcut("o"),
      () => self.perform_file_open(services),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Open Document",
      markdown_editor_control_shortcut("o"),
      () => self.perform_file_open(services),
    ),
    markdown_editor_command_binding(
      "Save",
      markdown_editor_shortcut("s"),
      () => self.perform_document_save(services),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Save",
      markdown_editor_control_shortcut("s"),
      () => self.perform_document_save(services),
    ),
    markdown_editor_command_binding(
      "Save As",
      markdown_editor_shift_shortcut("s"),
      () => self.perform_file_save_as(services),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Save As",
      markdown_editor_control_shift_shortcut("s"),
      () => self.perform_file_save_as(services),
    ),
    markdown_editor_command_binding(
      "Import Markdown from Clipboard",
      markdown_editor_meta_alt_shortcut("i"),
      () => self.perform_clipboard_import(services),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Import Markdown from Clipboard",
      markdown_editor_control_alt_shortcut("i"),
      () => self.perform_clipboard_import(services),
    ),
    markdown_editor_command_binding(
      "Export Markdown",
      markdown_editor_meta_alt_shortcut("s"),
      () => self.perform_clipboard_export(services),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Export Markdown",
      markdown_editor_control_alt_shortcut("s"),
      () => self.perform_clipboard_export(services),
    ),
    markdown_editor_command_binding(
      "Export HTML",
      markdown_editor_meta_alt_shortcut("e"),
      () => self.perform_html_export(services),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Export HTML",
      markdown_editor_control_alt_shortcut("e"),
      () => self.perform_html_export(services),
    ),
    markdown_editor_command_binding(
      "Find",
      markdown_editor_shortcut("f"),
      () => ignore(self.update(OpenFind)),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Find",
      markdown_editor_control_shortcut("f"),
      () => ignore(self.update(OpenFind)),
    ),
    markdown_editor_command_binding(
      "Find/Replace",
      markdown_editor_meta_alt_shortcut("f"),
      () => ignore(self.update(OpenFindReplace)),
      context_menu=true,
    ),
    markdown_editor_command_binding(
      "Find/Replace",
      markdown_editor_control_shortcut("h"),
      () => ignore(self.update(OpenFindReplace)),
    ),
    markdown_editor_command_binding(
      "Find Next",
      markdown_editor_shortcut("g"),
      () => ignore(self.update(FindNext)),
    ),
    markdown_editor_command_binding(
      "Find Next",
      markdown_editor_control_shortcut("g"),
      () => ignore(self.update(FindNext)),
    ),
    markdown_editor_command_binding(
      "Find Previous",
      markdown_editor_shift_shortcut("g"),
      () => ignore(self.update(FindPrevious)),
    ),
    markdown_editor_command_binding(
      "Find Previous",
      markdown_editor_control_shift_shortcut("g"),
      () => ignore(self.update(FindPrevious)),
    ),
    markdown_editor_command_binding(
      "Dismiss Panels",
      markdown_editor_plain_shortcut("Escape"),
      () => ignore(self.update(DismissAuxiliaryPanels)),
    ),
    markdown_editor_command_binding(
      "Toggle Source Preview",
      markdown_editor_shortcut("/"),
      () => ignore(self.update(ToggleSourcePreview)),
    ),
    markdown_editor_command_binding(
      "Toggle Source Preview",
      markdown_editor_control_shortcut("/"),
      () => ignore(self.update(ToggleSourcePreview)),
    ),
    markdown_editor_command_binding(
      "Toggle Source Mode",
      markdown_editor_shift_shortcut("/"),
      () => ignore(self.update(ToggleSourceMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Source Mode",
      markdown_editor_control_shift_shortcut("/"),
      () => ignore(self.update(ToggleSourceMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Quick Format",
      markdown_editor_shift_shortcut("p"),
      () => ignore(self.update(ToggleFormatPalette)),
    ),
    markdown_editor_command_binding(
      "Toggle Quick Format",
      markdown_editor_control_shift_shortcut("p"),
      () => ignore(self.update(ToggleFormatPalette)),
    ),
    markdown_editor_command_binding(
      "Cycle Writing Look",
      markdown_editor_meta_alt_shortcut("l"),
      () => ignore(self.update(CycleWritingAppearance)),
    ),
    markdown_editor_command_binding(
      "Cycle Writing Look",
      markdown_editor_control_alt_shortcut("l"),
      () => ignore(self.update(CycleWritingAppearance)),
    ),
    markdown_editor_command_binding(
      "Insert Table of Contents",
      markdown_editor_meta_alt_shortcut("t"),
      () => ignore(self.update(ApplyCommand(InsertTableOfContents))),
    ),
    markdown_editor_command_binding(
      "Insert Table of Contents",
      markdown_editor_control_alt_shortcut("t"),
      () => ignore(self.update(ApplyCommand(InsertTableOfContents))),
    ),
    markdown_editor_command_binding(
      "Insert YAML Front Matter",
      markdown_editor_meta_alt_shortcut("y"),
      () => ignore(self.update(ApplyCommand(InsertFrontMatter))),
    ),
    markdown_editor_command_binding(
      "Insert YAML Front Matter",
      markdown_editor_control_alt_shortcut("y"),
      () => ignore(self.update(ApplyCommand(InsertFrontMatter))),
    ),
    markdown_editor_command_binding(
      "Indent Lines",
      markdown_editor_shortcut("]"),
      () => ignore(self.update(IndentLines)),
    ),
    markdown_editor_command_binding(
      "Indent Lines",
      markdown_editor_control_shortcut("]"),
      () => ignore(self.update(IndentLines)),
    ),
    markdown_editor_command_binding(
      "Outdent Lines",
      markdown_editor_shortcut("["),
      () => ignore(self.update(OutdentLines)),
    ),
    markdown_editor_command_binding(
      "Outdent Lines",
      markdown_editor_control_shortcut("["),
      () => ignore(self.update(OutdentLines)),
    ),
    markdown_editor_command_binding(
      "Toggle Outline",
      markdown_editor_meta_alt_shortcut("o"),
      () => ignore(self.update(ToggleOutline)),
    ),
    markdown_editor_command_binding(
      "Toggle Outline",
      markdown_editor_control_alt_shortcut("o"),
      () => ignore(self.update(ToggleOutline)),
    ),
    markdown_editor_command_binding(
      "Toggle Files",
      markdown_editor_meta_alt_shortcut("p"),
      () => ignore(self.update(ToggleFileSidebar)),
    ),
    markdown_editor_command_binding(
      "Toggle Files",
      markdown_editor_control_alt_shortcut("p"),
      () => ignore(self.update(ToggleFileSidebar)),
    ),
    markdown_editor_command_binding(
      "Toggle Document Info",
      markdown_editor_meta_alt_shortcut("d"),
      () => ignore(self.update(ToggleDocumentInfo)),
    ),
    markdown_editor_command_binding(
      "Toggle Document Info",
      markdown_editor_control_alt_shortcut("d"),
      () => ignore(self.update(ToggleDocumentInfo)),
    ),
    markdown_editor_command_binding(
      "Toggle Focus Mode",
      markdown_editor_shift_shortcut("f"),
      () => ignore(self.update(ToggleFocusMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Focus Mode",
      markdown_editor_control_shift_shortcut("f"),
      () => ignore(self.update(ToggleFocusMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Typewriter Mode",
      markdown_editor_shift_shortcut("t"),
      () => ignore(self.update(ToggleTypewriterMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Typewriter Mode",
      markdown_editor_control_shift_shortcut("t"),
      () => ignore(self.update(ToggleTypewriterMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Zen Mode",
      markdown_editor_meta_alt_shortcut("z"),
      () => ignore(self.update(ToggleZenMode)),
    ),
    markdown_editor_command_binding(
      "Toggle Zen Mode",
      markdown_editor_control_alt_shortcut("z"),
      () => ignore(self.update(ToggleZenMode)),
    ),
    markdown_editor_command_binding(
      "Next Heading",
      markdown_editor_meta_alt_shortcut("ArrowDown"),
      () => ignore(self.update(JumpToNextHeading)),
    ),
    markdown_editor_command_binding(
      "Next Heading",
      markdown_editor_control_alt_shortcut("ArrowDown"),
      () => ignore(self.update(JumpToNextHeading)),
    ),
    markdown_editor_command_binding(
      "Previous Heading",
      markdown_editor_meta_alt_shortcut("ArrowUp"),
      () => ignore(self.update(JumpToPreviousHeading)),
    ),
    markdown_editor_command_binding(
      "Previous Heading",
      markdown_editor_control_alt_shortcut("ArrowUp"),
      () => ignore(self.update(JumpToPreviousHeading)),
    ),
    markdown_editor_command_binding(
      "Open Target",
      markdown_editor_shift_shortcut("o"),
      () => self.perform_open_target(services),
    ),
    markdown_editor_command_binding(
      "Open Target",
      markdown_editor_control_shift_shortcut("o"),
      () => self.perform_open_target(services),
    ),
    markdown_editor_command_binding("Bold", markdown_editor_shortcut("b"), () => {
      ignore(self.update(ApplyCommand(Bold)))
    }),
    markdown_editor_command_binding(
      "Bold",
      markdown_editor_control_shortcut("b"),
      () => ignore(self.update(ApplyCommand(Bold))),
    ),
    markdown_editor_command_binding("Italic", markdown_editor_shortcut("i"), () => {
      ignore(self.update(ApplyCommand(Italic)))
    }),
    markdown_editor_command_binding(
      "Italic",
      markdown_editor_control_shortcut("i"),
      () => ignore(self.update(ApplyCommand(Italic))),
    ),
    markdown_editor_command_binding(
      "Inline Code",
      markdown_editor_shortcut("e"),
      () => ignore(self.update(ApplyCommand(Code))),
    ),
    markdown_editor_command_binding(
      "Inline Code",
      markdown_editor_control_shortcut("e"),
      () => ignore(self.update(ApplyCommand(Code))),
    ),
    markdown_editor_command_binding(
      "Strikethrough",
      markdown_editor_shift_shortcut("x"),
      () => ignore(self.update(ApplyCommand(Strikethrough))),
    ),
    markdown_editor_command_binding(
      "Strikethrough",
      markdown_editor_control_shift_shortcut("x"),
      () => ignore(self.update(ApplyCommand(Strikethrough))),
    ),
    markdown_editor_command_binding("Link", markdown_editor_shortcut("l"), () => {
      ignore(self.update(ApplyCommand(Link)))
    }),
    markdown_editor_command_binding(
      "Link",
      markdown_editor_control_shortcut("k"),
      () => ignore(self.update(ApplyCommand(Link))),
    ),
    markdown_editor_command_binding(
      "Image",
      markdown_editor_shift_shortcut("i"),
      () => ignore(self.update(ApplyCommand(Image))),
    ),
    markdown_editor_command_binding(
      "Image",
      markdown_editor_control_shift_shortcut("i"),
      () => ignore(self.update(ApplyCommand(Image))),
    ),
    markdown_editor_command_binding(
      "Paragraph",
      markdown_editor_shortcut("0"),
      () => ignore(self.update(ApplyCommand(Paragraph))),
    ),
    markdown_editor_command_binding(
      "Paragraph",
      markdown_editor_control_shortcut("0"),
      () => ignore(self.update(ApplyCommand(Paragraph))),
    ),
    markdown_editor_command_binding(
      "Heading 1",
      markdown_editor_shortcut("1"),
      () => ignore(self.update(ApplyCommand(Heading(1)))),
    ),
    markdown_editor_command_binding(
      "Heading 1",
      markdown_editor_control_shortcut("1"),
      () => ignore(self.update(ApplyCommand(Heading(1)))),
    ),
    markdown_editor_command_binding(
      "Heading 2",
      markdown_editor_shortcut("2"),
      () => ignore(self.update(ApplyCommand(Heading(2)))),
    ),
    markdown_editor_command_binding(
      "Heading 2",
      markdown_editor_control_shortcut("2"),
      () => ignore(self.update(ApplyCommand(Heading(2)))),
    ),
    markdown_editor_command_binding(
      "Heading 3",
      markdown_editor_shortcut("3"),
      () => ignore(self.update(ApplyCommand(Heading(3)))),
    ),
    markdown_editor_command_binding(
      "Heading 3",
      markdown_editor_control_shortcut("3"),
      () => ignore(self.update(ApplyCommand(Heading(3)))),
    ),
    markdown_editor_command_binding(
      "Heading 4",
      markdown_editor_shortcut("4"),
      () => ignore(self.update(ApplyCommand(Heading(4)))),
    ),
    markdown_editor_command_binding(
      "Heading 4",
      markdown_editor_control_shortcut("4"),
      () => ignore(self.update(ApplyCommand(Heading(4)))),
    ),
    markdown_editor_command_binding(
      "Heading 5",
      markdown_editor_shortcut("5"),
      () => ignore(self.update(ApplyCommand(Heading(5)))),
    ),
    markdown_editor_command_binding(
      "Heading 5",
      markdown_editor_control_shortcut("5"),
      () => ignore(self.update(ApplyCommand(Heading(5)))),
    ),
    markdown_editor_command_binding(
      "Heading 6",
      markdown_editor_shortcut("6"),
      () => ignore(self.update(ApplyCommand(Heading(6)))),
    ),
    markdown_editor_command_binding(
      "Heading 6",
      markdown_editor_control_shortcut("6"),
      () => ignore(self.update(ApplyCommand(Heading(6)))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_shortcut("u"),
      () => ignore(self.update(ApplyCommand(BulletList))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_control_shift_shortcut("8"),
      () => ignore(self.update(ApplyCommand(BulletList))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_control_shift_shortcut("*"),
      () => ignore(self.update(ApplyCommand(BulletList))),
    ),
    markdown_editor_command_binding(
      "Task List",
      markdown_editor_shortcut("t"),
      () => ignore(self.update(ApplyCommand(TaskList))),
    ),
    markdown_editor_command_binding(
      "Toggle Task",
      markdown_editor_shortcut("Enter"),
      () => ignore(self.update(ToggleCurrentTask)),
    ),
    markdown_editor_command_binding(
      "Toggle Task",
      markdown_editor_control_shortcut("Enter"),
      () => ignore(self.update(ToggleCurrentTask)),
    ),
    markdown_editor_command_binding(
      "Hard Line Break",
      markdown_editor_plain_shift_shortcut("Enter"),
      () => ignore(self.update(InsertHardBreak)),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_shortcut("o"),
      () => ignore(self.update(ApplyCommand(OrderedList))),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_control_shift_shortcut("7"),
      () => ignore(self.update(ApplyCommand(OrderedList))),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_control_shift_shortcut("&"),
      () => ignore(self.update(ApplyCommand(OrderedList))),
    ),
    markdown_editor_command_binding("Quote", markdown_editor_shortcut("q"), () => {
      ignore(self.update(ApplyCommand(Quote)))
    }),
    markdown_editor_command_binding(
      "Quote",
      markdown_editor_control_shift_shortcut("9"),
      () => ignore(self.update(ApplyCommand(Quote))),
    ),
    markdown_editor_command_binding(
      "Quote",
      markdown_editor_control_shift_shortcut("("),
      () => ignore(self.update(ApplyCommand(Quote))),
    ),
    markdown_editor_command_binding(
      "Code Block",
      markdown_editor_shortcut("k"),
      () => ignore(self.update(ApplyCommand(CodeBlock))),
    ),
    markdown_editor_command_binding(
      "Code Block",
      markdown_editor_control_shift_shortcut("k"),
      () => ignore(self.update(ApplyCommand(CodeBlock))),
    ),
    markdown_editor_command_binding(
      "Duplicate Block",
      markdown_editor_shift_shortcut("d"),
      () => ignore(self.update(ApplyCommand(DuplicateBlock))),
    ),
    markdown_editor_command_binding(
      "Duplicate Block",
      markdown_editor_control_shift_shortcut("d"),
      () => ignore(self.update(ApplyCommand(DuplicateBlock))),
    ),
    markdown_editor_command_binding(
      "Move Block Up",
      markdown_editor_alt_shortcut("ArrowUp"),
      () => ignore(self.update(ApplyCommand(MoveBlockUp))),
    ),
    markdown_editor_command_binding(
      "Move Block Down",
      markdown_editor_alt_shortcut("ArrowDown"),
      () => ignore(self.update(ApplyCommand(MoveBlockDown))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_shift_shortcut("="),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_shift_shortcut("+"),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_control_shift_shortcut("="),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_control_shift_shortcut("+"),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Row",
      markdown_editor_shift_shortcut("Enter"),
      () => ignore(self.update(ApplyCommand(InsertTableRow))),
    ),
    markdown_editor_command_binding(
      "Insert Table Row",
      markdown_editor_control_shift_shortcut("Enter"),
      () => ignore(self.update(ApplyCommand(InsertTableRow))),
    ),
    markdown_editor_command_binding(
      "Delete Table Row",
      markdown_editor_shift_shortcut("-"),
      () => ignore(self.update(ApplyCommand(DeleteTableRow))),
    ),
    markdown_editor_command_binding(
      "Delete Table Row",
      markdown_editor_control_shift_shortcut("-"),
      () => ignore(self.update(ApplyCommand(DeleteTableRow))),
    ),
    markdown_editor_command_binding(
      "Delete Table Column",
      markdown_editor_shift_shortcut("_"),
      () => ignore(self.update(ApplyCommand(DeleteTableColumn))),
    ),
    markdown_editor_command_binding(
      "Delete Table Column",
      markdown_editor_control_shift_shortcut("_"),
      () => ignore(self.update(ApplyCommand(DeleteTableColumn))),
    ),
    markdown_editor_command_binding(
      "Table Align Left",
      markdown_editor_shift_shortcut("l"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextStart)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Left",
      markdown_editor_control_shift_shortcut("l"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextStart)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Center",
      markdown_editor_shift_shortcut("e"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Center",
      markdown_editor_control_shift_shortcut("e"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Right",
      markdown_editor_shift_shortcut("r"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Right",
      markdown_editor_control_shift_shortcut("r"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Auto",
      markdown_editor_shift_shortcut("0"),
      () => ignore(self.update(ApplyCommand(SetTableColumnAlignment(None)))),
    ),
    markdown_editor_command_binding(
      "Table Align Auto",
      markdown_editor_control_shift_shortcut("0"),
      () => ignore(self.update(ApplyCommand(SetTableColumnAlignment(None)))),
    ),
  ])
}

///|
