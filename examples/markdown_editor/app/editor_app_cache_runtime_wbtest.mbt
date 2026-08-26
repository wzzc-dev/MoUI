///|
fn markdown_editor_begin_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands
  .filter(command => command is @core.DrawCommand::BeginRetainedLayer(_))
  .length()
}

///|
fn markdown_editor_has_retained_chrome_layer(
  commands : Array[@core.DrawCommand],
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::BeginRetainedLayer(spec) =>
        spec.frame.size.height <= 48.0
      _ => false
    }
  })
}

///|
fn markdown_editor_cached_layer_command_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  markdown_editor_begin_cached_layer_count(commands)
}

///|
test "markdown editor chrome caches stable state and refreshes on dirty" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  // Runtime emits complete retained declarations; renderer-local admission
  // and residency are deliberately not observable here.
  assert_true(
    markdown_editor_begin_cached_layer_count(runtime.draw_frame().commands) > 0,
  )
  assert_true(
    markdown_editor_has_retained_chrome_layer(runtime.draw_frame().commands),
  )
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
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  assert_true(
    markdown_editor_has_retained_chrome_layer(runtime.draw_frame().commands),
  )
  // Text input flips the dirty flag, which the toolbar reacts to. The next
  // declaration carries the new content revision and a complete payload.
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  let frame = runtime.draw_frame()
  assert_true(markdown_editor_begin_cached_layer_count(frame.commands) > 0)
  assert_true(
    markdown_editor_has_retained_chrome_layer(runtime.draw_frame().commands),
  )
}

///|
test "markdown editor scroll does not reparse session" {
  let app = MarkdownEditorApp::new()
  app.set_document(markdown_editor_synthetic_scroll_document(160))
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  let after_first_frame = app.document_session_parse_count()
  let scroll_result = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@geometry.Point::new(
        x=app.editor_content_x(980.0, inner_x=8.0),
        y=220.0,
      ),
      phase=@core.PointerPhase::Move,
      wheel_delta=@geometry.Point::new(x=0.0, y=-220.0),
    ),
  )
  ignore(scroll_result)
  let dirty = runtime.inspector_snapshot()
  inspect(dirty.runtime().dirty_layout_count(), content="7")
  assert_true(dirty.runtime().dirty_paint_count() > 0)
  inspect(dirty.view_tree().dirty_layout_count(), content="7")
  assert_true(dirty.view_tree().dirty_paint_count() > 0)
  ignore(runtime.draw_frame())
  assert_true(app.editor_scroll_y() > 0.0)
  inspect(
    app.document_session_parse_count(),
    content=after_first_frame.to_string(),
  )
}

///|
test "markdown editor long scroll keeps cached layer tracking bounded" {
  let app = MarkdownEditorApp::new()
  app.set_document(markdown_editor_synthetic_scroll_document(900))
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  let mut last_cached_command_count = 0
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
    let frame = runtime.draw_frame()
    last_cached_command_count = markdown_editor_cached_layer_command_count(
      frame.commands,
    )
  }
  assert_true(app.editor_scroll_y() > 0.0)
  if last_cached_command_count <= 0 || last_cached_command_count > 64 {
    fail("expected long-scroll retained declarations to stay viewport bounded")
  }
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
      " with **bold** text and a [link](https://wzzc-dev.github.io/MoUI).",
    )
    parts.push("")
  }
  parts.join("\n")
}

///|
/// Collect the Y-center of every DrawText command in a draw frame. Used to
/// verify that text is actually painted across the full viewport height after
/// scrolling, not just in the top portion.
fn markdown_editor_draw_text_y_centers(
  commands : Array[@core.DrawCommand],
) -> Array[Double] {
  let ys : Array[Double] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) =>
        ys.push(run.frame.origin.y + run.frame.size.height / 2.0)
      _ => ()
    }
  }
  ys
}

///|
/// Regression: scrolling a large document must not leave the bottom of the
/// viewport blank. Before the fix, `append_rich_text_document_layers` culled
/// blocks using the offset `window_content` rect instead of the real viewport,
/// cutting off the bottom ~overscan (320px) of text after any scroll past the
/// first screen.
test "markdown editor scroll renders text across full viewport" {
  let app = MarkdownEditorApp::new()
  app.set_document(markdown_editor_synthetic_scroll_document(160))
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  // Scroll well past the first screen.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=8.0),
          y=220.0,
        ),
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=-600.0),
      ),
    ),
  )
  let frame = runtime.draw_frame()
  assert_true(app.editor_scroll_y() > 0.0)
  let ys = markdown_editor_draw_text_y_centers(frame.commands)
  // There must be text rendered after scrolling.
  assert_true(ys.length() > 0)
  // The editor content occupies roughly y=40 (chrome+inset) to y=572 (above
  // the status bar). After the fix, text should appear in the bottom half of
  // the editor viewport. Before the fix, the bottom ~overscan was culled
  // blank, leaving only the status bar text (y≈622) in this Y range.
  let editor_bottom_half_count = ys
    .iter()
    .filter(y => y > 300.0 && y < 600.0)
    .count()
  assert_true(editor_bottom_half_count > 0)
}
