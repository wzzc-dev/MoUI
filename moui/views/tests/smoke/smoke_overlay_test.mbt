///|
/// Smoke tests for popover, dialog, sheet, context_menu_region.

///|
test "popover smoke" {
  let view : @core.View[Unit] = @views.overlay_host(
    @views.button("Open", on_click=()),
    [
      @views.PresentationSpec::new(
        id="menu",
        kind=@views.PresentationKind::Popover,
        content=@views.text("Menu content"),
      ),
    ],
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "context_menu_region smoke" {
  let view : @core.View[Unit] = @views.context_menu_region(
    child=@views.text("Right-click me"),
    menu=@views.text("Menu"),
    visible=false,
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "sheet smoke" {
  let view : @core.View[Unit] = @views.sheet(
    content=@views.text("Sheet content"),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "dialog smoke" {
  let view : @core.View[Unit] = @views.dialog(
    "Confirm",
    content=@views.text("Are you sure?"),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
