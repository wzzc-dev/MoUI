///|
test "center card and title render simple content" {
  let root : @core.View[Unit] = @views.center(
    @views.card(@views.text("Centered").title()),
    width=400.0,
    height=300.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=300.0),
  )
  assert_true(has_text(runtime.draw_commands(), "Centered"))
}

///|
test "form field primitives build labels helper and errors" {
  let root : @core.View[Unit] = @views.form(
    [
      @views.form_section(
        [
          @views.form_field(
            label="Name",
            child=@views.text_field("Ada", on_input=_value => ()),
            helper="Shown on normal fields",
            required=true,
          ),
          @views.form_field(
            label="Email",
            child=@views.text_field("", on_input=_value => ()),
            error="Email is required",
            status=@views.FormFieldStatus::Invalid,
          ),
          @views.form_validation_summary(
            summary=@core.FormValidationSummary::from_errors([
              { name: "email", message: "Email is required" },
              { name: "token", message: "Token is expired" },
            ]),
            action=Some(
              @views.StateViewAction::new(label="Focus first", message=()),
            ),
          ),
          @views.form_field(
            label="Token",
            child=@views.text_field("readonly", on_input=_value => ()),
            status=@views.FormFieldStatus::ReadOnly,
            layout=@views.FormFieldLayout::Horizontal,
          ),
          @views.form_actions(
            primary=@views.StateViewAction::new(
              label="Save changes",
              message=(),
            ),
            secondary=Some(
              @views.StateViewAction::new(label="Cancel", message=()),
            ),
            status="Submit disabled until Email is valid",
            primary_enabled=false,
          ),
        ],
        title="Profile",
        summary="Grouped fields",
        width=420.0,
      ),
    ],
    width=440.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=320.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Profile"))
  assert_true(has_text(commands, "Name *"))
  assert_true(has_text(commands, "Shown on normal fields"))
  assert_true(has_text(commands, "Email is required"))
  assert_true(has_text(commands, "Review required"))
  assert_true(has_text(commands, "First invalid: email"))
  assert_true(has_text(commands, "token: Token is expired"))
  assert_true(has_text(commands, "Focus first"))
  assert_true(has_text(commands, "Submit disabled until Email is valid"))
  assert_true(has_text(commands, "Save changes"))
  assert_true(has_text(commands, "Cancel"))
  assert_true(runtime.semantics().children.length() > 0)
  guard find_semantics_label(runtime.semantics(), "Validation summary")
    is Some(summary) else {
    fail("expected validation summary semantics")
  }
  assert_true(summary.state.invalid)
  guard find_semantics_label(runtime.semantics(), "Save changes") is Some(save) else {
    fail("expected save action semantics")
  }
  assert_true(save.state.disabled)
}
