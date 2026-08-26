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
    Some(SetLinkTarget("https://wzzc-dev.github.io/MoUI"))
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
    Some(SetTableColumnAlignment(Some(@text.TextAlign::TextStart)))
  } else if action == "table-align-center" {
    Some(SetTableColumnAlignment(Some(@text.TextAlign::TextCenter)))
  } else if action == "table-align-right" {
    Some(SetTableColumnAlignment(Some(@text.TextAlign::TextEnd)))
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
#warnings("-unused_value")
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
  range : @text.TextRange,
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
fn markdown_editor_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(meta=true),
  )
}

///|
fn markdown_editor_plain_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(key~)
}

///|
fn markdown_editor_plain_shift_shortcut(
  key : String,
) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(shift=true),
  )
}

///|
fn markdown_editor_shift_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(meta=true, shift=true),
  )
}

///|
fn markdown_editor_control_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(control=true),
  )
}

///|
fn markdown_editor_control_shift_shortcut(
  key : String,
) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(control=true, shift=true),
  )
}

///|
fn markdown_editor_alt_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(alt=true),
  )
}

///|
fn markdown_editor_alt_shift_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(alt=true, shift=true),
  )
}

///|
fn markdown_editor_meta_alt_shortcut(key : String) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(meta=true, alt=true),
  )
}

///|
fn markdown_editor_control_alt_shortcut(
  key : String,
) -> @views.KeyboardShortcut {
  @views.KeyboardShortcut::new(
    key~,
    modifiers=@views.KeyModifiers::new(control=true, alt=true),
  )
}

///|
fn markdown_editor_program_command(
  label : String,
  shortcut : @views.KeyboardShortcut,
  message : MarkdownEditorMsg,
) -> @moui.ProgramCommand[MarkdownEditorMsg] {
  @moui.ProgramCommand::new(
    command=@views.ActionCommand::new(
      intent=@views.CommandIntent::Activate,
      label~,
      shortcut=Some(shortcut),
      context_menu=true,
    ),
    message~,
  )
}

