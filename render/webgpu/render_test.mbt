///|
test "render commands call js bridge in draw order" {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=20.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::DrawText({
      text: "Hello",
      frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
      font: @core.FontSpec::new(size=16.0),
      color: @core.Color::black(),
    }),
  ]
  let trace = @webgpu.render_commands_for_test(
    commands,
    @core.Size::new(width=320.0, height=240.0),
  )
  inspect(
    trace.calls,
    content=(
      #|["begin", "clear", "rect", "text", "present"]
    ),
  )
}

///|
test "clip commands are preserved in bridge traversal" {
  let trace = @webgpu.render_commands_for_test(
    [
      @core.DrawCommand::PushClip(
        @core.Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
      ),
      @core.DrawCommand::PopClip,
    ],
    @core.Size::new(width=320.0, height=240.0),
  )
  inspect(
    trace.calls,
    content=(
      #|["begin", "push_clip", "pop_clip", "present"]
    ),
  )
}
