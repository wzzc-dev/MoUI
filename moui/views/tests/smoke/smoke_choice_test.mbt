///|
/// Smoke tests for choice controls: checkbox, toggle, radio.

///|
test "checkbox smoke" {
  let view : @core.View[Unit] = @views.checkbox("Agree", checked=true, on_change=fn(
    _b,
  ) {
    ()
  })
  assert_true(view.semantics().role == Some(@core.SemanticsRole::Checkbox))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "toggle smoke" {
  let view : @core.View[Unit] = @views.toggle("On", true, on_change=fn(_b) {
    ()
  })
  assert_true(view.semantics().role == Some(@core.SemanticsRole::Switch))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "radio smoke" {
  let view : @core.View[Unit] = @views.radio("Option", true, on_change=fn(_b) {
    ()
  })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
