///|
test "runtime draw frame separates clear color from content commands" {
  let root : @core.View[Unit] = @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="DrawFrameContract"),
    revision=() => "draw-frame-contract",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=12.0, height=8.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, @core.Color::black()),
      ])
    },
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=12.0, height=8.0),
  )
  let frame = runtime.draw_frame()
  assert_true(frame.clear_color == @core.Color::white())
  assert_false(
    frame.commands.any(command => command is @core.DrawCommand::Clear(_)),
  )
  assert_true(
    frame.commands.any(command => command is @core.DrawCommand::FillRect(_, _)),
  )
  let legacy = runtime.draw_commands()
  assert_true(legacy[0] is @core.DrawCommand::Clear(_))
}
