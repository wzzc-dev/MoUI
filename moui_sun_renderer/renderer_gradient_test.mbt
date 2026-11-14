///|
test "sun renderer renders multi-stop gradient pixels" {
  let presented = Ref(None)
  let target = @moui_sun_renderer.SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = @moui_sun_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=1.0),
    ),
    target,
  )
  let gradient = @core.Brush::linear_stops(
    start=@core.Point::new(x=0.0, y=0.0),
    end=@core.Point::new(x=8.0, y=0.0),
    stops=[
      @core.GradientStop::new(
        color=@core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
        at=0.0,
      ),
      @core.GradientStop::new(
        color=@core.Color::rgba(r=0.0, g=1.0, b=0.0, a=1.0),
        at=0.5,
      ),
      @core.GradientStop::new(
        color=@core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0),
        at=1.0,
      ),
    ],
  )
  renderer.render([
    Clear(@core.Color::white()),
    FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=1.0),
      ),
      gradient,
    ),
  ])
  match presented.val {
    Some(frame) => {
      let pixels = frame.pixels()
      let left = (pixels[0].to_int(), pixels[1].to_int(), pixels[2].to_int())
      let middle = (
        pixels[4 * 4].to_int(),
        pixels[4 * 4 + 1].to_int(),
        pixels[4 * 4 + 2].to_int(),
      )
      let right = (
        pixels[7 * 4].to_int(),
        pixels[7 * 4 + 1].to_int(),
        pixels[7 * 4 + 2].to_int(),
      )
      assert_true(left.0 > 200 && left.1 < 60 && left.2 < 60)
      assert_true(middle.1 > 150)
      assert_true(right.2 > 200 && right.0 < 60)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer renders conic gradient pixels" {
  let presented = Ref(None)
  let target = @moui_sun_renderer.SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = @moui_sun_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  )
  let gradient = @core.Brush::conic(center=@core.Point::new(x=8.0, y=8.0), stops=[
    @core.GradientStop::new(
      color=@core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
      at=0.0,
    ),
    @core.GradientStop::new(
      color=@core.Color::rgba(r=0.0, g=1.0, b=0.0, a=1.0),
      at=0.5,
    ),
    @core.GradientStop::new(
      color=@core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0),
      at=1.0,
    ),
  ])
  renderer.render([
    Clear(@core.Color::white()),
    FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      ),
      gradient,
    ),
  ])
  match presented.val {
    Some(frame) => {
      let pixels = frame.pixels()
      let row_bytes = frame.row_bytes()
      let top = (
        pixels[1 * row_bytes + 8 * 4].to_int(),
        pixels[1 * row_bytes + 8 * 4 + 1].to_int(),
      )
      let bottom = (
        pixels[14 * row_bytes + 8 * 4].to_int(),
        pixels[14 * row_bytes + 8 * 4 + 1].to_int(),
      )
      // Top starts the sweep (red); the bottom is half a turn in (green).
      assert_true(top.0 > 200 && top.1 < 80)
      assert_true(bottom.1 > 150 && bottom.0 < 120)
    }
    None => fail("expected Sun frame")
  }
}
