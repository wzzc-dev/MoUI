///|
test "markdown editor runtime backspace removes hidden heading marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
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
        position=@geometry.Point::new(
          x=heading_app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=task_app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
  app.set_document("Visit [MoUI](https://wzzc-dev.github.io/MoUI)")
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
  app.set_document("Visit [MoUI](https://wzzc-dev.github.io/MoUI)")
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=64.0,
        ),
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
