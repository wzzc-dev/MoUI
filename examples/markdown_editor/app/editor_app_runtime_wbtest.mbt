///|
test "markdown editor app emits primary wysiwyg commands" {
  let app = MarkdownEditorApp::new()
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Editor notes", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Editor notes", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "• ", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor page decoration keeps editor interactive" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  inspect(app.document(), content="Hi")
}

///|
test "markdown editor controlled runtime rebuilds after input" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Program path")),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Program path", .. })
    }),
  )
  assert_true(app.dirty())
}

///|
fn markdown_editor_begin_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands.filter(command => {
    command is @core.DrawCommand::BeginCachedLayer(_)
  }).length()
}

///|
fn markdown_editor_draw_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands.filter(command => {
    command is @core.DrawCommand::DrawCachedLayer(_)
  }).length()
}

///|
fn markdown_editor_has_cached_chrome_layer(
  commands : Array[@core.DrawCommand],
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::DrawCachedLayer(spec) =>
        spec.frame.size.height <= 48.0
      _ => false
    }
  })
}

///|
test "markdown editor text input keeps chrome cached" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  assert_true(
    markdown_editor_draw_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  assert_true(
    markdown_editor_draw_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  let frame = runtime.draw_frame()
  assert_true(markdown_editor_begin_cached_layer_count(frame.commands) > 0)
  assert_true(markdown_editor_draw_cached_layer_count(frame.commands) > 0)
  assert_true(markdown_editor_has_cached_chrome_layer(frame.commands))
}

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
  assert_true(app.document_status_label_for_test().contains("notes.md / Saved"))

  app.edit_document("# Title\n\nUpdated")
  assert_true(app.dirty())
  app.save_as_for_test("C:\\Users\\writer\\paper.md")
  assert_false(app.dirty())
  inspect(app.document_path(), content="C:\\Users\\writer\\paper.md")
  inspect(app.saved_document(), content="# Title\n\nUpdated")
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

///|
test "markdown editor toggles source preview from action" {
  let app = MarkdownEditorApp::new()
  inspect(app.source_preview_visible(), content="false")
  app.apply_action("source-preview")
  inspect(app.source_preview_visible(), content="true")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor runtime source preview shortcuts toggle inspector" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="/",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.source_preview_visible())
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="/",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_false(meta_app.source_preview_visible())

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="/",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.source_preview_visible())
}

///|
test "markdown editor toggles outline sidebar from action" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n## Section\nBody")
  assert_false(app.outline_visible())
  app.apply_action("outline")
  assert_true(app.outline_visible())
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Outline", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "H1 Title", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "H2 Section", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor runtime outline shortcuts toggle sidebar" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("# Title\n\nBody")
  let meta_runtime = meta_app.runtime(width=1120.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="o",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.outline_visible())
  assert_true(
    meta_runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text: "Outline", .. })
    }),
  )
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="o",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_false(meta_app.outline_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("# Title\n\nBody")
  let control_runtime = control_app.runtime(width=1120.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="o",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_app.outline_visible())
}

///|
test "markdown editor outline jump updates caret block and scroll" {
  let app = MarkdownEditorApp::new()
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  app.set_document(lead + "## Second\nTail")
  let snapshot = MarkdownEditorSnapshot::parse(app.document())
  app.jump_to_outline_for_test(snapshot.outline[1].source_start)
  inspect(app.block_label(), content="Heading 2")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[1].source_start.to_string(),
  )
  assert_true(app.editor_scroll_y() > 0.0)
}

///|
test "markdown editor heading navigation actions wrap through outline" {
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\nBody\n\n## Second\nTail\n\n### Third")
  let snapshot = MarkdownEditorSnapshot::parse(app.document())
  app.set_selection(0, None)
  app.apply_action("next-heading")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[0].source_start.to_string(),
  )
  app.apply_action("next-heading")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[1].source_start.to_string(),
  )
  app.apply_action("next-heading")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[2].source_start.to_string(),
  )
  app.apply_action("next-heading")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[0].source_start.to_string(),
  )
  app.apply_action("previous-heading")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[2].source_start.to_string(),
  )
}

///|
test "markdown editor runtime heading navigation shortcuts jump outline" {
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\nBody\n\n## Second\nTail")
  let runtime = app.runtime(width=1120.0, height=640.0)
  let snapshot = MarkdownEditorSnapshot::parse(app.document())
  app.set_selection(snapshot.outline[0].source_start, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  inspect(
    app.selection_caret(),
    content=snapshot.outline[1].source_start.to_string(),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowUp",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  inspect(
    app.selection_caret(),
    content=snapshot.outline[0].source_start.to_string(),
  )
}

///|
test "markdown editor runtime outline click jumps to heading" {
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\n## Second\nTail")
  app.set_outline_visible(true)
  let runtime = app.runtime(width=1120.0, height=640.0)
  let snapshot = MarkdownEditorSnapshot::parse(app.document())
  guard markdown_editor_text_frame(runtime.draw_commands(), "H2 Second")
    is Some(frame) else {
    fail("expected outline heading row")
  }
  let point = @core.Point::new(x=frame.origin.x + 4.0, y=frame.origin.y + 4.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
  inspect(app.block_label(), content="Heading 2")
  inspect(
    app.selection_caret(),
    content=snapshot.outline[1].source_start.to_string(),
  )
}

///|
test "markdown editor runtime outline rows indent by heading level" {
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\n## Second\n\n### Third")
  app.set_outline_visible(true)
  let runtime = app.runtime(width=1120.0, height=640.0)
  guard markdown_editor_text_frame(runtime.draw_commands(), "H1 First")
    is Some(first) else {
    fail("expected first outline row")
  }
  guard markdown_editor_text_frame(runtime.draw_commands(), "H2 Second")
    is Some(second) else {
    fail("expected second outline row")
  }
  guard markdown_editor_text_frame(runtime.draw_commands(), "H3 Third")
    is Some(third) else {
    fail("expected third outline row")
  }
  assert_true(second.origin.x > first.origin.x)
  assert_true(third.origin.x > second.origin.x)
}

///|
test "markdown editor toggles find panel from action" {
  let app = MarkdownEditorApp::new()
  assert_false(app.find_visible())
  app.apply_action("find")
  assert_true(app.find_visible())
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Replace", .. })
    }),
  )
  inspect(app.find_query(), content="")
  inspect(app.replace_text(), content="")
}

