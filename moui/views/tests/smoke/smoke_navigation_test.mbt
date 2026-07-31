///|
/// Smoke tests for navigation widgets.

///|
test "tab_view smoke" {
  let view : @core.View[Unit] = @views.tab_view(
    "main",
    [
      @views.tab_item(route="1", label="Tab 1", view=@views.text("content 1")),
      @views.tab_item(route="2", label="Tab 2", view=@views.text("content 2")),
    ],
    on_select=fn(_s) { () },
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "breadcrumb smoke" {
  let view : @core.View[Unit] = @views.breadcrumb([
    @views.breadcrumb_item(id="home", label="Home"),
    @views.breadcrumb_item(id="page", label="Page"),
  ])
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "sidebar smoke" {
  let view : @core.View[Unit] = @views.sidebar(
    "main",
    [
      @views.sidebar_item(id="a", label="Item A", message=()),
      @views.sidebar_item(id="b", label="Item B", message=()),
    ],
    selected="a",
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "split_view smoke" {
  let view : @core.View[Unit] = @views.split_view(
    primary=@views.text("sidebar"),
    detail=@views.text("content"),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "wizard smoke" {
  let step = @views.WizardStep::new(
    id="1",
    title="Step 1",
    content=@views.text("content"),
  )
  let view : @core.View[Unit] = @views.wizard([step], current="1", on_select=fn(
    _s,
  ) {
    ()
  })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
