///|
test "radial gradient brush clamps radius and preserves alpha helpers" {
  let center = Point::new(x=12.0, y=18.0)
  let center_color = Color::rgba(r=0.9, g=0.1, b=0.2, a=0.6)
  let edge_color = Color::rgba(r=0.1, g=0.2, b=0.9, a=0.4)
  let brush = Brush::radial_gradient(
    center~,
    radius=-8.0,
    center_color~,
    edge_color~,
  )
  guard brush is Brush::RadialGradient(gradient) else {
    fail("expected radial gradient brush")
  }
  assert_true(gradient.center == center)
  assert_paint_double_close(gradient.radius, 0.0)
  assert_true(brush.fallback_color() == center_color)
  let faded = brush.multiply_alpha(0.5)
  guard faded is Brush::RadialGradient(faded_gradient) else {
    fail("expected faded radial gradient brush")
  }
  assert_true(faded_gradient.center == center)
  assert_paint_double_close(faded_gradient.radius, 0.0)
  assert_paint_double_close(faded_gradient.center_color.a, 0.3)
  assert_paint_double_close(faded_gradient.edge_color.a, 0.2)
}

///|
fn assert_paint_double_close(actual : Double, expected : Double) -> Unit raise {
  let delta = actual - expected
  let distance = if delta < 0.0 { -delta } else { delta }
  assert_true(distance < 0.000001)
}
