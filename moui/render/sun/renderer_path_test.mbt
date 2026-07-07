///|
test "sun renderer DrawPath without fill or stroke is no-op" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(verbs=[
        @core.PathVerb::MoveTo(@core.Point::new(x=1.0, y=1.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.0, y=1.0)),
        @core.PathVerb::LineTo(@core.Point::new(x=3.0, y=3.0)),
        @core.PathVerb::Close,
      ]),
    ),
  ])
  match presented.val {
    Some(frame) => {
      inspect(renderer.unsupported_command_count(), content="0")
      assert_true(frame.pixels[0].to_int() == 255)
      assert_true(frame.pixels[1].to_int() == 255)
      assert_true(frame.pixels[2].to_int() == 255)
    }
    None => fail("expected Sun frame")
  }
}