///|
test "markdown editor find opens with selected source text as query" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha beta gamma beta")
  app.set_selection(10, Some(@core.TextRange::new(start=6, end=10)))
  app.apply_action("find")
  assert_true(app.find_visible())
  inspect(app.find_query(), content="beta")
  guard app.selection.get().selection is Some(range) else {
    fail("expected original selection to remain active")
  }
  inspect(range.start, content="6")
  inspect(range.end, content="10")

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_find_query("old")
  app.edit_document("alpha beta\ngamma beta")
  app.set_selection(16, Some(@core.TextRange::new(start=6, end=16)))
  app.apply_action("find")
  inspect(app.find_query(), content="old")

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_find_query("stale")
  app.set_replace_text("replacement")
  app.set_document("fresh document")
  inspect(app.find_query(), content="")
  inspect(app.replace_text(), content="")
}

///|
test "markdown editor find opens with caret word as query" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha beta gamma beta")
  app.set_selection(8, None)
  app.apply_action("find")
  assert_true(app.find_visible())
  inspect(app.find_query(), content="beta")
  inspect(app.selection_caret(), content="10")
  guard app.selection.get().selection is Some(range) else {
    fail("expected caret word to become active match")
  }
  inspect(range.start, content="6")
  inspect(range.end, content="10")
  let matched = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    matched.any(command => {
      command is @core.DrawCommand::DrawText({ text: "1/2", .. })
    }),
  )

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_find_query("old")
  app.set_selection(10, None)
  app.apply_action("find")
  inspect(app.find_query(), content="beta")
  guard app.selection.get().selection is Some(end_range) else {
    fail("expected word-end caret to seed query")
  }
  inspect(end_range.start, content="6")
  inspect(end_range.end, content="10")

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_document("alpha, beta")
  app.set_find_query("stale")
  app.set_selection(6, None)
  app.apply_action("find")
  inspect(app.find_query(), content="stale")
  guard app.selection.get().selection is None else {
    fail("expected punctuation gap to keep selection collapsed")
  }
}

///|
test "markdown editor find next selects match and scrolls into view" {
  let app = MarkdownEditorApp::new()
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  let first = markdown_editor_text_length(lead)
  app.set_document(lead + "needle near end\nneedle tail")
  app.set_find_query("needle")

  app.find_next_for_test()
  assert_true(app.find_visible())
  let selection = app.selection.get()
  inspect(selection.caret, content=(first + 6).to_string())
  guard selection.selection is Some(range) else {
    fail("expected selected first match")
  }
  inspect(range.start, content=first.to_string())
  inspect(range.end, content=(first + 6).to_string())
  assert_true(app.editor_scroll_y() > 0.0)

  app.find_next_for_test()
  let next_selection = app.selection.get()
  guard next_selection.selection is Some(next_range) else {
    fail("expected selected next match")
  }
  inspect(next_range.start, content=(first + 16).to_string())
  inspect(next_range.end, content=(first + 22).to_string())
}

///|
test "markdown editor find query input selects live match" {
  let app = MarkdownEditorApp::new()
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  let first = markdown_editor_text_length(lead)
  app.set_document(lead + "needle near end\nneedle tail")
  app.apply_action("find")

  app.update_find_query_for_test("n")
  let first_selection = app.selection.get()
  guard first_selection.selection is Some(first_range) else {
    fail("expected live first-character match")
  }
  inspect(first_range.start, content=first.to_string())
  inspect(first_range.end, content=(first + 1).to_string())
  assert_true(app.editor_scroll_y() > 0.0)

  app.update_find_query_for_test("needle")
  let refined_selection = app.selection.get()
  guard refined_selection.selection is Some(refined_range) else {
    fail("expected refined query to keep active match")
  }
  inspect(refined_range.start, content=first.to_string())
  inspect(refined_range.end, content=(first + 6).to_string())
}

///|
test "markdown editor clearing find query collapses active match selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha needle beta")
  app.apply_action("find")
  app.update_find_query_for_test("needle")
  guard app.selection.get().selection is Some(match_range) else {
    fail("expected live match selection")
  }
  inspect(match_range.start, content="6")
  inspect(match_range.end, content="12")

  app.update_find_query_for_test("")
  inspect(app.find_query(), content="")
  inspect(app.selection_caret(), content="12")
  guard app.selection.get().selection is None else {
    fail("expected cleared find query to collapse selection")
  }
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Ready", .. })
    }),
  )
}

///|
test "markdown editor unmatched find query collapses stale match selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha needle beta")
  app.apply_action("find")
  app.update_find_query_for_test("needle")
  guard app.selection.get().selection is Some(match_range) else {
    fail("expected live match selection")
  }
  inspect(match_range.start, content="6")
  inspect(match_range.end, content="12")

  app.update_find_query_for_test("missing")
  inspect(app.find_query(), content="missing")
  inspect(app.selection_caret(), content="12")
  guard app.selection.get().selection is None else {
    fail("expected unmatched query to collapse stale find selection")
  }
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No match", .. })
    }),
  )
}

///|
test "markdown editor find ignores ascii case while preserving source range" {
  let app = MarkdownEditorApp::new()
  app.set_document("Needle first\nmiddle\nNEEDLE last")
  app.apply_action("find")

  app.update_find_query_for_test("needle")
  let selection = app.selection.get()
  guard selection.selection is Some(range) else {
    fail("expected case-insensitive live match")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="6")

  app.find_next_for_test()
  guard app.selection.get().selection is Some(next_range) else {
    fail("expected second case-insensitive match")
  }
  inspect(next_range.start, content="20")
  inspect(next_range.end, content="26")
}

///|
test "markdown editor find bar reports ready no match and match count" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha, beta")
  app.set_selection(6, None)
  app.apply_action("find")
  let ready = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    ready.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Ready", .. })
    }),
  )

  app.update_find_query_for_test("missing")
  let missing = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    missing.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No match", .. })
    }),
  )

  app.update_find_query_for_test("beta")
  let matched = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    matched.any(command => {
      command is @core.DrawCommand::DrawText({ text: "1/1", .. })
    }),
  )
}

///|
test "markdown editor find previous wraps from caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("needle first\nmiddle\nneedle last")
  app.set_find_query("needle")
  app.set_selection(0, None)
  app.find_previous_for_test()
  let selection = app.selection.get()
  guard selection.selection is Some(range) else {
    fail("expected wrapped previous match")
  }
  inspect(range.start, content="20")
  inspect(range.end, content="26")
}

