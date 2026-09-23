///|
test "draw frame defaults to no overlay bounds" {
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
  )
  assert_true(frame.overlay_bounds is None)
}
