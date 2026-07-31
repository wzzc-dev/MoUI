///|
/// Smoke tests for text and text input widgets.

///|
test "text smoke" {
  let view : @core.View[Unit] = @views.text("Hello")
  assert_eq(view.identity().kind, "Text")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "text with role smoke" {
  let view : @core.View[Unit] = @views.text(
    "Title",
    role=@views.TextRole::Title,
  )
  assert_eq(view.identity().kind, "Text")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "text_field smoke" {
  let view : @core.View[Unit] = @views.text_field("", on_input=fn(_s) { () })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "text_area smoke" {
  let view : @core.View[Unit] = @views.text_area("", on_input=fn(_s) { () })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
