///|
test "sun renderer blurs the backdrop inside a material frame" {
  let presented = Ref(None)
  let target = @moui_sun_renderer.SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = @moui_sun_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=40.0, height=20.0),
    ),
    target,
  )
  renderer.render([
    Clear(@core.Color::white()),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      @core.Color::rgba(r=0.0, g=0.0, b=0.0),
    ),
    DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="backdrop-blur",
        frame=@core.Rect::new(x=10.0, y=2.0, width=20.0, height=16.0),
        uniforms=[3.0, 0.0],
        fallback=@core.Brush::solid(@core.Color::transparent()),
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      let pixels = frame.pixels()
      let row_bytes = frame.row_bytes()
      let edge = pixels[10 * row_bytes + 20 * 4].to_int()
      let outside_left = pixels[10 * row_bytes + 2 * 4].to_int()
      let outside_right = pixels[10 * row_bytes + 38 * 4].to_int()
      // The hard black/white edge inside the material reads as a blend.
      assert_true(edge > 40 && edge < 215)
      assert_true(outside_left < 20)
      assert_true(outside_right > 235)
    }
    None => fail("expected Sun frame")
  }
}
