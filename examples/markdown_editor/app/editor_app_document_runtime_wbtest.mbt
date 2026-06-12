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
  assert_false(app.can_undo())
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
    "# Title\n\nParagraph with [link](https://moui.dev), ![alt](img.png), and footnote[^1].\n\n- [x] Done\n- [ ] Todo\n- Bullet\n\n> Quote\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n```mbt\nlet x = 1\n```\n\n[^1]: note",
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
  ignore(app.update(ApplyFirstFormatPaletteAction))
  assert_true(app.document_info_visible())
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor quick format can request html export" {
  let app = MarkdownEditorApp::new()
  app.apply_action("format-palette")
  app.set_format_palette_query("export html")
  ignore(app.update(ApplyFirstFormatPaletteAction))
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
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) =>
          text.contains("plan.md / Unsaved")
        _ => false
      }
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "New", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Save", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Open", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Save As", .. })
    }),
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
  assert_false(app.can_undo())
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

///|
test "markdown editor clipboard export writes canonical markdown source" {
  let written = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Draft\n\n**Bold** source")
  let services = markdown_editor_clipboard_services(read_text="", written~)

  app.export_clipboard_for_test(services)
  inspect(written.val, content="# Draft\n\n**Bold** source")
  inspect(app.transfer_status_label_for_test(), content="Markdown copied")
  assert_false(app.dirty())
}

///|
test "markdown editor html export renders document structure" {
  let app = MarkdownEditorApp::new()
  app.set_document(
    "# Draft\n\nParagraph with **bold** and [MoUI](https://moui.dev?a=1&b=2).\n\n![Alt & logo](assets/logo.png)\n\n- [x] Done\n- [ ] Todo\n\n| Name | Value |\n| :--- | ---: |\n| A | 1 |\n\n```mbt\nlet x = 1 < 2\n```\n\nAT&T > 1",
  )
  let html = app.html_export_for_test()
  assert_true(html.contains("<!doctype html>"))
  assert_true(html.contains("<title>Draft</title>"))
  assert_true(html.contains("<h1>Draft</h1>"))
  assert_true(html.contains("<strong>bold</strong>"))
  assert_true(
    html.contains("<a href=\"https://moui.dev?a=1&amp;b=2\">MoUI</a>"),
  )
  assert_true(
    html.contains("<img src=\"assets/logo.png\" alt=\"Alt &amp; logo\">"),
  )
  assert_true(
    html.contains(
      "<li class=\"task-list-item\"><input type=\"checkbox\" disabled checked> Done</li>",
    ),
  )
  assert_true(html.contains("<table>"))
  assert_true(html.contains("<th>Name</th>"))
  assert_true(html.contains("<td style=\"text-align:right\">1</td>"))
  assert_true(
    html.contains(
      "<pre><code class=\"language-mbt\">let x = 1 &lt; 2</code></pre>",
    ),
  )
  assert_true(html.contains("<p>AT&amp;T &gt; 1</p>"))
}

///|
test "markdown editor html export writes clipboard html" {
  let written = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Export\n\nText")
  let services = markdown_editor_clipboard_services(read_text="", written~)

  app.export_html_for_test(services)
  assert_true(written.val.contains("<title>Export</title>"))
  assert_true(written.val.contains("<h1>Export</h1>"))
  assert_true(written.val.contains("<p>Text</p>"))
  inspect(app.transfer_status_label_for_test(), content="HTML copied")
}

///|
test "markdown editor clipboard import loads markdown as clean document" {
  let written = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Old\n\nText")
  app.edit_document("# Old\n\nChanged")
  app.apply_action("find")
  app.update_find_query_for_test("Old")
  app.set_replace_text("New")
  assert_true(app.dirty())
  let services = markdown_editor_clipboard_services(
    read_text="# Imported\n\nFrom clipboard",
    written~,
  )

  app.import_clipboard_for_test(services)
  inspect(app.document(), content="# Imported\n\nFrom clipboard")
  inspect(app.document_path(), content="")
  assert_false(app.find_visible())
  inspect(app.find_query(), content="")
  inspect(app.replace_text(), content="")
  inspect(app.transfer_status_label_for_test(), content="Clipboard imported")
  assert_false(app.dirty())
  assert_false(app.can_undo())
}

