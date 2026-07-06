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
