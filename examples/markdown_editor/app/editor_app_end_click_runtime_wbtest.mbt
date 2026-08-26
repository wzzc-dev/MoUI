///|
fn markdown_editor_end_click_document(blocks : Int) -> String {
  let parts : Array[String] = []
  for index in 0..<blocks {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push(
      "Paragraph " +
      index.to_string() +
      " with **bold** text and a [link](https://wzzc-dev.github.io/MoUI).",
    )
    parts.push("")
  }
  parts.join("\n")
}

///|
test "markdown editor bottom click keeps focused text input windowed" {
  let app = MarkdownEditorApp::new()
  app.set_document(markdown_editor_end_click_document(900))
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  let parse_count = app.document_session_parse_count()
  for _ in 0..<240 {
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@geometry.Point::new(
            x=app.editor_content_x(980.0, inner_x=8.0),
            y=220.0,
          ),
          phase=@core.PointerPhase::Move,
          wheel_delta=@geometry.Point::new(x=0.0, y=-420.0),
        ),
      ),
    )
    ignore(runtime.draw_frame())
  }
  assert_true(app.editor_scroll_y() > 1000.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=8.0),
          y=552.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let input = runtime.focused_text_input()
  assert_true(input.focused)
  assert_true(input.caret >= 0)
  assert_true(input.caret <= markdown_editor_text_length(app.document()))
  assert_true(input.caret_rect.size.height > 0.0)
  assert_true(input.caret_rect.origin.x >= 0.0)
  assert_true(input.caret_rect.origin.x <= 980.0)
  assert_true(input.caret_rect.origin.y >= 0.0)
  assert_true(input.caret_rect.origin.y <= 640.0)
  inspect(app.block_label(), content="Paragraph")
  guard app.target_kind() is PlainSelection else {
    fail("expected bottom plain-text click to avoid target palette probing")
  }
  inspect(app.document_session_parse_count(), content=parse_count.to_string())
}