///|
test "markdown editor clipboard transfer reports unavailable fallback" {
  let app = MarkdownEditorApp::new()
  app.apply_action("clipboard-import")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("clipboard import requires host services"),
  )
  app.apply_action("clipboard-export")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("clipboard export requires host services"),
  )
  app.apply_action("html-export")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("html export requires host services"),
  )
  app.apply_action("save-as")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("save as requires host file dialog services"),
  )
  app.apply_action("save")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("save requires host file dialog services"),
  )
  app.load_document_for_test("# Named", path="/tmp/named.md")
  app.apply_action("save")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("save requires host text file services"),
  )
}

///|
test "markdown editor opens current link target through host service" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Docs](https://moui.dev/docs)")
  app.set_selection(12, Some(@core.TextRange::new(start=7, end=11)))
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://moui.dev/docs")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor opens link target from current caret context" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Old](https://old.dev)")
  app.set_selection(10, None)
  inspect(app.link_target(), content="https://old.dev")
  app.edit_document("Visit [Docs](https://moui.dev/docs)")
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://moui.dev/docs")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor open target prefers edited link field" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Docs](https://moui.dev/docs)")
  app.set_selection(10, None)
  app.set_link_target("https://edited.dev")
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://edited.dev")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor opens image target through host service" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Logo ![Mark](https://moui.dev/logo.png)")
  app.set_selection(9, None)
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode")
  }
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://moui.dev/logo.png")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor open target prefers edited image field" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Logo ![Mark](https://moui.dev/logo.png)")
  app.set_selection(9, None)
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode")
  }
  app.set_image_target("https://cdn.example/logo.png")
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://cdn.example/logo.png")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor open target reports unavailable fallback" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Docs](https://moui.dev/docs)")
  app.set_selection(12, Some(@core.TextRange::new(start=7, end=11)))
  app.apply_action("open-target")
  assert_true(
    app
    .transfer_status_label_for_test()
    .contains("open target requires host services"),
  )
}

///|
test "markdown editor runtime open target shortcut uses host services" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Docs](https://moui.dev/docs)")
  let services = markdown_editor_link_services(opened~)
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)
  app.set_selection(12, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="o",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(opened.val, content="https://moui.dev/docs")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor runtime save as and open shortcuts use host services" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let seen_title = Ref("")
  let seen_default_name = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Runtime Export")
  app.edit_document("# Runtime Export\n\nChanged")
  let services = markdown_editor_document_services(
    read_text="# Runtime Import",
    selected_path="/tmp/runtime-export.md",
    seen_kind~,
    seen_title~,
    seen_default_name~,
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_true(seen_kind.val == @host.HostFileDialogKind::SaveFile)
  inspect(seen_title.val, content="Save Markdown")
  inspect(app.document_path(), content="/tmp/runtime-export.md")
  assert_false(app.dirty())
  inspect(
    app.transfer_status_label_for_test(),
    content="Saved as runtime-export.md",
  )

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="o",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="# Runtime Import")
  inspect(app.document_path(), content="/tmp/runtime-export.md")
  inspect(
    app.transfer_status_label_for_test(),
    content="Opened runtime-export.md",
  )
}

///|
test "markdown editor runtime export shortcut writes clipboard markdown" {
  let written = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Shortcut Export")
  let services = markdown_editor_clipboard_services(read_text="", written~)
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  inspect(written.val, content="# Shortcut Export")
  inspect(app.transfer_status_label_for_test(), content="Markdown copied")
}