///|
test "markdown editor replace current pushes undo and redo history" {
  let app = MarkdownEditorApp::new()
  app.set_document("one Needle two needle")
  app.set_find_query("needle")
  app.set_replace_text("pin")

  app.find_next_for_test()
  app.replace_current_find_match_for_test()
  inspect(app.document(), content="one pin two needle")
  assert_true(app.dirty())
  let selection = app.selection.get()
  guard selection.selection is Some(range) else {
    fail("expected selected next match")
  }
  inspect(range.start, content="12")
  inspect(range.end, content="18")

  assert_true(app.undo())
  inspect(app.document(), content="one Needle two needle")
  assert_false(app.dirty())
  assert_true(app.redo())
  inspect(app.document(), content="one pin two needle")
}

///|
test "markdown editor replace current wraps to previous remaining match" {
  let app = MarkdownEditorApp::new()
  app.set_document("needle first\nmiddle\nneedle last")
  app.set_find_query("needle")
  app.set_replace_text("pin")
  app.set_selection(26, Some(@core.TextRange::new(start=20, end=26)))

  app.replace_current_find_match_for_test()
  inspect(app.document(), content="needle first\nmiddle\npin last")
  let selection = app.selection.get()
  guard selection.selection is Some(range) else {
    fail("expected wrapped remaining match")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="6")
}

///|
test "markdown editor replace all updates non-overlapping source matches" {
  let app = MarkdownEditorApp::new()
  app.set_document("aa aa aaa")
  app.set_find_query("aa")
  app.set_replace_text("b")

  app.replace_all_find_matches_for_test()
  inspect(app.document(), content="b b ba")
  assert_true(app.dirty())
  guard app.selection.get().selection is Some(range) else {
    fail("expected selected first replacement")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="1")

  assert_true(app.undo())
  inspect(app.document(), content="aa aa aaa")
}

///|
test "markdown editor runtime find shortcuts open panel" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("Find selected text")
  meta_app.set_selection(13, Some(@core.TextRange::new(start=5, end=13)))
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())
  inspect(meta_app.find_query(), content="selected")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("Find control text")
  control_app.set_selection(12, Some(@core.TextRange::new(start=5, end=12)))
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
  inspect(control_app.find_query(), content="control")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
}

///|
test "markdown editor runtime find replace shortcuts open panel" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("Find replace selected text")
  meta_app.set_selection(21, Some(@core.TextRange::new(start=13, end=21)))
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())
  inspect(meta_app.find_query(), content="selected")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("alpha beta gamma")
  control_app.set_selection(8, None)
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="h",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
  inspect(control_app.find_query(), content="beta")
  guard control_app.selection.get().selection is Some(range) else {
    fail("expected control find-replace shortcut to select caret word")
  }
  inspect(range.start, content="6")
  inspect(range.end, content="10")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="h",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
}

///|
test "markdown editor runtime find navigation shortcuts move and close panel" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("needle first\nmiddle\nneedle last")
  meta_app.set_find_query("needle")
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_app.set_selection(0, None)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())
  guard meta_app.selection.get().selection is Some(first_range) else {
    fail("expected meta find-next selection")
  }
  inspect(first_range.start, content="0")
  inspect(first_range.end, content="6")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  guard meta_app.selection.get().selection is Some(next_range) else {
    fail("expected second meta find-next selection")
  }
  inspect(next_range.start, content="20")
  inspect(next_range.end, content="26")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  guard meta_app.selection.get().selection is Some(previous_range) else {
    fail("expected meta find-previous selection")
  }
  inspect(previous_range.start, content="0")
  inspect(previous_range.end, content="6")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(meta_app.find_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("one hit two hit")
  control_app.set_find_query("hit")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(0, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  guard control_app.selection.get().selection is Some(control_range) else {
    fail("expected control find-next selection")
  }
  inspect(control_range.start, content="4")
  inspect(control_range.end, content="7")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  guard control_app.selection.get().selection is Some(wrapped_range) else {
    fail("expected control find-previous wrap selection")
  }
  inspect(wrapped_range.start, content="12")
  inspect(wrapped_range.end, content="15")
}

///|
test "markdown editor runtime escape dismisses auxiliary panels after find" {
  let app = MarkdownEditorApp::new()
  app.set_source_preview_visible(true)
  app.set_outline_visible(true)
  app.set_selection(8, Some(@core.TextRange::new(start=0, end=8)))
  app.apply_action("find")
  assert_true(app.find_visible())
  assert_true(app.source_preview_visible())
  assert_true(app.outline_visible())
  let runtime = app.runtime(width=1180.0, height=680.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(app.find_visible())
  assert_true(app.source_preview_visible())
  assert_true(app.outline_visible())
  guard app.selection.get().selection is Some(find_range) else {
    fail("expected selection to survive find dismissal")
  }
  inspect(find_range.start, content="0")
  inspect(find_range.end, content="8")

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(app.source_preview_visible())
  assert_false(app.outline_visible())
  guard app.selection.get().selection is Some(panel_range) else {
    fail("expected selection to survive panel dismissal")
  }
  inspect(panel_range.start, content="0")
  inspect(panel_range.end, content="8")
}

///|
test "markdown editor runtime escape collapses selection when panels are gone" {
  let app = MarkdownEditorApp::new()
  app.set_document("Selected text")
  app.set_selection(8, Some(@core.TextRange::new(start=0, end=8)))
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  inspect(app.selection_caret(), content="8")
  guard app.selection.get().selection is None else {
    fail("expected selection to collapse")
  }
}

///|
test "markdown editor status reports active inline format" {
  inspect(
    markdown_editor_active_format_suffix(
      "Text **bold** and [MoUI](https://moui.dev)",
      { caret: 9, selection: None },
    ),
    content=" / Active: Bold",
  )
  inspect(
    markdown_editor_active_format_suffix(
      "Text **bold** and [MoUI](https://moui.dev)",
      { caret: 21, selection: None },
    ),
    content=" / Active: Link",
  )
  inspect(
    markdown_editor_active_format_suffix("Plain", { caret: 2, selection: None }),
    content="",
  )
}

///|
test "markdown editor toolbar active state follows caret context" {
  let source = "# Title\n\nText **bold** and [MoUI](https://moui.dev)\n- item\n> quote"
  inspect(
    markdown_editor_command_active(source, { caret: 17, selection: None }, Bold),
    content="true",
  )
  inspect(
    markdown_editor_command_active(source, { caret: 30, selection: None }, Link),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 3, selection: None },
      Heading(1),
    ),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 55, selection: None },
      BulletList,
    ),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 63, selection: None },
      Quote,
    ),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 17, selection: None },
      Italic,
    ),
    content="false",
  )
}

