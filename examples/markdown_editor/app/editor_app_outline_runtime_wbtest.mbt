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
