///|
test "FieldAction applies text toggle and select to a keyed field" {
  let display = FormFieldState::new(name="display_name", initial="Ada")
  let toggled = FormFieldState::new(name="telemetry", initial="false")
  assert_eq(
    display.apply_action(FieldAction::Text("Grace")).value(),
    "Grace",
  )
  assert_eq(
    toggled.apply_action(FieldAction::Toggle(true)).value(),
    "true",
  )
  assert_eq(
    toggled.apply_action(FieldAction::Toggle(false)).value(),
    "false",
  )
  assert_eq(
    display.apply_action(FieldAction::Select("workspace-b")).value(),
    "workspace-b",
  )
}

///|
test "update_named_field touches only the matching field" {
  let display = FormFieldState::new(name="display_name", initial="Ada")
  let email = FormFieldState::new(name="email", initial="a@example.com")
  let updated = update_named_field(
    [display, email],
    "email",
    FieldAction::Text("b@example.com"),
  )
  assert_eq(updated.length(), 2)
  assert_eq(updated[0].value(), "Ada")
  assert_eq(updated[1].value(), "b@example.com")
}

///|
test "update_named_field leaves unknown names unchanged" {
  let display = FormFieldState::new(name="display_name", initial="Ada")
  let snapshot = [display]
  let updated = update_named_field(snapshot, "removed_field", FieldAction::Text("x"))
  assert_eq(updated[0].value(), "Ada")
}
