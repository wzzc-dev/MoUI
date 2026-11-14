///|
test "gradient stops clamp and sort" {
  let stops = [
    @core.GradientStop::new(
      color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
      at=1.5,
    ),
    @core.GradientStop::new(
      color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
      at=-0.5,
    ),
  ]
  let spec = @core.StopsGradientSpec::new(
    axis=@core.LinearAxis(
      @core.Point::new(x=0.0, y=0.0),
      @core.Point::new(x=1.0, y=0.0),
    ),
    stops~,
  )
  assert_eq(spec.stops.length(), 2)
  assert_eq(spec.stops[0].at, 0.0)
  assert_eq(spec.stops[0].color, @core.Color::rgba(r=1.0, g=0.0, b=0.0))
  assert_eq(spec.stops[1].at, 1.0)
}

///|
test "oklab lerp maps midpoint L to perceptual luminance" {
  let black = @core.Color::rgba(r=0.0, g=0.0, b=0.0)
  let white = @core.Color::rgba(r=1.0, g=1.0, b=1.0)
  let midpoint = @core.Color::lerp_oklab(black, white, 0.5)
  // Oklab L=0.5 is linear luminance 0.125, i.e. sRGB ~0.389 — not the 0.5 a
  // naive sRGB lerp returns.
  assert_true(midpoint.r > 0.35 && midpoint.r < 0.43)
  assert_true((midpoint.r - midpoint.g).abs() < 0.000001)
  assert_true((midpoint.g - midpoint.b).abs() < 0.000001)
}

///|
test "srgb_stops expands oklab segments and preserves endpoints" {
  let stops = [
    @core.GradientStop::new(
      color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
      at=0.0,
    ),
    @core.GradientStop::new(
      color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
      at=1.0,
    ),
  ]
  let linear = @core.StopsGradientSpec::new(
    axis=@core.LinearAxis(
      @core.Point::new(x=0.0, y=0.0),
      @core.Point::new(x=1.0, y=0.0),
    ),
    stops~,
    oklab=true,
  )
  let expanded = linear.srgb_stops(resolution=8)
  assert_eq(expanded.length(), 9)
  assert_eq(expanded[0].color, @core.Color::rgba(r=1.0, g=0.0, b=0.0))
  assert_eq(expanded[8].color, @core.Color::rgba(r=0.0, g=0.0, b=1.0))
  // The exact middle sample is not the sRGB midpoint.
  let srgb_mid = @core.Color::rgba(r=0.5, g=0.0, b=0.5)
  assert_true(expanded[4].color != srgb_mid)
  // A non-Oklab spec returns its stops unchanged.
  let plain = @core.StopsGradientSpec::new(axis=linear.axis, stops~)
  assert_eq(plain.srgb_stops().length(), 2)
}

///|
test "stops gradient brush helpers and fallbacks" {
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0)
  let blue = @core.Color::rgba(r=0.0, g=0.0, b=1.0)
  let brush = @core.Brush::conic(
    center=@core.Point::new(x=2.0, y=2.0),
    stops=[
      @core.GradientStop::new(color=red, at=0.0),
      @core.GradientStop::new(color=blue, at=1.0),
    ],
    angle_degrees=45.0,
  )
  assert_true(brush.fallback_color() == red)
  match brush {
    @core.StopsGradient(spec) => assert_true(spec.edge_colors() == (red, blue))
    _ => abort("expected StopsGradient")
  }
  match brush.multiply_alpha(0.5) {
    @core.StopsGradient(spec) => {
      assert_eq(spec.stops[0].color.a, 0.5)
      assert_eq(spec.stops[1].color.a, 0.5)
    }
    _ => abort("expected StopsGradient")
  }
}
