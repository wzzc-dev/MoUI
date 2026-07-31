///|
/// Smoke tests for toolbar, command_bar, status_bar.

///|
test "toolbar smoke" {
  let view : @core.View[Unit] = @views.toolbar([@views.button("A", on_click=())])
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "command_bar smoke" {
  let view : @core.View[Unit] = @views.command_bar([
    @views.action_item(id="a", label="A", message=()),
  ])
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "status_bar smoke" {
  let view : @core.View[Unit] = @views.status_bar(["Ready"])
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
