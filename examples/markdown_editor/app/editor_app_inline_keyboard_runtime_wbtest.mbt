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
        position=@moui.Point::new(x=app.editor_content_x(980.0, inner_x=2.0), y=84.0),
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
        position=@moui.Point::new(x=app.editor_content_x(980.0, inner_x=2.0), y=84.0),
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
        position=@moui.Point::new(x=app.editor_content_x(980.0, inner_x=2.0), y=84.0),
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
