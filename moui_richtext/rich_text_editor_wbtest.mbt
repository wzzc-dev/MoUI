///|
test "rich text run frame leaves right ink bleed" {
  let font = @core.FontSpec::new(size=20.0)
  let text_system = @core.TextSystem::fallback()
  let text_width = rich_text_width("Today", font, text_system)
  let commands : Array[@core.DrawCommand] = []
  append_rich_text_block_commands(
    commands,
    RichTextBlock::new(runs=[RichTextRun::new(text="Today")]),
    @core.Rect::new(x=10.0, y=20.0, width=400.0, height=40.0),
    40.0,
    font,
    @core.Color::black(),
    text_system~,
  )
  guard commands.length() == 1 else {
    fail("expected one rich text draw command")
  }
  guard commands[0] is @core.DrawCommand::DrawText({ text: "Today", frame, .. }) else {
    fail("expected Today text command")
  }
  assert_true(frame.origin.x == 10.0)
  assert_true(frame.size.width > text_width)
  assert_true(frame.size.width <= 400.0)
}

///|
test "rich text editor wheel event updates shared scroll state" {
  let state = @core.ScrollState::new()
  let source = rich_text_scroll_test_source()
  let font = @core.FontSpec::new(size=14.0)
  let runtime = @runtime.AppRuntime::new_view(
    root=controlled_rich_text_editor(
      value=source,
      on_input=_ => (),
      placeholder="",
      size=@core.Size::new(width=320.0, height=80.0),
      format=rich_text_scroll_test_document,
      font~,
      foreground=@core.Color::black(),
      placeholder_color=@core.Color::black(),
      background=@core.Brush::solid(@core.Color::white()),
      cursor_color=@core.Color::black(),
      visible_viewport_height=80.0,
      visible_scroll_state=Some(state),
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-48.0),
      ),
    ),
  )
  assert_true(state.offset().y > 0.0)
}

///|
fn rich_text_scroll_test_source() -> String {
  let lines : Array[String] = []
  for index in 0..<24 {
    lines.push("line " + index.to_string())
  }
  lines.join("\n")
}

///|
fn rich_text_scroll_test_document(source : String) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  for line in source.split("\n") {
    blocks.push(
      RichTextBlock::new(
        runs=[RichTextRun::new(text=line.to_owned())],
        line_height=Some(20.0),
      ),
    )
  }
  RichTextDocument::new(blocks~)
}