///|
test "markdown editor floats contextual palette over editor surface" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let commands = app.runtime(width=980.0, height=700.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Visit ") is Some(editor_text) else {
    fail("expected editor text frame")
  }
  guard markdown_editor_text_frame(commands, "Link target")
    is Some(palette_text) else {
    fail("expected floating palette text frame")
  }
  assert_true(palette_text.origin.y > editor_text.origin.y)
  assert_true(palette_text.origin.y - editor_text.origin.y < 80.0)
}

///|
test "markdown editor hides contextual palette in plain writing mode" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)\n\nTail")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let top_commands = app.runtime(width=980.0, height=700.0).draw_commands()
  guard markdown_editor_text_frame(top_commands, "Link target")
    is Some(top_palette) else {
    fail("expected top palette")
  }
  app.set_selection(35, None)
  let lower_commands = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_false(
    markdown_editor_text_frame(lower_commands, "Link target") is Some(_),
  )
  assert_false(
    markdown_editor_text_frame(lower_commands, "Image src") is Some(_),
  )
  assert_true(top_palette.origin.y > 0.0)
}

///|
test "markdown editor app inline command uses tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  app.set_selection(7, Some(@core.TextRange::new(start=2, end=7)))
  app.apply_command_to_selection(Code)
  inspect(app.document(), content="# `Title`")
}

///|
test "markdown editor app inline command toggles tracked formatted selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor app reference commands toggle caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://example.com) and ![logo](image.png)")
  app.set_selection(9, None)
  app.apply_command_to_selection(Link)
  inspect(app.document(), content="Visit MoUI and ![logo](image.png)")
  app.set_selection(20, None)
  app.apply_command_to_selection(Image)
  inspect(app.document(), content="Visit MoUI and logo")
}

///|
test "markdown editor app undo and redo structured formatting commands" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="Text **bold**")
  assert_true(app.can_undo())
  assert_false(app.can_redo())
  assert_true(app.undo())
  inspect(app.document(), content="Text bold")
  assert_true(app.can_redo())
  assert_true(app.redo())
  inspect(app.document(), content="Text **bold**")
}

///|
test "markdown editor app undo and redo block duplicate command" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\nBeta")
  app.set_selection(8, None)
  app.apply_action("duplicate-block")
  inspect(app.document(), content="Alpha\nBeta\nBeta")
  inspect(app.selection_caret(), content="13")
  assert_true(app.can_undo())
  assert_true(app.undo())
  inspect(app.document(), content="Alpha\nBeta")
  assert_true(app.redo())
  inspect(app.document(), content="Alpha\nBeta\nBeta")
}

///|
test "markdown editor app undo and redo selected block range move command" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\nBeta\nGamma")
  app.set_selection(8, Some(@core.TextRange::new(start=1, end=10)))
  app.apply_action("move-block-down")
  inspect(app.document(), content="Gamma\nAlpha\nBeta")
  inspect(app.selection_caret(), content="14")
  guard app.selection.get().selection is Some(moved_selection) else {
    fail("expected moved block range selection")
  }
  inspect(moved_selection.start, content="7")
  inspect(moved_selection.end, content="16")
  assert_true(app.can_undo())
  assert_true(app.undo())
  inspect(app.document(), content="Alpha\nBeta\nGamma")
  assert_true(app.redo())
  inspect(app.document(), content="Gamma\nAlpha\nBeta")
}

///|
test "markdown editor app undo and redo target edits" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
  assert_true(app.undo())
  inspect(app.document(), content="Visit [MoUI](https://old.example)")
  assert_true(app.redo())
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
}

///|
test "markdown editor app clears command history on document reset" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  assert_true(app.can_undo())
  app.set_document("Fresh")
  assert_false(app.can_undo())
  assert_false(app.undo())
  inspect(app.document(), content="Fresh")
  app.apply_command_to_selection(Bold)
  assert_true(app.can_undo())
  app.clear()
  assert_false(app.can_undo())
}

///|
test "markdown editor app target inputs sync from selection and apply edits" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  inspect(app.block_label(), content="Paragraph")
  guard app.target_kind() is PlainSelection else {
    fail("expected plain target mode")
  }
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  guard app.target_kind() is LinkTarget else {
    fail("expected link target mode")
  }
  inspect(app.link_target(), content="https://old.example")
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](old.png)",
  )
  app.set_document("Mail <hello@example.dev>")
  app.set_selection(23, Some(@core.TextRange::new(start=6, end=23)))
  guard app.target_kind() is LinkTarget else {
    fail("expected email autolink target mode")
  }
  inspect(app.link_target(), content="hello@example.dev")
  app.set_link_target("team@example.dev")
  app.apply_link_target()
  inspect(app.document(), content="Mail <team@example.dev>")
  app.set_document("Visit [MoUI](https://moui.dev) and ![logo](old.png)")
  app.set_selection(41, Some(@core.TextRange::new(start=37, end=41)))
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode")
  }
  inspect(app.image_target(), content="old.png")
  app.set_image_target("assets/logo.png")
  app.apply_image_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)",
  )
  app.set_selection(5, Some(@core.TextRange::new(start=0, end=5)))
  guard app.target_kind() is PlainSelection else {
    fail("expected plain target mode after non-target selection")
  }
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(26, None)
  guard app.target_kind() is TableTools else {
    fail("expected table tools mode")
  }
  app.set_document("```moonbit\nlet x = 1\n```")
  app.set_selection(15, None)
  guard app.target_kind() is PlainSelection else {
    fail("expected direct code source editing mode")
  }
  app.set_document("Note[^a]\n\n[^a]: Old text")
  app.set_selection(7, Some(@core.TextRange::new(start=6, end=7)))
  guard app.target_kind() is FootnoteTarget else {
    fail("expected footnote target mode")
  }
  inspect(app.footnote_text(), content="Old text")
  app.set_footnote_text("New text")
  app.apply_footnote_text()
  inspect(app.document(), content="Note[^a]\n\n[^a]: New text")
  app.set_document("Intro\n<div>Old</div>\nTail")
  app.set_selection(9, None)
  guard app.target_kind() is HtmlBlockTarget else {
    fail("expected html block target mode")
  }
  inspect(app.html_block_text(), content="<div>Old</div>")
  app.set_html_block_text("<section>New</section>")
  app.apply_html_block_text()
  inspect(app.document(), content="Intro\n<section>New</section>\nTail")
}

