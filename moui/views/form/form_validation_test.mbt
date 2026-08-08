///|
test "form fields validate required values" {
  let name = FormFieldState::new(
    name="name",
    validator=required_field(message="Name required"),
  )
  let email = FormFieldState::new(name="email", initial="a@example.com")
  let invalid = validate_form([name, email])
  inspect(invalid.valid, content="false")
  inspect(invalid.errors.length(), content="1")
  inspect(invalid.errors[0].message, content="Name required")
  let valid = validate_form([name.with_value("Ada"), email])
  inspect(valid.valid, content="true")
  inspect(valid.errors.length(), content="0")
}

///|
test "form controller aggregates rules and first invalid field" {
  let name = FormFieldState::new(name="name", label="Name", rules=[
    FormValidationRule::required(message="Name required"),
  ])
  let email = FormFieldState::new(name="email", initial="ada", rules=[
    FormValidationRule::required(message="Email required"),
    FormValidationRule::new(message="Email must contain @", validate=value => {
      value.contains("@")
    }),
  ])
  let controller = FormController::new(fields=[name, email])
  let summary = controller.validate()
  inspect(summary.valid, content="false")
  inspect(summary.errors.length(), content="2")
  inspect(summary.first_invalid_id.unwrap_or(""), content="name")
  inspect(controller.field_error("email"), content="Email must contain @")
  let valid = FormController::new(fields=[
    name.with_value("Ada"),
    email.with_value("ada@example.com"),
  ]).validate()
  inspect(valid.valid, content="true")
  inspect(valid.first_invalid_id is None, content="true")
}
