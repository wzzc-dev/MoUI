///|
test "markdown editor tracks document clean dirty and saved baseline" {
  let app = MarkdownEditorApp::new()
  assert_false(app.dirty())
  assert_true(
    app.document_status_label_for_test().contains("Editor notes / Saved"),
  )

  app.edit_document("# Draft\n\nBody")
  assert_true(app.dirty())
  assert_true(app.document_status_label_for_test().contains("Draft / Unsaved"))

  app.mark_saved_for_test()
  assert_false(app.dirty())
  inspect(app.saved_document(), content="# Draft\n\nBody")
  assert_true(app.document_status_label_for_test().contains("Draft / Saved"))
}

///|
test "markdown editor new document clears transient transfer status" {
  let written = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Draft\n\nBody")
  let services = markdown_editor_clipboard_services(read_text="", written~)
  app.export_clipboard_for_test(services)
  inspect(app.transfer_status_label_for_test(), content="Markdown copied")

  app.clear()
  inspect(app.document(), content="")
  inspect(app.transfer_status_label_for_test(), content="")
  assert_false(app.dirty())
}

///|
test "markdown editor status reports active section from caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\nBody\n\n## Second\nTail")
  app.set_selection(10, None)
  assert_true(app.document_status_label_for_test().contains("Section: First"))
  app.set_selection(24, None)
  assert_true(app.document_status_label_for_test().contains("Section: Second"))
}

///|
test "markdown editor load and save as set document identity" {
  let app = MarkdownEditorApp::new()
  app.apply_action("find")
  app.update_find_query_for_test("stale")
  app.set_replace_text("old")
  app.load_document_for_test("# Title\n\nBody", path="/tmp/writing/notes.md")
  assert_false(app.dirty())
  inspect(app.document_path(), content="/tmp/writing/notes.md")
  assert_false(app.find_visible())
  inspect(app.find_query(), content="")
  inspect(app.replace_text(), content="")
  let first_recent = app.recent_document_paths()
  inspect(first_recent.length(), content="1")
  inspect(first_recent[0], content="/tmp/writing/notes.md")
  assert_true(app.document_status_label_for_test().contains("notes.md / Saved"))

  app.edit_document("# Title\n\nUpdated")
  assert_true(app.dirty())
  app.save_as_for_test("C:\\Users\\writer\\paper.md")
  assert_false(app.dirty())
  inspect(app.document_path(), content="C:\\Users\\writer\\paper.md")
  inspect(app.saved_document(), content="# Title\n\nUpdated")
  let next_recent = app.recent_document_paths()
  inspect(next_recent.length(), content="2")
  inspect(next_recent[0], content="C:\\Users\\writer\\paper.md")
  inspect(next_recent[1], content="/tmp/writing/notes.md")
  assert_true(app.document_status_label_for_test().contains("paper.md / Saved"))
}

///|
test "markdown editor file save as dialog sets path and saved baseline" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let seen_title = Ref("")
  let seen_default_name = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Save Target\n\nBody")
  app.edit_document("# Save Target\n\nChanged")
  assert_true(app.dirty())
  let services = markdown_editor_file_dialog_services(
    selected_path="/tmp/writing/save-target.md",
    seen_kind~,
    seen_title~,
    seen_default_name~,
  )

  app.save_as_dialog_for_test(services)
  assert_true(seen_kind.val == @host.HostFileDialogKind::SaveFile)
  inspect(seen_title.val, content="Save Markdown")
  inspect(seen_default_name.val, content="Save Target.md")
  inspect(app.document_path(), content="/tmp/writing/save-target.md")
  inspect(app.saved_document(), content="# Save Target\n\nChanged")
  assert_false(app.dirty())
  inspect(
    app.transfer_status_label_for_test(),
    content="Saved as save-target.md",
  )
}

///|
test "markdown editor opens recent files through text file services" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let seen_title = Ref("")
  let seen_default_name = Ref("")
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Old", path="/tmp/old.md")
  app.load_document_for_test("# Current", path="/tmp/current.md")
  let services = markdown_editor_document_services(
    read_text="# Old reopened",
    selected_path="/tmp/unused.md",
    seen_kind~,
    seen_title~,
    seen_default_name~,
  )

  app.open_recent_for_test("/tmp/old.md", services)
  inspect(app.document(), content="# Old reopened")
  inspect(app.document_path(), content="/tmp/old.md")
  inspect(app.transfer_status_label_for_test(), content="Opened old.md")
  let recent = app.recent_document_paths()
  inspect(recent[0], content="/tmp/old.md")
  inspect(recent[1], content="/tmp/current.md")
}

///|
test "markdown editor files sidebar shows current and recent documents" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Notes", path="/tmp/writing/notes.md")
  app.load_document_for_test("# Draft", path="/tmp/writing/draft.md")
  assert_false(app.file_sidebar_visible())
  app.apply_action("files")
  assert_true(app.file_sidebar_visible())

  let commands = app.runtime(width=1180.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Files", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Recent", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "draft.md / Saved", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "notes.md", .. })
    }),
  )
}

///|
test "markdown editor runtime files shortcuts toggle sidebar" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=1180.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="p",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.file_sidebar_visible())
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="p",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_false(meta_app.file_sidebar_visible())

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=1180.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="p",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_app.file_sidebar_visible())
}