///|
test "markdown editor link and image target bars show open action" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let link_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    link_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Open", .. })
    }),
  )
  app.set_document("Logo ![mark](https://moui.dev/logo.png)")
  app.set_selection(9, None)
  let image_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    image_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Open", .. })
    }),
  )
}

///|
test "markdown editor app target inputs sync from caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  app.set_selection(9, None)
  guard app.target_kind() is LinkTarget else {
    fail("expected link target mode at caret")
  }
  inspect(app.link_target(), content="https://old.example")
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](old.png)",
  )

  app.set_selection(39, None)
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode at caret")
  }
  inspect(app.image_target(), content="old.png")
  app.set_image_target("assets/logo.png")
  app.apply_image_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)",
  )

  app.set_document("Mail <hello@example.dev>")
  app.set_selection(12, None)
  guard app.target_kind() is LinkTarget else {
    fail("expected autolink target mode at caret")
  }
  inspect(app.link_target(), content="hello@example.dev")
}

///|
test "markdown editor app block label syncs from selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n- item\nPlain")
  app.set_selection(3, None)
  inspect(app.block_label(), content="Heading 1")
  app.set_selection(10, None)
  inspect(app.block_label(), content="Bullet list")
  app.apply_command_to_selection(Paragraph)
  inspect(app.document(), content="# Title\nitem\nPlain")
  inspect(app.block_label(), content="Paragraph")
}

///|
test "markdown editor target bar renders contextual controls" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  let plain = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_false(
    plain.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Link target", .. })
    }),
  )
  assert_false(
    plain.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  assert_false(
    plain.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Table tools", .. })
    }),
  )
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let link = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    link.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Link target", .. })
    }),
  )
  assert_false(
    link.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  app.set_selection(44, Some(@core.TextRange::new(start=40, end=44)))
  let image = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    image.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(26, None)
  let table = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Table tools", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "+Row", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "+Col", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "-Col", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "-Row", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Center", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Auto", .. })
    }),
  )
  app.set_document("```moonbit\nlet x = 1\n```")
  app.set_selection(15, None)
  let code = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "```moonbit", .. })
    }),
  )
  assert_true(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "```", .. })
    }),
  )
  assert_false(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Code lang", .. })
    }),
  )
  app.set_document("Intro\n<div>Old</div>\nTail")
  app.set_selection(9, None)
  let html = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    html.any(command => {
      command is @core.DrawCommand::DrawText({ text: "HTML block", .. })
    }),
  )
}

///|
test "markdown editor runtime inline keyboard shortcut toggles selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text **bold**")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor runtime block editing shortcuts update document" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\nBeta\nGamma")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Alpha\nBeta\nBeta\nGamma")
  app.set_document("Alpha\nBeta\nGamma")
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowUp",
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
  inspect(app.document(), content="Beta\nAlpha\nGamma")
  app.set_selection(2, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
  inspect(app.document(), content="Alpha\nBeta\nGamma")
}

///|
test "markdown editor runtime ctrl inline shortcuts toggle selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold word")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text **bold** word")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold word")
  app.set_selection(14, Some(@core.TextRange::new(start=10, end=14)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold *word*")
}

///|
test "markdown editor runtime ctrl code and strike shortcuts toggle selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text code old")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text `code` old")
  app.set_selection(11, Some(@core.TextRange::new(start=6, end=10)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text code old")
  app.set_selection(13, Some(@core.TextRange::new(start=10, end=13)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Text code ~~old~~")
}

///|
test "markdown editor runtime typed marker wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("**")),
  )
  inspect(app.document(), content="**bold**")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="6")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="2")
  inspect(selection.end, content="6")
}

///|
test "markdown editor runtime underscore marker wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("__")),
  )
  inspect(app.document(), content="__bold__")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="6")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="2")
  inspect(selection.end, content="6")
}

///|
test "markdown editor runtime underline italic marker wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("old")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("_")),
  )
  inspect(app.document(), content="_old_")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="4")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="1")
  inspect(selection.end, content="4")
}

///|
test "markdown editor runtime link strike and image shortcuts use tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text link old logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="l",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text [link](https://example.com) old logo")
  app.set_selection(36, Some(@core.TextRange::new(start=33, end=36)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="Text [link](https://example.com) ~~old~~ logo",
  )
  app.set_selection(45, Some(@core.TextRange::new(start=41, end=45)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="Text [link](https://example.com) ~~old~~ ![logo](image.png)",
  )
}

///|
test "markdown editor runtime ctrl k wraps tracked selection as link" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit docs today")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(10, Some(@core.TextRange::new(start=6, end=10)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="k",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Visit [docs](https://example.com) today")
  let editor_selection = app.selection.get()
  inspect(editor_selection.caret, content="11")
  guard editor_selection.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor runtime ctrl image shortcut wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Insert logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Insert ![logo](image.png)")
}

///|
test "markdown editor runtime block keyboard shortcuts transform caret and selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle\nFirst\nSecond")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="2",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n## Title\nFirst\nSecond")
  app.set_selection(9, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="6",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n###### Title\nFirst\nSecond")
  app.set_selection(30, Some(@core.TextRange::new(start=19, end=31)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="u",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n###### Title\n- First\n- Second")
}

///|
test "markdown editor runtime ctrl code block shortcut toggles current line" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nlet x = 1\nTail")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="k",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n```\nlet x = 1\n```\nTail")
  app.set_selection(12, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="k",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\nlet x = 1\nTail")
}

///|
test "markdown editor runtime ctrl heading shortcuts transform caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="1",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n# Title")
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="3",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n### Title")
}