///|
pub fn markdown_editor_program_commands() -> Array[
  @moui.ProgramCommand[MarkdownEditorMsg],
] {
  let commands : Array[@moui.ProgramCommand[MarkdownEditorMsg]] = []
  let add = (
    label : String,
    shortcut : @views.KeyboardShortcut,
    message : MarkdownEditorMsg,
  ) => commands.push(markdown_editor_program_command(label, shortcut, message))
  let both = (
    label : String,
    meta : @views.KeyboardShortcut,
    control : @views.KeyboardShortcut,
    message : MarkdownEditorMsg,
  ) => {
    add(label, meta, message)
    add(label, control, message)
  }

  both(
    "New Document",
    markdown_editor_shortcut("n"),
    markdown_editor_control_shortcut("n"),
    NewDocument,
  )
  both(
    "Open Document",
    markdown_editor_shortcut("o"),
    markdown_editor_control_shortcut("o"),
    OpenDocument,
  )
  both(
    "Save",
    markdown_editor_shortcut("s"),
    markdown_editor_control_shortcut("s"),
    SaveDocument,
  )
  both(
    "Save As",
    markdown_editor_shift_shortcut("s"),
    markdown_editor_control_shift_shortcut("s"),
    SaveDocumentAs,
  )
  both(
    "Import Markdown from Clipboard",
    markdown_editor_meta_alt_shortcut("i"),
    markdown_editor_control_alt_shortcut("i"),
    ImportFromClipboard,
  )
  both(
    "Export Markdown",
    markdown_editor_meta_alt_shortcut("s"),
    markdown_editor_control_alt_shortcut("s"),
    ExportToClipboard,
  )
  both(
    "Export HTML",
    markdown_editor_meta_alt_shortcut("e"),
    markdown_editor_control_alt_shortcut("e"),
    ExportHtmlToClipboard,
  )
  both(
    "Find",
    markdown_editor_shortcut("f"),
    markdown_editor_control_shortcut("f"),
    OpenFind,
  )
  both(
    "Find/Replace",
    markdown_editor_meta_alt_shortcut("f"),
    markdown_editor_control_shortcut("h"),
    OpenFindReplace,
  )
  both(
    "Find Next",
    markdown_editor_shortcut("g"),
    markdown_editor_control_shortcut("g"),
    FindNext,
  )
  both(
    "Find Previous",
    markdown_editor_shift_shortcut("g"),
    markdown_editor_control_shift_shortcut("g"),
    FindPrevious,
  )
  add(
    "Dismiss Panels",
    markdown_editor_plain_shortcut("Escape"),
    DismissAuxiliaryPanels,
  )
  both(
    "Toggle Source Preview",
    markdown_editor_shortcut("/"),
    markdown_editor_control_shortcut("/"),
    ToggleSourcePreview,
  )
  both(
    "Toggle Source Mode",
    markdown_editor_shift_shortcut("/"),
    markdown_editor_control_shift_shortcut("/"),
    ToggleSourceMode,
  )
  both(
    "Toggle Quick Format",
    markdown_editor_shift_shortcut("p"),
    markdown_editor_control_shift_shortcut("p"),
    ToggleFormatPalette,
  )
  both(
    "Cycle Writing Look",
    markdown_editor_meta_alt_shortcut("l"),
    markdown_editor_control_alt_shortcut("l"),
    CycleWritingAppearance,
  )
  both(
    "Insert Table of Contents",
    markdown_editor_meta_alt_shortcut("t"),
    markdown_editor_control_alt_shortcut("t"),
    ApplyCommand(InsertTableOfContents),
  )
  both(
    "Insert YAML Front Matter",
    markdown_editor_meta_alt_shortcut("y"),
    markdown_editor_control_alt_shortcut("y"),
    ApplyCommand(InsertFrontMatter),
  )
  both(
    "Indent Lines",
    markdown_editor_shortcut("]"),
    markdown_editor_control_shortcut("]"),
    IndentLines,
  )
  both(
    "Outdent Lines",
    markdown_editor_shortcut("["),
    markdown_editor_control_shortcut("["),
    OutdentLines,
  )
  both(
    "Toggle Outline",
    markdown_editor_meta_alt_shortcut("o"),
    markdown_editor_control_alt_shortcut("o"),
    ToggleOutline,
  )
  both(
    "Toggle Files",
    markdown_editor_meta_alt_shortcut("p"),
    markdown_editor_control_alt_shortcut("p"),
    ToggleFileSidebar,
  )
  both(
    "Toggle Document Info",
    markdown_editor_meta_alt_shortcut("d"),
    markdown_editor_control_alt_shortcut("d"),
    ToggleDocumentInfo,
  )
  both(
    "Toggle Focus Mode",
    markdown_editor_shift_shortcut("f"),
    markdown_editor_control_shift_shortcut("f"),
    ToggleFocusMode,
  )
  both(
    "Toggle Typewriter Mode",
    markdown_editor_shift_shortcut("t"),
    markdown_editor_control_shift_shortcut("t"),
    ToggleTypewriterMode,
  )
  both(
    "Toggle Zen Mode",
    markdown_editor_meta_alt_shortcut("z"),
    markdown_editor_control_alt_shortcut("z"),
    ToggleZenMode,
  )
  both(
    "Next Heading",
    markdown_editor_meta_alt_shortcut("ArrowDown"),
    markdown_editor_control_alt_shortcut("ArrowDown"),
    JumpToNextHeading,
  )
  both(
    "Previous Heading",
    markdown_editor_meta_alt_shortcut("ArrowUp"),
    markdown_editor_control_alt_shortcut("ArrowUp"),
    JumpToPreviousHeading,
  )
  both(
    "Open Target",
    markdown_editor_shift_shortcut("o"),
    markdown_editor_control_shift_shortcut("o"),
    OpenTarget,
  )
  both(
    "Bold",
    markdown_editor_shortcut("b"),
    markdown_editor_control_shortcut("b"),
    ApplyCommand(Bold),
  )
  both(
    "Italic",
    markdown_editor_shortcut("i"),
    markdown_editor_control_shortcut("i"),
    ApplyCommand(Italic),
  )
  both(
    "Inline Code",
    markdown_editor_shortcut("e"),
    markdown_editor_control_shortcut("e"),
    ApplyCommand(Code),
  )
  both(
    "Strikethrough",
    markdown_editor_shift_shortcut("x"),
    markdown_editor_control_shift_shortcut("x"),
    ApplyCommand(Strikethrough),
  )
  both(
    "Link",
    markdown_editor_shortcut("l"),
    markdown_editor_control_shortcut("k"),
    ApplyCommand(Link),
  )
  both(
    "Image",
    markdown_editor_shift_shortcut("i"),
    markdown_editor_control_shift_shortcut("i"),
    ApplyCommand(Image),
  )
  both(
    "Paragraph",
    markdown_editor_shortcut("0"),
    markdown_editor_control_shortcut("0"),
    ApplyCommand(Paragraph),
  )
  both(
    "Heading 1",
    markdown_editor_shortcut("1"),
    markdown_editor_control_shortcut("1"),
    ApplyCommand(Heading(1)),
  )
  both(
    "Heading 2",
    markdown_editor_shortcut("2"),
    markdown_editor_control_shortcut("2"),
    ApplyCommand(Heading(2)),
  )
  both(
    "Heading 3",
    markdown_editor_shortcut("3"),
    markdown_editor_control_shortcut("3"),
    ApplyCommand(Heading(3)),
  )
  both(
    "Heading 4",
    markdown_editor_shortcut("4"),
    markdown_editor_control_shortcut("4"),
    ApplyCommand(Heading(4)),
  )
  both(
    "Heading 5",
    markdown_editor_shortcut("5"),
    markdown_editor_control_shortcut("5"),
    ApplyCommand(Heading(5)),
  )
  both(
    "Heading 6",
    markdown_editor_shortcut("6"),
    markdown_editor_control_shortcut("6"),
    ApplyCommand(Heading(6)),
  )
  add("Bullet List", markdown_editor_shortcut("u"), ApplyCommand(BulletList))
  add(
    "Bullet List",
    markdown_editor_control_shift_shortcut("8"),
    ApplyCommand(BulletList),
  )
  add(
    "Bullet List",
    markdown_editor_control_shift_shortcut("*"),
    ApplyCommand(BulletList),
  )
  add("Task List", markdown_editor_shortcut("t"), ApplyCommand(TaskList))
  both(
    "Toggle Task",
    markdown_editor_shortcut("Enter"),
    markdown_editor_control_shortcut("Enter"),
    ToggleCurrentTask,
  )
  add(
    "Hard Line Break",
    markdown_editor_plain_shift_shortcut("Enter"),
    InsertHardBreak,
  )
  add("Ordered List", markdown_editor_shortcut("o"), ApplyCommand(OrderedList))
  add(
    "Ordered List",
    markdown_editor_control_shift_shortcut("7"),
    ApplyCommand(OrderedList),
  )
  add(
    "Ordered List",
    markdown_editor_control_shift_shortcut("&"),
    ApplyCommand(OrderedList),
  )
  add("Quote", markdown_editor_shortcut("q"), ApplyCommand(Quote))
  add("Quote", markdown_editor_control_shift_shortcut("9"), ApplyCommand(Quote))
  add("Quote", markdown_editor_control_shift_shortcut("("), ApplyCommand(Quote))
  both(
    "Code Block",
    markdown_editor_shortcut("k"),
    markdown_editor_control_shift_shortcut("k"),
    ApplyCommand(CodeBlock),
  )
  both(
    "Duplicate Block",
    markdown_editor_shift_shortcut("d"),
    markdown_editor_control_shift_shortcut("d"),
    ApplyCommand(DuplicateBlock),
  )
  add(
    "Move Block Up",
    markdown_editor_alt_shortcut("ArrowUp"),
    ApplyCommand(MoveBlockUp),
  )
  add(
    "Move Block Down",
    markdown_editor_alt_shortcut("ArrowDown"),
    ApplyCommand(MoveBlockDown),
  )
  add(
    "Insert Table Column",
    markdown_editor_shift_shortcut("="),
    ApplyCommand(InsertTableColumn),
  )
  add(
    "Insert Table Column",
    markdown_editor_shift_shortcut("+"),
    ApplyCommand(InsertTableColumn),
  )
  add(
    "Insert Table Column",
    markdown_editor_control_shift_shortcut("="),
    ApplyCommand(InsertTableColumn),
  )
  add(
    "Insert Table Column",
    markdown_editor_control_shift_shortcut("+"),
    ApplyCommand(InsertTableColumn),
  )
  both(
    "Insert Table Row",
    markdown_editor_shift_shortcut("Enter"),
    markdown_editor_control_shift_shortcut("Enter"),
    ApplyCommand(InsertTableRow),
  )
  both(
    "Delete Table Row",
    markdown_editor_shift_shortcut("-"),
    markdown_editor_control_shift_shortcut("-"),
    ApplyCommand(DeleteTableRow),
  )
  both(
    "Delete Table Column",
    markdown_editor_shift_shortcut("_"),
    markdown_editor_control_shift_shortcut("_"),
    ApplyCommand(DeleteTableColumn),
  )
  both(
    "Table Align Left",
    markdown_editor_shift_shortcut("l"),
    markdown_editor_control_shift_shortcut("l"),
    ApplyCommand(SetTableColumnAlignment(Some(@text.TextAlign::TextStart))),
  )
  both(
    "Table Align Center",
    markdown_editor_shift_shortcut("e"),
    markdown_editor_control_shift_shortcut("e"),
    ApplyCommand(SetTableColumnAlignment(Some(@text.TextAlign::TextCenter))),
  )
  both(
    "Table Align Right",
    markdown_editor_shift_shortcut("r"),
    markdown_editor_control_shift_shortcut("r"),
    ApplyCommand(SetTableColumnAlignment(Some(@text.TextAlign::TextEnd))),
  )
  both(
    "Table Align Auto",
    markdown_editor_shift_shortcut("0"),
    markdown_editor_control_shift_shortcut("0"),
    ApplyCommand(SetTableColumnAlignment(None)),
  )
  add("Undo Formatting Command", markdown_editor_alt_shortcut("z"), Undo)
  add("Redo Formatting Command", markdown_editor_alt_shift_shortcut("z"), Redo)
  commands
}

