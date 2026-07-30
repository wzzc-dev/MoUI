///|
/// Smoke tests for button, shortcut_button, button_group, chip, tag, stepper.
///|
test "button smoke" {
  let view : @core.View[Unit] = @views.button("Click", on_click=())
  assert_eq(view.identity().kind, "Button")
  assert_true(view.semantics().role == Some(@core.SemanticsRole::Button))
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "button variants smoke" {
  for variant in [
    @views.ButtonVariant::Primary,
    @views.ButtonVariant::Ghost,
    @views.ButtonVariant::Outline,
    @views.ButtonVariant::Subtle,
    @views.ButtonVariant::SubtleBrand,
    @views.ButtonVariant::Tonal,
  ] {
    let view : @core.View[Unit] = @views.button("Action", on_click=(), variant~)
    assert_eq(view.identity().kind, "Button")
    @common.assert_layouts(view)
    @common.assert_paints(view)
  }
}

///|
test "shortcut_button smoke" {
  let view : @core.View[Unit] = @views.shortcut_button("Copy", on_click=(), shortcut=@core.KeyboardShortcut::new(key="c", modifiers=@core.KeyModifiers::new(meta=true)), width=200.0, height=44.0)
  // Shortcut button wraps in accessibility + shortcut modifiers; identity is a compound chain
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "button_group smoke" {
  let view : @core.View[Unit] = @views.button_group([@views.action_item(id="a", label="A", message=()), @views.action_item(id="b", label="B", message=())])
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
