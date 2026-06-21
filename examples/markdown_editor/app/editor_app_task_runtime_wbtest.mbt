///|
test "markdown editor runtime prefix click toggles task checkbox" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [x] todo")
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
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
