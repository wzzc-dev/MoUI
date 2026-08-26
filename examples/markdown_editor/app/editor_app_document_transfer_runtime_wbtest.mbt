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
    "# Draft\n\nParagraph with **bold** and [MoUI](https://wzzc-dev.github.io/MoUI?a=1&b=2).\n\n![Alt & logo](assets/logo.png)\n\n- [x] Done\n- [ ] Todo\n\n| Name | Value |\n| :--- | ---: |\n| A | 1 |\n\n```mbt\nlet x = 1 < 2\n```\n\nAT&T > 1",
  )
  let html = app.html_export_for_test()
  assert_true(html.contains("<!doctype html>"))
  assert_true(html.contains("<title>Draft</title>"))
  assert_true(html.contains("<h1>Draft</h1>"))
  assert_true(html.contains("<strong>bold</strong>"))
  assert_true(
    html.contains("<a href=\"https://wzzc-dev.github.io/MoUI?a=1&amp;b=2\">MoUI</a>"),
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
test "markdown editor html export preserves raw image galleries" {
  let gallery =
    #|<div align="center">
    #|
    #|  <img src="resource/a.png" width="48%" alt="A"/>
    #|
    #|  <br/><br/>
    #|
    #|  <img src="resource/b.png" width="48%" alt="B"/>
    #|
    #|</div>
  let app = MarkdownEditorApp::new()
  app.set_document(gallery)
  let html = app.html_export_for_test()
  assert_true(html.contains(gallery))
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
  app.set_document("Visit [Docs](https://wzzc-dev.github.io/MoUI/docs)")
  app.set_selection(12, Some(@core.TextRange::new(start=7, end=11)))
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://wzzc-dev.github.io/MoUI/docs")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor opens link target from current caret context" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Old](https://old.dev)")
  app.set_selection(10, None)
  inspect(app.link_target(), content="https://old.dev")
  app.edit_document("Visit [Docs](https://wzzc-dev.github.io/MoUI/docs)")
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://wzzc-dev.github.io/MoUI/docs")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor open target prefers edited link field" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [Docs](https://wzzc-dev.github.io/MoUI/docs)")
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
  app.set_document("Logo ![Mark](https://wzzc-dev.github.io/MoUI/logo.png)")
  app.set_selection(9, None)
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode")
  }
  let services = markdown_editor_link_services(opened~)
  app.open_target_for_test(services)
  inspect(opened.val, content="https://wzzc-dev.github.io/MoUI/logo.png")
  inspect(app.transfer_status_label_for_test(), content="Target opened")
}

///|
test "markdown editor open target prefers edited image field" {
  let opened = Ref("")
  let app = MarkdownEditorApp::new()
  app.set_document("Logo ![Mark](https://wzzc-dev.github.io/MoUI/logo.png)")
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
  app.set_document("Visit [Docs](https://wzzc-dev.github.io/MoUI/docs)")
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
  app.set_document("Visit [Docs](https://wzzc-dev.github.io/MoUI/docs)")
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
  inspect(opened.val, content="https://wzzc-dev.github.io/MoUI/docs")
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
  let queue = @backend_common_services.ServiceAsyncQueue::new()
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
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
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
  let queue = @backend_common_services.ServiceAsyncQueue::new()
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
  let pending = queue.drain_pending()
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
    queue.complete(
      pending[0].id,
      @host.HostServiceResponse::FileDialogSelection(["/tmp/async-save.md"]),
    ),
  )
  let write_pending = queue.drain_pending()
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
    queue.complete(
      write_pending[0].id,
      @host.HostServiceResponse::TextFileWritten("/tmp/async-save.md"),
    ),
  )
  let commands = runtime.draw_commands()
  inspect(app.document_path(), content="/tmp/async-save.md")
  assert_false(app.dirty())
  inspect(
    app.transfer_status_label_for_test(),
    content="Saved as async-save.md",
  )
  // Chrome renders the document title (filename) and save state as separate
  // text elements after the status bar redesign (e337e41d).
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) =>
          text.contains("async-save.md")
        _ => false
      }
    }),
  )
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text.contains("Saved")
        _ => false
      }
    }),
  )
}
