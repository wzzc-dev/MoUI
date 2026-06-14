///|
test "form workflow bar links validation focus and keyboard action status" {
  let focus_scope = @core.FocusScope::new(
    items=[
      @core.FocusScopeItem::new(id="name"),
      @core.FocusScopeItem::new(id="email"),
      @core.FocusScopeItem::new(id="archived", enabled=false),
      @core.FocusScopeItem::new(id="submit", focusable=false),
    ],
    current=Some("name"),
    default_action="submit",
    dismiss_action="cancel",
  )
  let invalid_summary = @core.FormValidationSummary::from_errors([
    { name: "email", message: "Email is required" },
  ])
  let invalid_runtime = @runtime.AppRuntime::new_view(
    root=@views.form_workflow_bar(
      summary=invalid_summary,
      primary=@views.StateViewAction::new(label="Save", message=()),
      secondary=Some(@views.StateViewAction::new(label="Cancel", message=())),
      focus_scope=Some(focus_scope),
      focus_invalid=Some(
        @views.StateViewAction::new(label="Focus first", message=()),
      ),
      width=420.0,
    ),
    size=@core.Size::new(width=480.0, height=240.0),
  )
  let invalid_draw = invalid_runtime.draw_commands()
  assert_true(has_text(invalid_draw, "Review required"))
  assert_true(has_text(invalid_draw, "First invalid: email"))
  assert_true(has_text(invalid_draw, "Focus first"))
  assert_true(has_text(invalid_draw, "Fix email before submit"))
  guard find_semantics_label(invalid_runtime.semantics(), "Form workflow")
    is Some(workflow) else {
    fail("expected form workflow semantics")
  }
  assert_true(workflow.state.invalid)
  guard find_semantics_label(invalid_runtime.semantics(), "Save") is Some(save) else {
    fail("expected disabled primary action")
  }
  assert_true(save.state.disabled)
  let valid_runtime = @runtime.AppRuntime::new_view(
    root=@views.form_workflow_bar(
      summary=@core.FormValidationSummary::from_errors([]),
      primary=@views.StateViewAction::new(label="Save", message=()),
      secondary=Some(@views.StateViewAction::new(label="Cancel", message=())),
      focus_scope=Some(focus_scope),
      valid_message="All required fields pass",
      width=420.0,
    ),
    size=@core.Size::new(width=480.0, height=220.0),
  )
  let valid_draw = valid_runtime.draw_commands()
  assert_true(has_text(valid_draw, "All required fields pass"))
  assert_true(has_text(valid_draw, "Enter: submit / Escape: cancel"))
  guard find_semantics_label(valid_runtime.semantics(), "Save")
    is Some(valid_save) else {
    fail("expected enabled primary action")
  }
  assert_false(valid_save.state.disabled)
}

///|
test "form validation display can hide support text" {
  let root : @core.View[Unit] = @views.form_field(
    label="Hidden",
    child=@views.text_field("", on_input=_value => ()),
    error="Should not draw",
    validation_display=@views.FormValidationDisplay::Hidden,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=360.0, height=120.0),
  )
  assert_false(has_text(runtime.draw_commands(), "Should not draw"))
}

///|
test "form field validating state exposes preview semantics" {
  let root : @core.View[Unit] = @views.form_field(
    label="Workspace slug",
    child=@views.text_field("", on_input=_value => ()),
    helper="Checking availability.",
    status=@views.FormFieldStatus::Validating,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=480.0, height=160.0),
  )
  assert_true(
    has_text(runtime.draw_commands(), "Checking availability. Validating..."),
  )
  guard find_semantics_label(runtime.semantics(), "Workspace slug, validating")
    is Some(field) else {
    fail("expected validating form field semantics")
  }
  assert_false(field.state.invalid)
  inspect(field.description, content="Checking availability. Validating...")
}

///|
test "form field state uses core validation errors" {
  let field = @core.FormFieldState::new(name="email", label="Email", rules=[
    @core.FormValidationRule::required(message="Email required"),
  ])
  let root : @core.View[Unit] = @views.form_field_state(
    field~,
    child=@views.text_field(field.value.get(), on_input=_value => ()),
    required=true,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=420.0, height=140.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Email *"))
  assert_true(has_text(commands, "Email required"))
}
