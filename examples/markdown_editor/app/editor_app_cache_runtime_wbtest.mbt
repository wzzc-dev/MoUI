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
test "markdown editor text input keeps chrome cached" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  assert_true(
    markdown_editor_draw_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  assert_true(
    markdown_editor_draw_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  let frame = runtime.draw_frame()
  assert_true(markdown_editor_begin_cached_layer_count(frame.commands) > 0)
  assert_true(markdown_editor_draw_cached_layer_count(frame.commands) > 0)
  assert_true(markdown_editor_has_cached_chrome_layer(frame.commands))
}
