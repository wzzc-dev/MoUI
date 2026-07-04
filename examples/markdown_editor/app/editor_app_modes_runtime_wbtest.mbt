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
test "markdown editor toggles source mode from action" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold** and `code`")
  assert_false(app.source_mode_enabled())
  let formatted = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_false(
    formatted.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Text **bold** and `code`", .. })
    }),
  )

  app.apply_action("source-mode")
  assert_true(app.source_mode_enabled())
  assert_true(app.document_status_label_for_test().contains("Source Mode"))
  let raw = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    raw.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Text **bold** and `code`", .. })
    }),
  )
  assert_false(
    raw.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Link target", .. })
    }),
  )
}

///|
test "markdown editor runtime source mode shortcuts toggle raw editing" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="/",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_true(meta_app.source_mode_enabled())
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="/",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_false(meta_app.source_mode_enabled())

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="/",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  assert_true(control_app.source_mode_enabled())
}

///|
test "markdown editor quick format can toggle source mode" {
  let app = MarkdownEditorApp::new()
  app.apply_action("format-palette")
  app.set_format_palette_query("source mode")
  ignore(app.update(ApplyFirstFormatPaletteAction))
  assert_true(app.source_mode_enabled())
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor source mode keeps text input canonical" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("source-mode")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("# Raw")),
  )
  inspect(app.document(), content="# Raw")
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "# Raw", .. })
    }),
  )
}

///|
test "markdown editor toggles quick format palette from action" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text")
  assert_false(app.format_palette_visible())
  app.apply_action("format-palette")
  assert_true(app.format_palette_visible())

  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Quick Format", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Heading 1", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Bold", .. })
    }),
  )

  app.set_format_palette_query("code")
  inspect(app.format_palette_query(), content="code")
  let filtered = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    filtered.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Code Block", .. })
    }),
  )
  assert_false(
    filtered.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Bold", .. })
    }),
  )
}

///|
test "markdown editor runtime quick format shortcuts toggle palette" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="p",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_true(meta_app.format_palette_visible())
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="p",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_false(meta_app.format_palette_visible())

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="p",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  assert_true(control_app.format_palette_visible())
}

///|
test "markdown editor runtime quick format row applies command" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("format-palette")
  let runtime = app.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(runtime.draw_commands(), "Heading 1")
    is Some(frame) else {
    fail("expected quick format heading row")
  }
  let point = @geometry.Point::new(x=frame.origin.x + 4.0, y=frame.origin.y + 4.0)
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
  inspect(app.document(), content="# Heading")
  assert_false(app.format_palette_visible())
}

//|

///|
test "markdown editor set document from input anchors scroll position" {
  let app = MarkdownEditorApp::new()
  app.edit_document("# Long\n\nParagraph text\n\nMore text\n\nEnd")
  app.editor_scroll.scroll_to(x=0.0, y=50.0)
  let before = app.editor_scroll_y()
  app.set_document_from_input(
    "# Long\n\nParagraph text updated\n\nMore text\n\nEnd",
  )
  inspect(app.editor_scroll_y(), content=before.to_string())
}

///|
test "markdown editor quick format submit applies first filtered command" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("format-palette")
  app.set_format_palette_query("heading 2")
  ignore(app.update(ApplyFirstFormatPaletteAction))
  inspect(app.document(), content="## Section")
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor inserts table of contents from outline" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n## Section\n\n### Detail")
  app.set_selection(markdown_editor_text_length(app.document()), None)
  app.apply_action("toc")
  inspect(
    app.document(),
    content="# Title\n\n## Section\n\n### Detail\n\n## Contents\n- [Title](#title)\n  - [Section](#section)\n    - [Detail](#detail)",
  )
}

///|
test "markdown editor quick format can insert table of contents" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n## Section")
  app.apply_action("format-palette")
  app.set_format_palette_query("contents")
  ignore(app.update(ApplyFirstFormatPaletteAction))
  inspect(
    app.document(),
    content="## Contents\n- [Title](#title)\n  - [Section](#section)\n\n# Title\n\n## Section",
  )
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor runtime table of contents shortcuts insert outline" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("# Meta\n\n## Child")
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="t",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.document().contains("- [Meta](#meta)"))
  assert_true(meta_app.document().contains("  - [Child](#child)"))

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("# Control")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="t",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_app.document().contains("- [Control](#control)"))
}

///|
test "markdown editor inserts yaml front matter at document top" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Draft")
  app.apply_action("front-matter")
  inspect(
    app.document(),
    content="---\ntitle: Untitled\ntags: []\n---\n\n# Draft",
  )
}

///|
test "markdown editor front matter command selects existing metadata" {
  let app = MarkdownEditorApp::new()
  app.set_document("---\ntitle: Existing\n---\n\n# Draft")
  app.apply_action("front-matter")
  inspect(app.document(), content="---\ntitle: Existing\n---\n\n# Draft")
  guard app.selection.get().selection is Some(range) else {
    fail("expected existing front matter content selection")
  }
  inspect(range.start, content="4")
  inspect(range.end, content="20")
  inspect(app.selection_caret(), content="20")
}

///|
test "markdown editor quick format can insert yaml front matter" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Draft")
  app.apply_action("format-palette")
  app.set_format_palette_query("front matter")
  ignore(app.update(ApplyFirstFormatPaletteAction))
  assert_true(app.document().has_prefix("---\ntitle: Untitled"))
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor runtime front matter shortcuts insert metadata" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("# Meta")
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="y",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.document().has_prefix("---\ntitle: Untitled"))

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("# Control")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="y",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_app.document().has_prefix("---\ntitle: Untitled"))
}

//|

///|
test "markdown editor image center wraps image in center tags" {
  let app = MarkdownEditorApp::new()
  app.set_document("Before\n\n![photo](img.png)\n\nAfter")
  let offset = app.document().find("![photo]").unwrap_or(0)
  app.selected_image_offset.set(Some(offset))
  ignore(app.update(ToggleImageCenter))
  let doc = app.document()
  assert_true(doc.contains("<center>"))
  assert_true(doc.contains("</center>"))
  assert_true(doc.contains("![photo](img.png)"))
  assert_true(doc.has_prefix("Before"))
  assert_true(doc.has_suffix("After"))
  ignore(app.update(ToggleImageCenter))
  assert_false(app.document().contains("<center>"))
}

//|

///|
test "markdown editor image center detects centered state" {
  let wrapped = markdown_editor_toggle_image_center(
    "Before\n\n![photo](img.png)\n\nAfter", true,
  )
  assert_true(wrapped.contains("<center>"))
  assert_true(wrapped.contains("</center>"))
  let unwrapped = markdown_editor_toggle_image_center(wrapped, false)
  assert_false(unwrapped.contains("<center>"))
  assert_false(unwrapped.contains("</center>"))
}
