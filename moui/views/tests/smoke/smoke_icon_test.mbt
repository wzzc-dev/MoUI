///|
/// Smoke tests for icon, image, divider.
///|
test "icon smoke" {
  let view : @core.View[Unit] = @views.icon(@views.IconName::Check)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "icon sized smoke" {
  let view : @core.View[Unit] = @views.icon(@views.IconName::Search, size=24.0)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "icon colored smoke" {
  let view : @core.View[Unit] = @views.icon(@views.IconName::Close, color=@core.Color::black())
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "divider horizontal smoke" {
  let view : @core.View[Unit] = @views.divider()
  assert_eq(view.identity().kind, "Divider")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "divider vertical smoke" {
  let view : @core.View[Unit] = @views.divider(axis=@core.Axis::Vertical)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
