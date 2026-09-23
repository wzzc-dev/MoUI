///|
test "FieldAction applies text toggle and select to a keyed field" {
  let display = @form.FormFieldState::new(name="display_name", initial="Ada")
  let toggled = @form.FormFieldState::new(name="telemetry", initial="false")
  assert_eq(display.apply_action(Text("Grace")).value(), "Grace")
  assert_eq(toggled.apply_action(Toggle(true)).value(), "true")
  assert_eq(toggled.apply_action(Toggle(false)).value(), "false")
  assert_eq(display.apply_action(Select("workspace-b")).value(), "workspace-b")
}

///|
test "update_named_field touches only the matching field" {
  let display = @form.FormFieldState::new(name="display_name", initial="Ada")
  let email = @form.FormFieldState::new(name="email", initial="a@example.com")
  let updated = @form.update_named_field(
    [display, email],
    "email",
    Text("b@example.com"),
  )
  assert_eq(updated.length(), 2)
  assert_eq(updated[0].value(), "Ada")
  assert_eq(updated[1].value(), "b@example.com")
}

///|
test "update_named_field leaves unknown names unchanged" {
  let display = @form.FormFieldState::new(name="display_name", initial="Ada")
  let snapshot = [display]
  let updated = @form.update_named_field(snapshot, "removed_field", Text("x"))
  assert_eq(updated[0].value(), "Ada")
}
