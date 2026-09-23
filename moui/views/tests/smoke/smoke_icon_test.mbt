///|
/// Smoke tests for icon, image, divider.

///|
test "icon smoke" {
  let view : @core.View[Unit] = @views.icon(Check)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "icon sized smoke" {
  let view : @core.View[Unit] = @views.icon(Search, size=24.0)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "icon colored smoke" {
  let view : @core.View[Unit] = @views.icon(Close, color=@core.Color::black())
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
  let view : @core.View[Unit] = @views.divider(axis=Vertical)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