///|
test "markdown editor document info panel shows structural stats" {
  let app = MarkdownEditorApp::new()
  app.set_document(
    "# Title\n\nParagraph with [link](https://wzzc-dev.github.io/MoUI), ![alt](img.png), and footnote[^1].\n\n- [x] Done\n- [ ] Todo\n- Bullet\n\n> Quote\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n```mbt\nlet x = 1\n```\n\n[^1]: note",
  )
  assert_false(app.document_info_visible())
  app.apply_action("document-info")
  assert_true(app.document_info_visible())
  let info = app.document_info_for_test()
  inspect(info.heading_count, content="1")
  inspect(info.paragraph_count, content="1")
  inspect(info.list_item_count, content="3")
  inspect(info.task_count, content="2")
  inspect(info.checked_task_count, content="1")
  inspect(info.quote_count, content="1")
  inspect(info.code_block_count, content="1")
  inspect(info.table_count, content="1")
  inspect(info.link_count, content="1")
  inspect(info.image_count, content="1")
  inspect(info.footnote_reference_count, content="1")
  inspect(info.footnote_definition_count, content="1")

  let commands = app.runtime(width=1180.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Info", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Headings", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Tasks", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Footnotes", .. })
    }),
  )
}

///|
test "markdown editor runtime document info shortcuts toggle panel" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=1180.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.document_info_visible())
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_false(meta_app.document_info_visible())

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=1180.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_app.document_info_visible())
}

///|
test "markdown editor quick format can toggle document info" {
  let app = MarkdownEditorApp::new()
  app.apply_action("format-palette")
  app.set_format_palette_query("document info")
  app.update_in_place(ApplyFirstFormatPaletteAction)
  assert_true(app.document_info_visible())
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor quick format can request html export" {
  let app = MarkdownEditorApp::new()
  app.apply_action("format-palette")
  app.set_format_palette_query("export html")
  app.update_in_place(ApplyFirstFormatPaletteAction)
  assert_false(app.format_palette_visible())
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("html export requires host services"),
  )
}

///|
test "markdown editor file save as dialog cancellation preserves dirty document" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let seen_title = Ref("")
  let seen_default_name = Ref("")
  let app = MarkdownEditorApp::new()
  app.edit_document("# Unsaved")
  let services = markdown_editor_file_dialog_services(
    selected_path="",
    seen_kind~,
    seen_title~,
    seen_default_name~,
  )

  app.save_as_dialog_for_test(services)
  assert_true(seen_kind.val == @host.HostFileDialogKind::SaveFile)
  inspect(app.document_path(), content="")
  assert_true(app.dirty())
  inspect(app.transfer_status_label_for_test(), content="Save cancelled")
}

///|
test "markdown editor undo redo updates dirty state against saved document" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  assert_false(app.dirty())
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  assert_true(app.dirty())
  inspect(app.document(), content="Text **bold**")

  assert_true(app.undo())
  inspect(app.document(), content="Text bold")
  assert_false(app.dirty())

  assert_true(app.redo())
  inspect(app.document(), content="Text **bold**")
  assert_true(app.dirty())
  app.mark_saved_for_test()
  assert_false(app.dirty())
}

///|
test "markdown editor chrome renders document workflow state" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Plan", path="/tmp/plan.md")
  app.edit_document("# Plan\n\nNext")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  // Chrome renders the document title (filename) and save state as separate
  // text elements after the status bar redesign (e337e41d).
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text.contains("plan.md")
        _ => false
      }
    }),
  )
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text.contains("Unsaved")
        _ => false
      }
    }),
  )
  // The toolbar is now icon-driven, so it renders DrawPath icon glyphs rather
  // than text labels. At least one icon glyph must be present in the chrome.
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawPath(_)),
  )
}

///|
test "markdown editor runtime document shortcuts save and create clean documents" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Draft", path="/tmp/draft.md")
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let seen_title = Ref("")
  let seen_default_name = Ref("")
  let services = markdown_editor_document_services(
    read_text="# Imported",
    selected_path="/tmp/draft.md",
    seen_kind~,
    seen_title~,
    seen_default_name~,
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)
  app.edit_document("# Draft\n\nChanged")
  assert_true(app.dirty())
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_false(app.dirty())
  inspect(app.saved_document(), content="# Draft\n\nChanged")
  inspect(app.transfer_status_label_for_test(), content="Saved draft.md")

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="n",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="")
  inspect(app.document_path(), content="")
  assert_false(app.dirty())
}

///|
test "markdown editor runtime save on unnamed document chooses save location" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let seen_title = Ref("")
  let seen_default_name = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# First Save")
  app.edit_document("# First Save\n\nDraft")
  let services = markdown_editor_document_services(
    read_text="",
    selected_path="/tmp/first-save.md",
    seen_kind~,
    seen_title~,
    seen_default_name~,
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )

  assert_true(seen_kind.val == @host.HostFileDialogKind::SaveFile)
  inspect(seen_title.val, content="Save Markdown")
  inspect(seen_default_name.val, content="First Save.md")
  inspect(app.document_path(), content="/tmp/first-save.md")
  inspect(app.saved_document(), content="# First Save\n\nDraft")
  assert_false(app.dirty())
  inspect(
    app.transfer_status_label_for_test(),
    content="Saved as first-save.md",
  )
}
