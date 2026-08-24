///|
/// Smoke tests for layout primitives: row, column, stack, spacer, empty, flex, flow, grid, wrap, responsive_grid, list

///|
test "row smoke" {
  let view : @core.View[Unit] = @views.row([@views.text("a"), @views.text("b")])
  assert_eq(view.identity().kind, "Flex")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "column smoke" {
  let view : @core.View[Unit] = @views.column([
    @views.text("a"),
    @views.text("b"),
  ])
  assert_eq(view.identity().kind, "Flex")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "stack smoke" {
  let view : @core.View[Unit] = @views.stack([
    @views.text("a"),
    @views.text("b"),
  ])
  assert_eq(view.identity().kind, "Stack")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "overlay host smoke" {
  let view : @core.View[Unit] = @views.overlay_host(@views.text("base"), [
    @views.PresentationSpec::new(
      id="over",
      kind=@views.PresentationKind::Tooltip,
      content=@views.text("over"),
    ),
  ])
  assert_eq(view.identity().kind, "OverlayHost")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "spacer smoke" {
  let view : @core.View[Unit] = @views.spacer()
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "empty view smoke" {
  let view : @core.View[Unit] = @views.empty()
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
