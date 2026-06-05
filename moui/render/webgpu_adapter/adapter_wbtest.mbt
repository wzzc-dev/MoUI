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
test "wgpu web adapter lowers radial brush to deterministic center edge payload" {
  let payload = brush_payload(
    @core.Brush::radial_gradient(
      center=@core.Point::new(x=4.0, y=6.0),
      radius=12.0,
      center_color=@core.Color::blue(),
      edge_color=@core.Color::gray(),
    ),
    @core.Rect::new(x=1.0, y=2.0, width=40.0, height=20.0),
  )
  assert_true(payload.start == @core.Point::new(x=4.0, y=6.0))
  assert_true(payload.end == @core.Point::new(x=16.0, y=6.0))
  assert_true(payload.start_color == @core.Color::blue())
  assert_true(payload.end_color == @core.Color::gray())
}

///|
test "wgpu web adapter routes radial rounded brush through gradient payload" {
  let payload = rounded_brush_host_payload(
    @core.Brush::radial_gradient(
      center=@core.Point::new(x=14.0, y=11.0),
      radius=9.0,
      center_color=@core.Color::blue(),
      edge_color=@core.Color::gray(),
    ),
    @core.Rect::new(x=10.0, y=6.0, width=32.0, height=18.0),
  )
  guard payload is RoundedBrushHostPayload::GradientPayload(gradient) else {
    fail("expected radial rounded brush to use gradient host payload")
  }
  assert_true(gradient.start == @core.Point::new(x=14.0, y=11.0))
  assert_true(gradient.end == @core.Point::new(x=23.0, y=11.0))
  assert_true(gradient.start_color == @core.Color::blue())
  assert_true(gradient.end_color == @core.Color::gray())
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