///|
test "markdown editor runtime paragraph and quote shortcuts transform blocks" {
  let meta_paragraph_app = MarkdownEditorApp::new()
  meta_paragraph_app.set_document("# Title")
  let meta_paragraph_runtime = meta_paragraph_app.runtime(
    width=980.0,
    height=640.0,
  )
  meta_paragraph_app.set_selection(3, None)
  meta_paragraph_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="0",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(meta_paragraph_app.document(), content="Title")
  let control_paragraph_app = MarkdownEditorApp::new()
  control_paragraph_app.set_document("# Title\n> Quote")
  let control_paragraph_runtime = control_paragraph_app.runtime(
    width=980.0,
    height=640.0,
  )
  control_paragraph_app.set_selection(
    15,
    Some(@core.TextRange::new(start=0, end=15)),
  )
  control_paragraph_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="0",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(control_paragraph_app.document(), content="Title\nQuote")
  let quote_app = MarkdownEditorApp::new()
  quote_app.set_document("First\nSecond")
  let quote_runtime = quote_app.runtime(width=980.0, height=640.0)
  quote_app.set_selection(12, Some(@core.TextRange::new(start=0, end=12)))
  quote_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="9",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(quote_app.document(), content="> First\n> Second")
  let shifted_quote_app = MarkdownEditorApp::new()
  shifted_quote_app.set_document("First\nSecond")
  let shifted_quote_runtime = shifted_quote_app.runtime(
    width=980.0,
    height=640.0,
  )
  shifted_quote_app.set_selection(
    12,
    Some(@core.TextRange::new(start=0, end=12)),
  )
  shifted_quote_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="(",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(shifted_quote_app.document(), content="> First\n> Second")
}

///|
test "markdown editor runtime ctrl shift list shortcuts transform selection" {
  let bullet_app = MarkdownEditorApp::new()
  bullet_app.set_document("First\nSecond")
  let bullet_runtime = bullet_app.runtime(width=980.0, height=640.0)
  bullet_app.set_selection(12, Some(@core.TextRange::new(start=0, end=12)))
  bullet_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="8",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(bullet_app.document(), content="- First\n- Second")
  let shifted_bullet_app = MarkdownEditorApp::new()
  shifted_bullet_app.set_document("First\nSecond")
  let shifted_bullet_runtime = shifted_bullet_app.runtime(
    width=980.0,
    height=640.0,
  )
  shifted_bullet_app.set_selection(
    12,
    Some(@core.TextRange::new(start=0, end=12)),
  )
  shifted_bullet_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="*",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(shifted_bullet_app.document(), content="- First\n- Second")
  let ordered_app = MarkdownEditorApp::new()
  ordered_app.set_document("First\nSecond")
  let ordered_runtime = ordered_app.runtime(width=980.0, height=640.0)
  ordered_app.set_selection(12, Some(@core.TextRange::new(start=0, end=12)))
  ordered_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="7",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(ordered_app.document(), content="1. First\n2. Second")
  let shifted_ordered_app = MarkdownEditorApp::new()
  shifted_ordered_app.set_document("First\nSecond")
  let shifted_ordered_runtime = shifted_ordered_app.runtime(
    width=980.0,
    height=640.0,
  )
  shifted_ordered_app.set_selection(
    12,
    Some(@core.TextRange::new(start=0, end=12)),
  )
  shifted_ordered_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="&",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(shifted_ordered_app.document(), content="1. First\n2. Second")
}

///|
test "markdown editor runtime enter continues bullet list" {
  let app = MarkdownEditorApp::new()
  app.set_document("- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="- item\n- ")
}

///|
test "markdown editor runtime enter inserts table row" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let mut target : @core.Rect? = None
  for command in runtime.draw_commands() {
    match command {
      @core.DrawCommand::DrawText({ text: "2", frame, .. }) =>
        target = Some(frame)
      _ => ()
    }
  }
  guard target is Some(frame) else { fail("expected rendered table cell") }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(runtime.focused_text_input().caret, content="39")
}

///|
test "markdown editor runtime enter in table header inserts first data row" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(runtime.draw_commands(), "B") is Some(frame) else {
    fail("expected rendered table header cell")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n|  |  |\n| 1 | 2 |",
  )
  inspect(runtime.focused_text_input().caret, content="29")
}

///|
test "markdown editor runtime tab appends row from final table cell" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(runtime.draw_commands(), "2") is Some(frame) else {
    fail("expected rendered final table cell")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(runtime.focused_text_input().caret, content="36")
}