///|
fn markdown_editor_menu_item(
  label : String,
  shortcut : @views.KeyboardShortcut,
  message : MarkdownEditorMsg,
) -> @services.ApplicationMenuItem {
  @services.ApplicationMenuItem::MenuCommand(
    markdown_editor_program_command(label, shortcut, message).command(),
  )
}

///|
pub fn markdown_editor_application_menus() -> Array[@services.ApplicationMenu] {
  let separator = @services.ApplicationMenuItem::MenuSeparator
  [
    @services.ApplicationMenu::new(title="File", items=[
      markdown_editor_menu_item(
        "New Document",
        markdown_editor_shortcut("n"),
        NewDocument,
      ),
      markdown_editor_menu_item(
        "Open Document",
        markdown_editor_shortcut("o"),
        OpenDocument,
      ),
      markdown_editor_menu_item(
        "Save",
        markdown_editor_shortcut("s"),
        SaveDocument,
      ),
      markdown_editor_menu_item(
        "Save As",
        markdown_editor_shift_shortcut("s"),
        SaveDocumentAs,
      ),
    ]),
    @services.ApplicationMenu::new(title="Edit", items=[
      markdown_editor_menu_item(
        "Undo Formatting Command",
        markdown_editor_alt_shortcut("z"),
        Undo,
      ),
      markdown_editor_menu_item(
        "Redo Formatting Command",
        markdown_editor_alt_shift_shortcut("z"),
        Redo,
      ),
      separator,
      markdown_editor_menu_item("Find", markdown_editor_shortcut("f"), OpenFind),
    ]),
    @services.ApplicationMenu::new(title="Format", items=[
      markdown_editor_menu_item(
        "Bold",
        markdown_editor_shortcut("b"),
        ApplyCommand(Bold),
      ),
      markdown_editor_menu_item(
        "Italic",
        markdown_editor_shortcut("i"),
        ApplyCommand(Italic),
      ),
      markdown_editor_menu_item(
        "Inline Code",
        markdown_editor_shortcut("e"),
        ApplyCommand(Code),
      ),
      markdown_editor_menu_item(
        "Strikethrough",
        markdown_editor_shift_shortcut("x"),
        ApplyCommand(Strikethrough),
      ),
      markdown_editor_menu_item(
        "Link",
        markdown_editor_shortcut("l"),
        ApplyCommand(Link),
      ),
      separator,
      markdown_editor_menu_item(
        "Heading 1",
        markdown_editor_shortcut("1"),
        ApplyCommand(Heading(1)),
      ),
      markdown_editor_menu_item(
        "Heading 2",
        markdown_editor_shortcut("2"),
        ApplyCommand(Heading(2)),
      ),
      markdown_editor_menu_item(
        "Heading 3",
        markdown_editor_shortcut("3"),
        ApplyCommand(Heading(3)),
      ),
      markdown_editor_menu_item(
        "Heading 4",
        markdown_editor_shortcut("4"),
        ApplyCommand(Heading(4)),
      ),
      markdown_editor_menu_item(
        "Heading 5",
        markdown_editor_shortcut("5"),
        ApplyCommand(Heading(5)),
      ),
      markdown_editor_menu_item(
        "Heading 6",
        markdown_editor_shortcut("6"),
        ApplyCommand(Heading(6)),
      ),
      markdown_editor_menu_item(
        "Paragraph",
        markdown_editor_shortcut("0"),
        ApplyCommand(Paragraph),
      ),
      separator,
      markdown_editor_menu_item(
        "Bullet List",
        markdown_editor_shortcut("u"),
        ApplyCommand(BulletList),
      ),
      markdown_editor_menu_item(
        "Ordered List",
        markdown_editor_shortcut("o"),
        ApplyCommand(OrderedList),
      ),
      markdown_editor_menu_item(
        "Task List",
        markdown_editor_shortcut("t"),
        ApplyCommand(TaskList),
      ),
      markdown_editor_menu_item(
        "Quote",
        markdown_editor_shortcut("q"),
        ApplyCommand(Quote),
      ),
      markdown_editor_menu_item(
        "Code Block",
        markdown_editor_shortcut("k"),
        ApplyCommand(CodeBlock),
      ),
    ]),
    @services.ApplicationMenu::new(title="View", items=[
      markdown_editor_menu_item(
        "Toggle Source Mode",
        markdown_editor_shift_shortcut("/"),
        ToggleSourceMode,
      ),
      markdown_editor_menu_item(
        "Toggle Focus Mode",
        markdown_editor_shift_shortcut("f"),
        ToggleFocusMode,
      ),
      markdown_editor_menu_item(
        "Toggle Typewriter Mode",
        markdown_editor_shift_shortcut("t"),
        ToggleTypewriterMode,
      ),
      markdown_editor_menu_item(
        "Toggle Zen Mode",
        markdown_editor_meta_alt_shortcut("z"),
        ToggleZenMode,
      ),
      separator,
      markdown_editor_menu_item(
        "Toggle Outline",
        markdown_editor_meta_alt_shortcut("o"),
        ToggleOutline,
      ),
      markdown_editor_menu_item(
        "Toggle Files",
        markdown_editor_meta_alt_shortcut("p"),
        ToggleFileSidebar,
      ),
      markdown_editor_menu_item(
        "Toggle Document Info",
        markdown_editor_meta_alt_shortcut("d"),
        ToggleDocumentInfo,
      ),
      markdown_editor_menu_item(
        "Toggle Source Preview",
        markdown_editor_shortcut("/"),
        ToggleSourcePreview,
      ),
    ]),
  ]
}
