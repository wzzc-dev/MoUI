///|
pub using @style {type ButtonVariant}

///|
test "button exposes role label and identity" {
  let btn : @core.View[Unit] = @button.button("Submit", on_click=())
  let info = btn.semantics()
  assert_true(info.role == Some(Button))
  assert_eq(info.label, Some("Submit"))
  assert_eq(btn.identity().kind, "Button")
}

///|
test "button variants all produce valid views" {
  for
    variant in [
      ButtonVariant::Primary,
      Ghost,
      Outline,
      Subtle,
      SubtleBrand,
      Tonal,
    ] {
    let btn : @core.View[Unit] = @button.button("Action", on_click=(), variant~)
    assert_true(btn.semantics().role == Some(Button))
    assert_eq(btn.identity().kind, "Button")
  }
}
