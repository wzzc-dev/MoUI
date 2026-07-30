///|
/// Smoke tests for containers: container, card, center.
///|
test "container smoke" {
  let view : @core.View[Unit] = @views.container(@views.text("inside"))
  assert_eq(view.identity().kind, "Container")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "container framed smoke" {
  let view : @core.View[Unit] = @views.container(@views.text("inside"), width=200.0, height=100.0)
  // With explicit width/height, container wraps in a Frame modifier, so identity changes
  assert_true(view.identity().kind.contains("Container"))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "card smoke" {
  let view : @core.View[Unit] = @views.card(@views.text("content"))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "center smoke" {
  let view : @core.View[Unit] = @views.center(@views.text("centered"))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "rounded_clip smoke" {
  let view : @core.View[Unit] = @views.rounded_clip(@views.text("clipped"), radius=8.0)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "scroll_view smoke" {
  let view : @core.View[Unit] = @views.scroll_view(@views.text("scrollable"))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "padding smoke" {
  let view : @core.View[Unit] = @views.padding(@views.text("padded"), 16.0)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "frame smoke" {
  let view : @core.View[Unit] = @views.frame(@views.text("framed"), width=200.0, height=100.0)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "expanded smoke" {
  let view : @core.View[Unit] = @views.expanded(@views.text("flex"))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "flexible smoke" {
  let view : @core.View[Unit] = @views.flexible(@views.text("flex"), weight=1.0)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
