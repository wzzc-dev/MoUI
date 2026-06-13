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
        position=@core.Point::new(x=28.0, y=84.0),
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
  inspect(app.document(), content="# Heading")
  assert_false(app.format_palette_visible())
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
  assert_true(app.can_undo())
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
  assert_true(app.can_undo())
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

///|
test "markdown editor cycles writing appearance from action" {
  let app = MarkdownEditorApp::new()
  inspect(app.appearance_label_for_test(), content="Paper")
  assert_false(app.document_status_label_for_test().contains("Look:"))
  let paper_width = app.editor_page_width_for_test()
  let paper_size = app.editor_font_size_for_test()

  app.apply_action("look")
  inspect(app.appearance_label_for_test(), content="Warm")
  assert_true(app.document_status_label_for_test().contains("Look: Warm"))
  assert_true(app.editor_font_size_for_test() > paper_size)
  assert_true(app.editor_page_width_for_test() < paper_width)

  app.apply_action("look")
  inspect(app.appearance_label_for_test(), content="Wide")
  assert_true(app.document_status_label_for_test().contains("Look: Wide"))
  assert_true(app.editor_page_width_for_test() > paper_width)

  app.apply_action("look")
  inspect(app.appearance_label_for_test(), content="Paper")
  assert_false(app.document_status_label_for_test().contains("Look:"))
}

///|
test "markdown editor runtime writing appearance shortcuts cycle look" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="l",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  inspect(meta_app.appearance_label_for_test(), content="Warm")

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="l",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  inspect(control_app.appearance_label_for_test(), content="Warm")
}

///|
test "markdown editor quick format can set writing appearance directly" {
  let app = MarkdownEditorApp::new()
  app.apply_action("format-palette")
  app.set_format_palette_query("wide look")
  ignore(app.update(ApplyFirstFormatPaletteAction))
  inspect(app.appearance_label_for_test(), content="Wide")
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor writing appearance changes rendered typography" {
  let app = MarkdownEditorApp::new()
  app.set_document("Plain text")
  let paper_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  guard markdown_editor_text_font_size(paper_commands, "Plain text")
    is Some(paper_size) else {
    fail("expected rendered paper text")
  }

  app.apply_action("look")
  let warm_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  guard markdown_editor_text_font_size(warm_commands, "Plain text")
    is Some(warm_size) else {
    fail("expected rendered warm text")
  }
  assert_true(warm_size > paper_size)
}

///|
test "markdown editor writing mode actions update status strip" {
  let app = MarkdownEditorApp::new()
  assert_false(app.focus_mode_enabled())
  assert_false(app.typewriter_mode_enabled())
  assert_false(app.zen_mode_enabled())
  app.apply_action("focus-mode")
  app.apply_action("typewriter-mode")
  app.apply_action("zen-mode")
  assert_true(app.focus_mode_enabled())
  assert_true(app.typewriter_mode_enabled())
  assert_true(app.zen_mode_enabled())
  assert_true(
    app.document_status_label_for_test().contains("Focus + Typewriter + Zen"),
  )
}

///|
test "markdown editor zen mode hides chrome and auxiliary panels" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Zen\n\nBody")
  app.set_source_preview_visible(true)
  app.set_outline_visible(true)
  app.set_file_sidebar_visible(true)
  app.set_document_info_visible(true)
  app.apply_action("find")
  app.apply_action("format-palette")
  app.apply_action("zen-mode")
  assert_true(app.zen_mode_enabled())
  assert_false(app.find_visible())
  assert_false(app.format_palette_visible())
  assert_false(app.source_preview_visible())
  assert_false(app.outline_visible())
  assert_false(app.file_sidebar_visible())
  assert_false(app.document_info_visible())

  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Zen", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "New", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor runtime writing mode shortcuts toggle modes" {
  let meta_app = MarkdownEditorApp::new()
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_true(meta_app.focus_mode_enabled())
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="t",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_true(meta_app.typewriter_mode_enabled())

  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="z",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.zen_mode_enabled())

  let control_app = MarkdownEditorApp::new()
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  assert_true(control_app.focus_mode_enabled())
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="t",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  assert_true(control_app.typewriter_mode_enabled())
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="z",
        modifiers=@core.KeyModifiers::new(control=true, alt=true),
      ),
    ),
  )
  assert_true(control_app.zen_mode_enabled())
}

///|
test "markdown editor escape exits zen mode" {
  let app = MarkdownEditorApp::new()
  app.apply_action("zen-mode")
  assert_true(app.zen_mode_enabled())
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(app.zen_mode_enabled())
}

///|
test "markdown editor quick format can enable zen mode" {
  let app = MarkdownEditorApp::new()
  app.apply_action("format-palette")
  app.set_format_palette_query("zen")
  ignore(app.update(ApplyFirstFormatPaletteAction))
  assert_true(app.zen_mode_enabled())
  assert_false(app.format_palette_visible())
}

///|
test "markdown editor zen mode keeps editing live" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("zen-mode")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=48.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("quiet")),
  )
  inspect(app.document(), content="quiet")
}

///|
test "markdown editor typewriter mode centers current caret" {
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  let target = markdown_editor_text_length(lead)
  let source = lead + "Tail\n\n" + lead

  let plain = MarkdownEditorApp::new()
  plain.set_document(source)
  plain.set_selection(target, None)
  assert_true(plain.editor_scroll_y() == 0.0)

  let typewriter = MarkdownEditorApp::new()
  typewriter.set_document(source)
  typewriter.set_selection(target, None)
  typewriter.apply_action("typewriter-mode")
  let centered = typewriter.editor_scroll_y()
  assert_true(centered > 0.0)

  let top_aligned = MarkdownEditorApp::new()
  top_aligned.set_document(source)
  top_aligned.scroll_to_source(target)
  assert_true(centered < top_aligned.editor_scroll_y())
}

///|
test "markdown editor typewriter mode recenters after document input" {
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  let target = markdown_editor_text_length(lead)
  let source = lead + "Tail\n\n" + lead
  let app = MarkdownEditorApp::new()
  app.set_document(source)
  app.apply_action("typewriter-mode")
  app.set_selection(target, None)
  app.editor_scroll.scroll_to(x=0.0, y=0.0)
  app.edit_document(source + " updated")
  assert_true(app.editor_scroll_y() > 0.0)
}
