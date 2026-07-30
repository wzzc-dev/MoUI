///|
/// Smoke tests for form widgets: form_field, form_section, form_actions.
///|
test "form_field smoke" {
  let view : @core.View[Unit] = @views.form_field(
    label="Name",
    child=@views.text_field("", on_input=fn(_s) { () }),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "form_field with helper smoke" {
  let view : @core.View[Unit] = @views.form_field(
    label="Email",
    child=@views.text_field("", on_input=fn(_s) { () }),
    helper="Enter your email",
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "form_section smoke" {
  let view : @core.View[Unit] = @views.form_section(
    title="Section",
    [@views.text_field("", on_input=fn(_s) { () })],
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "form_actions smoke" {
  let view : @core.View[Unit] = @views.form_actions(
    primary=@views.StateViewAction::new(label="Submit", message=()),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "form_helper_text smoke" {
  let view : @core.View[Unit] = @views.form_helper_text("Help text")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "form_error smoke" {
  let view : @core.View[Unit] = @views.form_error("Something went wrong")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
