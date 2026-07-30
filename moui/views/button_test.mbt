///|
test "button exposes role label and identity" {
  let btn : @core.View[Unit] = button("Submit", on_click=())
  let info = btn.semantics()
  assert_true(info.role == Some(@core.SemanticsRole::Button))
  assert_eq(info.label, Some("Submit"))
  assert_eq(btn.identity().kind, "Button")
}

///|
test "button variants all produce valid views" {
  for variant in [
    ButtonVariant::Primary,
    ButtonVariant::Ghost,
    ButtonVariant::Outline,
    ButtonVariant::Subtle,
    ButtonVariant::SubtleBrand,
    ButtonVariant::Tonal,
  ] {
    let btn : @core.View[Unit] = button("Action", on_click=(), variant=variant)
    assert_true(btn.semantics().role == Some(@core.SemanticsRole::Button))
    assert_eq(btn.identity().kind, "Button")
  }
}

///|
test "shortcut button creates a valid view with accessibility label" {
  let btn : @core.View[Unit] = shortcut_button(
    "Copy",
    on_click=(),
    shortcut=KeyboardShortcut::new(
      key="c",
      modifiers=@core.KeyModifiers::new(meta=true),
    ),
    width=200.0,
    height=44.0,
  )
  // Shortcut button carries an accessibility label describing the action
  let info = btn.semantics()
  assert_true(info.label is Some(label) && label != "")
}