///|
test "markdown editor runtime html export shortcut writes clipboard html" {
  let written = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("# Shortcut HTML")
  let services = markdown_editor_clipboard_services(read_text="", written~)
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(written.val.contains("<h1>Shortcut HTML</h1>"))
  inspect(app.transfer_status_label_for_test(), content="HTML copied")

  let control_written = Ref("")
  let control_app = MarkdownEditorApp::new()
  control_app.set_document("# Control HTML")
  let control_services = markdown_editor_clipboard_services(
    read_text="",
    written=control_written,
  )
  let control_runtime = control_app.runtime_with_services(
    control_services,
    width=980.0,
    height=640.0,
  )
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_written.val.contains("<h1>Control HTML</h1>"))
  inspect(control_app.transfer_status_label_for_test(), content="HTML copied")
}

///|
test "markdown editor runtime receives async clipboard import completion" {
  let queue = @host.HostServiceAsyncQueue::new()
  let services = markdown_editor_async_clipboard_read_services(queue)
  let app = MarkdownEditorApp::new()
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  inspect(app.transfer_status_label_for_test(), content="Waiting for clipboard")
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    services.complete(
      pending[0].id,
      @host.HostServiceResponse::ClipboardText("# Async Import"),
    ),
  )
  let commands = runtime.draw_commands()
  inspect(app.document(), content="# Async Import")
  inspect(app.transfer_status_label_for_test(), content="Clipboard imported")
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Async Import", .. })
    }),
  )
}

///|
test "markdown editor runtime receives async save as completion" {
  let queue = @host.HostServiceAsyncQueue::new()
  let services = markdown_editor_async_file_dialog_services(queue)
  let app = MarkdownEditorApp::new()
  app.set_document("# Async Save\n\nDraft")
  app.edit_document("# Async Save\n\nChanged")
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  ignore(runtime.draw_commands())
  inspect(
    app.transfer_status_label_for_test(),
    content="Waiting for save location",
  )
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  match pending[0].request {
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::SaveFile, title, default_name, .. }
    ) => {
      inspect(title, content="Save Markdown")
      match default_name {
        Some(name) => inspect(name, content="Async Save.md")
        None => fail("expected default file name")
      }
    }
    _ => fail("expected save file dialog request")
  }
  assert_true(
    services.complete(
      pending[0].id,
      @host.HostServiceResponse::FileDialogSelection(["/tmp/async-save.md"]),
    ),
  )
  let mut write_pending = services.drain_pending()
  if write_pending.length() == 0 {
    app.apply_transfer_completion_with_services(
      {
        id: pending[0].id,
        request: pending[0].request,
        response: @host.HostServiceResponse::FileDialogSelection([
          "/tmp/async-save.md",
        ]),
      },
      services,
    )
    write_pending = services.drain_pending()
  }
  inspect(
    app.transfer_status_label_for_test(),
    content="Waiting for save location",
  )
  inspect(write_pending.length(), content="1")
  match write_pending[0].request {
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::WriteText(path, text)
    ) => {
      inspect(path, content="/tmp/async-save.md")
      inspect(text, content="# Async Save\n\nChanged")
    }
    _ => fail("expected text file write request")
  }
  assert_true(
    services.complete(
      write_pending[0].id,
      @host.HostServiceResponse::TextFileWritten("/tmp/async-save.md"),
    ),
  )
  app.apply_transfer_completion_with_services(
    {
      id: write_pending[0].id,
      request: write_pending[0].request,
      response: @host.HostServiceResponse::TextFileWritten("/tmp/async-save.md"),
    },
    services,
  )
  let commands = runtime.draw_commands()
  inspect(app.document_path(), content="/tmp/async-save.md")
  assert_false(app.dirty())
  inspect(app.transfer_status_label_for_test(), content="Saved async-save.md")
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) =>
          text.contains("async-save.md / Saved")
        _ => false
      }
    }),
  )
}
