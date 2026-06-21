///|
test "markdown editor runtime enter continues bullet list" {
  let app = MarkdownEditorApp::new()
  app.set_document("- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(x=app.editor_content_x(980.0, inner_x=2.0), y=84.0),
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
        position=@moui.Point::new(
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
        position=@moui.Point::new(
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
        position=@moui.Point::new(
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
        position=@moui.Point::new(
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
