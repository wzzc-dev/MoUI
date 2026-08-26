///|
test "markdown editor copy exports visual text without hidden markdown markers" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n- [ ] **bold**")
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
    paste_text=Some("https://wzzc-dev.github.io/MoUI"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(
    app.document(),
    content="Visit [MoUI](https://wzzc-dev.github.io/MoUI)",
  )
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
  let mut runtime = app.runtime(width=980.0, height=640.0)
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
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://wzzc-dev.github.io/MoUI"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit <https://wzzc-dev.github.io/MoUI>")

  app.set_document("Visit https://wzzc-dev.github.io/MoUI")
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Visit <https://wzzc-dev.github.io/MoUI> ")

  app.set_document("Mail ")
  runtime = app.runtime(width=980.0, height=640.0)
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
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Mail <hello@example.dev> ")

  app.set_document("Visit https://wzzc-dev.github.io/MoUI")
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="Visit <https://wzzc-dev.github.io/MoUI>\n")
}
