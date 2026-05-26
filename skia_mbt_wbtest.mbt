///|
test "geometry default values follow skia empty conventions" {
  assert_true(IPoint::default().is_zero())
  assert_true(Size::default().is_empty())
  assert_true(IRect::default().is_empty())
  assert_true(Rect::default().is_empty())
}

///|
test "rect join ignores empty input" {
  let rect = Rect::from_xywh(1, 2, 3, 4)
  assert_true(Rect::empty().join(rect) == rect)
  assert_true(rect.join(Rect::empty()) == rect)
}

///|
test "color info opacity combines alpha and storage type" {
  assert_true(ColorInfo::new(color_type=RGB565, alpha_type=Premul).is_opaque())
  assert_true(
    ColorInfo::new(color_type=RGBA8888, alpha_type=Opaque).is_opaque(),
  )
  assert_true(
    !ColorInfo::new(color_type=RGBA8888, alpha_type=Premul).is_opaque(),
  )
}
