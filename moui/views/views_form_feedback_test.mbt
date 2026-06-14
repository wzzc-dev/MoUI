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

///|
test "enhanced input wrappers compose public controls" {
  let root : @core.View[Unit] = @views.form([
    @views.input_group(
      child=@views.text_field("Grouped", on_input=_value => ()),
      prefix=Some(@views.text("$", width=20.0, height=24.0)),
      suffix=Some(@views.text("USD", width=44.0, height=24.0)),
    ),
    @views.clearable_text_field("Search", on_input=_value => (), on_clear=()),
    @views.password_field(
      "secret",
      on_input=_value => (),
      revealed=false,
      on_toggle_reveal=(),
    ),
    @views.number_field("42", on_input=_value => (), on_step=Some(_delta => ())),
    @views.stepper(on_decrement=(), on_increment=(), label="Page"),
    @views.multiline_text_area_shell("Line one", on_input=_value => ()),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=380.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Grouped"))
  assert_true(has_text(commands, "USD"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Show"))
  assert_false(has_text(commands, "secret"))
  assert_true(has_text(commands, "******"))
  assert_true(has_text(commands, "42"))
  assert_true(has_text(commands, "Page"))
  assert_true(has_text(commands, "Line one"))
}
