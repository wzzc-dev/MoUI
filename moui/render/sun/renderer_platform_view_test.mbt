///|
test "sun renderer draws platform view pixels before presenting frame" {
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
  renderer.set_platform_view_draw_fn(
    Some(() => {
      renderer.draw_platform_view_pixels(
        sun_platform_view_stride_test_rgba(),
        2,
        2,
        12,
        1.0,
        1.0,
        2.0,
        2.0,
      )
    }),
  )
  let result = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[@core.DrawCommand::Clear(@core.Color::white())],
      damage=@core.DamageRegion::full("sun platform view pixels"),
    ),
  )
  inspect(result.presented, content="true")
  match presented.val {
    Some(frame) => {
      let red = (1 * frame.width + 1) * 4
      let green = (1 * frame.width + 2) * 4
      assert_true(frame.pixels[red].to_int() > 200)
      assert_true(frame.pixels[red + 1].to_int() < 80)
      assert_true(frame.pixels[green + 1].to_int() > 200)
      assert_true(frame.pixels[green].to_int() < 80)
    }
    None => fail("expected Sun frame with platform-view pixels")
  }
}

///|
fn sun_platform_view_stride_test_rgba() -> Bytes {
  Bytes::from_array([
    255, 0, 0, 255, 0, 255, 0, 255, 9, 9, 9, 9, 0, 0, 255, 255, 255, 255, 255, 255,
    8, 8, 8, 8,
  ])
}