///|
test "markdown editor runtime shift tab exits first table cell" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(runtime.draw_commands(), "A") is Some(frame) else {
    fail("expected rendered table header cell")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Tab",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  inspect(app.document(), content="\n| A | B |\n| --- | --- |\n| 1 | 2 |")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime shortcut inserts table column" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="=",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(30, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="=",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(
    control_app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )

  let plus_app = MarkdownEditorApp::new()
  plus_app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let plus_runtime = plus_app.runtime(width=980.0, height=640.0)
  plus_app.set_selection(30, None)
  plus_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="+",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(
    plus_app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
}

///|
test "markdown editor runtime shortcut inserts table row" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(30, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(
    control_app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
}

///|
test "markdown editor runtime shift enter inserts hard line break" {
  let app = MarkdownEditorApp::new()
  app.set_document("HelloWorld")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(5, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Hello  \nWorld")
  inspect(app.selection_caret(), content="8")
}

///|
test "markdown editor runtime table row shortcut no-ops outside tables" {
  let app = MarkdownEditorApp::new()
  app.set_document("Plain text")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(5, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Plain text")
}

///|
test "markdown editor runtime shortcut deletes table row" {
  let header_app = MarkdownEditorApp::new()
  header_app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  let header_runtime = header_app.runtime(width=980.0, height=640.0)
  header_app.set_selection(6, None)
  header_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="-",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    header_app.document(),
    content="|  |  |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |",
  )

  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="-",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(30, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="-",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(control_app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
}

///|
test "markdown editor runtime shortcut deletes table column" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(40, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="_",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(40, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="_",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(control_app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
}

///|
test "markdown editor runtime shortcuts set table column alignment" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_app.set_selection(40, None)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="r",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    meta_app.document(),
    content="| A | B | C |\n| --- | ---: | --- |\n| 1 | 2 | 3 |",
  )
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    meta_app.document(),
    content="| A | B | C |\n| --- | :---: | --- |\n| 1 | 2 | 3 |",
  )

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(40, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="l",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(
    control_app.document(),
    content="| A | B | C |\n| --- | :--- | --- |\n| 1 | 2 | 3 |",
  )
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="0",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(
    control_app.document(),
    content="| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |",
  )
}

///|
test "markdown editor runtime enter outdents nested empty list marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("- parent\n  - ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=112.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="- parent\n- ")
  inspect(runtime.focused_text_input().caret, content="11")
}

///|
test "markdown editor runtime tab indents focused line" {
  let app = MarkdownEditorApp::new()
  app.set_document("- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  inspect(app.document(), content="  - item")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Tab",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  inspect(app.document(), content="- item")
}

///|
test "markdown editor indent and outdent actions preserve history" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\n- one\n- two\nTail")
  app.set_selection(17, Some(@core.TextRange::new(start=6, end=17)))
  app.apply_action("indent-lines")
  inspect(app.document(), content="Intro\n  - one\n  - two\nTail")
  guard app.selection.get().selection is Some(indented_selection) else {
    fail("expected indented line selection")
  }
  inspect(indented_selection.start, content="6")
  inspect(indented_selection.end, content="21")
  assert_true(app.undo())
  inspect(app.document(), content="Intro\n- one\n- two\nTail")
  assert_true(app.redo())
  inspect(app.document(), content="Intro\n  - one\n  - two\nTail")

  app.apply_action("outdent-lines")
  inspect(app.document(), content="Intro\n- one\n- two\nTail")
}

///|
test "markdown editor runtime bracket shortcuts indent and outdent lines" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("- item")
  meta_app.set_selection(2, None)
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="]",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(meta_app.document(), content="  - item")
  inspect(meta_app.selection_caret(), content="4")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="[",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(meta_app.document(), content="- item")
  inspect(meta_app.selection_caret(), content="2")

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("Alpha\nBeta")
  control_app.set_selection(10, Some(@core.TextRange::new(start=0, end=10)))
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="]",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(control_app.document(), content="  Alpha\n  Beta")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="[",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(control_app.document(), content="Alpha\nBeta")
}

///|
test "markdown editor runtime backspace removes hidden heading marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Title")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime delete removes hidden block marker" {
  let heading_app = MarkdownEditorApp::new()
  heading_app.set_document("# Title")
  let heading_runtime = heading_app.runtime(width=980.0, height=640.0)
  heading_runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  heading_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  inspect(heading_runtime.focused_text_input().caret, content="0")
  heading_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(heading_app.document(), content="Title")
  inspect(heading_runtime.focused_text_input().caret, content="0")

  let task_app = MarkdownEditorApp::new()
  task_app.set_document("- [x] done")
  let task_runtime = task_app.runtime(width=980.0, height=640.0)
  task_runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  task_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  inspect(task_runtime.focused_text_input().caret, content="0")
  task_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(task_app.document(), content="done")
  inspect(task_runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime backspace and delete exit empty continuation markers" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(">>")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="> > ")
  inspect(runtime.focused_text_input().caret, content="4")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="> ")
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime backspace removes hidden inline marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor runtime backspace removes hidden link marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Visit MoUI")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "markdown editor runtime delete removes hidden link marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<11 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="Visit MoUI")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "markdown editor runtime backspace merges visual blocks" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<8 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="8")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Title item")
}

///|
test "markdown editor runtime delete merges visual blocks" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="Title item")
  inspect(runtime.focused_text_input().caret, content="5")
}

///|
test "markdown editor runtime delete preserves same-list merge" {
  let app = MarkdownEditorApp::new()
  app.set_document("- first\n- second")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="- first second")
  inspect(runtime.focused_text_input().caret, content="7")
}

///|
test "markdown editor runtime undo restores input transform caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("#")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(app.document(), content="#")
  inspect(runtime.focused_text_input().caret, content="1")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
}

///|
test "markdown editor runtime prefix click toggles task checkbox" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [x] todo")
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor runtime task shortcut toggles current checkbox" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="- [x] todo")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor copy exports visual text without hidden markdown markers" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n- [ ] **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let copied = runtime.dispatch_focused_text_command(@core.CommandIntent::Copy)
  assert_true(copied.handled)
  guard copied.clipboard_text is Some(text) else {
    fail("expected copied visual text")
  }
  inspect(text, content="Title\n\nbold")
}

///|
test "markdown editor cut exports visual text and deletes source selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n- [ ] **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let cut = runtime.dispatch_focused_text_command(@core.CommandIntent::Cut)
  assert_true(cut.handled)
  assert_true(cut.changed)
  guard cut.clipboard_text is Some(text) else {
    fail("expected cut visual text")
  }
  inspect(text, content="Title\n\nbold")
  inspect(app.document(), content="")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(app.document(), content="# Title\n\n- [ ] **bold**")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="")
}

///|
test "markdown editor paste command continues list context" {
  let app = MarkdownEditorApp::new()
  app.set_document("- one")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some(" two\nthree"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="- one two\n- three")
}

///|
test "markdown editor runtime unicode paste participates in undo redo" {
  let app = MarkdownEditorApp::new()
  app.set_document("Note ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("你好 👩‍💻"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Note 你好 👩‍💻")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(app.document(), content="Note ")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="Note 你好 👩‍💻")
}

