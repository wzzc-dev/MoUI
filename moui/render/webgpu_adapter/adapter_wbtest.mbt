///|
test "wgpu web adapter encodes image fit host codes" {
  inspect(image_fit_host_code(@core.ImageFit::Contain), content="0")
  inspect(image_fit_host_code(@core.ImageFit::Cover), content="1")
  inspect(image_fit_host_code(@core.ImageFit::Stretch), content="2")
  inspect(image_fit_host_code(@core.ImageFit::ScaleDown), content="3")
  inspect(image_fit_host_code(@core.ImageFit::FitWidth), content="4")
  inspect(image_fit_host_code(@core.ImageFit::FitHeight), content="5")
}

///|
test "wgpu web adapter preserves radial brush host payload" {
  let payload = radial_brush_payload(
    @core.RadialGradientSpec::new(
      center=@core.Point::new(x=4.0, y=6.0),
      radius=12.0,
      center_color=@core.Color::blue(),
      edge_color=@core.Color::gray(),
    ),
  )
  assert_true(payload.center == @core.Point::new(x=4.0, y=6.0))
  inspect(payload.radius, content="12")
  assert_true(payload.center_color == @core.Color::blue())
  assert_true(payload.edge_color == @core.Color::gray())
}

///|
test "wgpu web adapter routes radial rounded brush through radial payload" {
  let payload = rounded_brush_host_payload(
    @core.Brush::radial_gradient(
      center=@core.Point::new(x=14.0, y=11.0),
      radius=9.0,
      center_color=@core.Color::blue(),
      edge_color=@core.Color::gray(),
    ),
    @core.Rect::new(x=10.0, y=6.0, width=32.0, height=18.0),
  )
  guard payload is RoundedBrushHostPayload::RadialGradientPayload(radial) else {
    fail("expected radial rounded brush to use radial host payload")
  }
  assert_true(radial.center == @core.Point::new(x=14.0, y=11.0))
  inspect(radial.radius, content="9")
  assert_true(radial.center_color == @core.Color::blue())
  assert_true(radial.edge_color == @core.Color::gray())
}

///|
test "wgpu web adapter keeps solid rounded brush on solid host payload" {
  let payload = rounded_brush_host_payload(
    @core.Brush::solid(@core.Color::blue()),
    @core.Rect::new(x=10.0, y=6.0, width=32.0, height=18.0),
  )
  guard payload is RoundedBrushHostPayload::SolidColor(color) else {
    fail("expected solid rounded brush to keep solid host payload")
  }
  assert_true(color == @core.Color::blue())
}
