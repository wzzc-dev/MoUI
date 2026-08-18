///|
test "draw frame defaults to no overlay bounds" {
  let frame = DrawFrame::new(commands=[], damage=DamageRegion::empty())
  assert_true(frame.overlay_bounds is None)
}
