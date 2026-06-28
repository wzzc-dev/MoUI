///|
fn markdown_editor_begin_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands
  .filter(command => command is @core.DrawCommand::BeginCachedLayer(_))
  .length()
}

///|
fn markdown_editor_draw_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands
  .filter(command => command is @core.DrawCommand::DrawCachedLayer(_))
  .length()
}

///|
fn markdown_editor_has_cached_chrome_layer(
  commands : Array[@core.DrawCommand],
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::DrawCachedLayer(spec) => spec.frame.size.height <= 48.0
      _ => false
    }
  })
}

///|
test "markdown editor chrome caches stable state and refreshes on dirty" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  // With no document state change, the chrome layer is reused from cache.
  assert_true(
    markdown_editor_draw_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
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
  ignore(runtime.draw_frame())
  assert_true(
    markdown_editor_draw_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
  // Text input flips the dirty flag, which the toolbar now reacts to (Save /
  // undo enable). The toolbar repaint boundary therefore invalidates and is
  // re-recorded as a fresh cached layer rather than reused as DrawCachedLayer.
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  let frame = runtime.draw_frame()
  assert_true(markdown_editor_begin_cached_layer_count(frame.commands) > 0)
  // Once the dirty-driven toolbar change is recorded, a subsequent stable
  // frame reuses the chrome layer from cache again.
  assert_true(
    markdown_editor_has_cached_chrome_layer(runtime.draw_frame().commands),
  )
}

///|
test "markdown editor scroll does not reparse session" {
  let app = MarkdownEditorApp::new()
  app.set_document(markdown_editor_synthetic_scroll_document(160))
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  let after_first_frame = app.document_session_parse_count()
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(
          x=app.editor_content_x(980.0, inner_x=8.0),
          y=220.0,
        ),
        phase=@core.PointerPhase::Move,
        wheel_delta=@moui.Point::new(x=0.0, y=-220.0),
      ),
    ),
  )
  let dirty = runtime.inspector_snapshot()
  inspect(dirty.runtime.dirty_layout_count, content="0")
  assert_true(dirty.runtime.dirty_paint_count > 0)
  inspect(dirty.view_tree.dirty_layout_count, content="0")
  assert_true(dirty.view_tree.dirty_paint_count > 0)
  ignore(runtime.draw_frame())
  assert_true(app.editor_scroll_y() > 0.0)
  inspect(
    app.document_session_parse_count(),
    content=after_first_frame.to_string(),
  )
}

///|
fn markdown_editor_synthetic_scroll_document(blocks : Int) -> String {
  let parts : Array[String] = []
  for index in 0..<blocks {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push(
      "Paragraph " +
      index.to_string() +
      " with **bold** text and a [link](https://moui.dev).",
    )
    parts.push("")
  }
  parts.join("\n")
}