///|
test "markdown editor paste command links selected text with url" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit MoUI")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<6 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://moui.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="11")
  guard input.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor paste command links selected text with email" {
  let app = MarkdownEditorApp::new()
  app.set_document("Email team")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<6 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("team@example.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Email [team](team@example.dev)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="11")
  guard input.selection is Some(selection) else {
    fail("expected email linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor paste command inserts image from selected alt text" {
  let app = MarkdownEditorApp::new()
  app.set_document("Insert logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("assets/logo.png"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Insert ![logo](assets/logo.png)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="13")
  guard input.selection is Some(selection) else {
    fail("expected image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor runtime paste and typing complete autolinks" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://moui.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit <https://moui.dev>")

  app.set_document("Visit https://moui.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Visit <https://moui.dev> ")

  app.set_document("Mail ")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted_email = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("hello@example.dev"),
  )
  assert_true(pasted_email.handled)
  assert_true(pasted_email.changed)
  inspect(app.document(), content="Mail <hello@example.dev>")

  app.set_document("Mail hello@example.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Mail <hello@example.dev> ")

  app.set_document("Visit https://moui.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="Visit <https://moui.dev>\n")
}

///|
test "markdown editor actions update canonical markdown" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("h1")
  inspect(app.document(), content="# Heading")
  app.clear()
  app.apply_action("h6")
  inspect(app.document(), content="###### Caption")
  app.clear()
  app.apply_action("bold")
  assert_true(app.document().contains("**bold text**"))
  app.apply_action("strike")
  assert_true(app.document().contains("~~old text~~"))
  app.apply_action("link")
  assert_true(app.document().contains("[link text](https://example.com)"))
  app.apply_action("link-target")
  assert_true(app.document().contains("[link text](https://moui.dev)"))
  app.apply_action("image")
  assert_true(app.document().contains("![image alt](image.png)"))
  app.apply_action("image-target")
  assert_true(app.document().contains("![image alt](assets/image.png)"))
  app.apply_action("code-language")
  assert_true(app.document().contains("```moonbit\ncode block\n```"))
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-row")
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-column")
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  app.set_selection(30, None)
  app.apply_action("table-row-delete")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  app.set_selection(40, None)
  app.apply_action("table-column-delete")
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  app.set_document("# Heading")
  app.set_selection(4, None)
  app.apply_action("paragraph")
  inspect(app.document(), content="Heading")
}

///|
test "markdown editor actions seed every supported action from empty document" {
  for
    expected in [
      "**bold text**", "*italic text*", "`code`", "~~old text~~", "[link text](https://example.com)",
      "[link text](https://moui.dev)", "![image alt](image.png)", "![image alt](assets/image.png)",
      "Paragraph", "# Heading", "## Section", "### Detail", "#### Subdetail", "##### Note",
      "###### Caption", "- List item", "- [ ] Task item", "1. List item", "> Quote",
      "---", "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |", "```\ncode block\n```",
    ] {
    let app = MarkdownEditorApp::new()
    app.clear()
    app.apply_action(markdown_action_from_seed(expected))
    inspect(app.document(), content=expected)
  }
}

///|
test "markdown editor actions apply actions at current caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Base")
  for
    action in [
      "bold", "italic", "code", "strike", "link", "image", "h1", "h2", "h3", "h4",
      "h5", "h6", "ul", "task", "ol", "quote", "codeblock",
    ] {
    app.apply_action(action)
  }
  let document = app.document()
  inspect(
    document,
    content="Base\n\n**bold text**\n\n*italic text*\n\n`code`\n\n~~old text~~\n\n[link text](https://example.com)\n\n> ```\n> ![image alt](image.png)\n> ```",
  )
  app.apply_action("unknown")
  inspect(app.document(), content=document)
}

///|
fn markdown_action_from_seed(expected : String) -> String {
  if expected == "**bold text**" {
    "bold"
  } else if expected == "*italic text*" {
    "italic"
  } else if expected == "`code`" {
    "code"
  } else if expected == "~~old text~~" {
    "strike"
  } else if expected == "[link text](https://example.com)" {
    "link"
  } else if expected == "[link text](https://moui.dev)" {
    "link-target"
  } else if expected == "![image alt](image.png)" {
    "image"
  } else if expected == "![image alt](assets/image.png)" {
    "image-target"
  } else if expected == "Paragraph" {
    "paragraph"
  } else if expected == "# Heading" {
    "h1"
  } else if expected == "## Section" {
    "h2"
  } else if expected == "### Detail" {
    "h3"
  } else if expected == "#### Subdetail" {
    "h4"
  } else if expected == "##### Note" {
    "h5"
  } else if expected == "###### Caption" {
    "h6"
  } else if expected == "- List item" {
    "ul"
  } else if expected == "- [ ] Task item" {
    "task"
  } else if expected == "1. List item" {
    "ol"
  } else if expected == "> Quote" {
    "quote"
  } else if expected == "---" {
    "rule"
  } else if expected ==
    "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |" {
    "table"
  } else {
    "codeblock"
  }
}

///|
test "markdown editor runtime typing updates document" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("#")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("- item")),
  )
  inspect(app.document(), content="# Hi\n- item")
}

///|
test "markdown editor runtime enter completes fenced code block" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("```moonbit")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="```moonbit\n\n```")
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("let x = 1")),
  )
  inspect(app.document(), content="```moonbit\nlet x = 1\n```")
}

///|
test "markdown editor clear redraws placeholder and optional empty source preview" {
  let app = MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  app.clear()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Start writing Markdown", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
  app.set_source_preview_visible(true)
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let source_commands = runtime.draw_commands()
  assert_true(
    source_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
}

///|
fn markdown_editor_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn markdown_editor_clipboard_services(
  read_text~ : String,
  written~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => @host.HostServiceResponse::ClipboardText(read_text)
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::WriteText(text)
        ) => {
          written.val = text
          @host.HostServiceResponse::ClipboardWritten
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_file_dialog_services(
  selected_path~ : String,
  seen_kind~ : Ref[@host.HostFileDialogKind],
  seen_title~ : Ref[String],
  seen_default_name~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(options) => {
          seen_kind.val = options.kind
          seen_title.val = options.title
          seen_default_name.val = match options.default_name {
            Some(name) => name
            None => ""
          }
          @host.HostServiceResponse::FileDialogSelection(
            if selected_path == "" {
              []
            } else {
              [selected_path]
            },
          )
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(path, _text)
        ) => @host.HostServiceResponse::TextFileWritten(path)
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => @host.HostServiceResponse::TextFileContent(path, "")
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_document_services(
  read_text~ : String,
  selected_path~ : String,
  seen_kind~ : Ref[@host.HostFileDialogKind],
  seen_title~ : Ref[String],
  seen_default_name~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => @host.HostServiceResponse::ClipboardText(read_text)
        @host.HostServiceRequest::FileDialog(options) => {
          seen_kind.val = options.kind
          seen_title.val = options.title
          seen_default_name.val = match options.default_name {
            Some(name) => name
            None => ""
          }
          @host.HostServiceResponse::FileDialogSelection(
            if selected_path == "" {
              []
            } else {
              [selected_path]
            },
          )
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => @host.HostServiceResponse::TextFileContent(path, read_text)
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(path, _text)
        ) => @host.HostServiceResponse::TextFileWritten(path)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_link_services(
  opened~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(open_url=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::OpenUrl(url) => {
          opened.val = url
          @host.HostServiceResponse::UrlOpened
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_async_clipboard_read_services(
  queue : @host.HostServiceAsyncQueue,
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~, async_queue=Some(queue))
}

///|
fn markdown_editor_async_file_dialog_services(
  queue : @host.HostServiceAsyncQueue,
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) => queue.submit(request)
        @host.HostServiceRequest::TextFile(_) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~, async_queue=Some(queue))
}
