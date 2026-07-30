///|
/// Smoke tests for data display widgets.
///|
test "table smoke" {
  let view : @core.View[Unit] = @views.table(
    [@views.table_column(id="name", label="Name", width=120.0)],
    [["Alice"], ["Bob"]],
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "pagination smoke" {
  let view : @core.View[Unit] = @views.pagination(
    page=1,
    page_count=10,
    on_previous=(),
    on_next=(),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "avatar smoke" {
  let view : @core.View[Unit] = @views.avatar("AB")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "stat_card smoke" {
  let view : @core.View[Unit] = @views.stat_card("Total", "42")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "tree_view smoke" {
  let view : @core.View[Unit] = @views.tree_view(
    [@views.tree_item(id="1", label="Root", children=[
      @views.tree_item(id="1.1", label="Child"),
    ])],
    expanded=[],
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
