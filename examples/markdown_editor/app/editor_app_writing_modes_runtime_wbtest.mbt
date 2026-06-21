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
        position=@moui.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=48.0,
        ),
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
