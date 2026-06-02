///|
pub fn[Msg] form(
  children : Array[@core.View[Msg]],
  spacing? : Double = @core.Theme::default().spacing_scale.lg,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double,
) -> @core.View[Msg] {
  column(children, spacing~, align=CrossAlign::Stretch)
  .frame(width?)
  .semantics_role(@core.SemanticsRole::Form)
  .accessibility_label("Form")
  .theme(theme)
}

///|
pub fn[Msg] form_section(
  title? : String = "",
  children : Array[@core.View[Msg]],
  summary? : String = "",
  spacing? : Double = @core.Theme::default().spacing_scale.md,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double,
  padding? : Double = @core.Theme::default().spacing_scale.md,
) -> @core.View[Msg] {
  let content_width = match width {
    Some(value) => views_max_double(40.0, value - padding * 2.0)
    None => 320.0
  }
  let rows : Array[@core.View[Msg]] = []
  if title != "" {
    rows.push(
      text(
        title,
        role=TextRole::Control,
        theme~,
        width=content_width,
        height=28.0,
      ),
    )
  }
  if summary != "" {
    rows.push(
      text(
        summary,
        role=TextRole::Caption,
        theme~,
        width=content_width,
        height=24.0,
      ),
    )
  }
  for child in children {
    rows.push(child)
  }
  surface(
    column(rows, spacing~, align=CrossAlign::Stretch),
    width?,
    variant=SurfaceVariant::Base,
    theme~,
    padding~,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] form_field(
  label~ : String,
  child~ : @core.View[Msg],
  helper? : String = "",
  error? : String = "",
  status? : FormFieldStatus = FormFieldStatus::Normal,
  layout? : FormFieldLayout = FormFieldLayout::Vertical,
  validation_display? : FormValidationDisplay = FormValidationDisplay::OnInvalid,
  required? : Bool = false,
  disabled? : Bool = false,
  read_only? : Bool = false,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
  label_width? : Double = 120.0,
) -> @core.View[Msg] {
  let resolved_status = form_field_resolved_status(
    status, required, disabled, read_only, error,
  )
  let content_width = match layout {
    Vertical => width
    Horizontal =>
      views_max_double(80.0, width - label_width - theme.spacing_scale.md)
  }
  let label_view = form_field_label(
    label,
    status=resolved_status,
    required=required || resolved_status == FormFieldStatus::Required,
    width=match layout {
      Vertical => width
      Horizontal => label_width
    },
    theme~,
  )
  let body_rows : Array[@core.View[Msg]] = [
    child.frame(width=content_width).disabled(disabled~),
  ]
  match
    form_field_support_text(
      helper~,
      error~,
      status=resolved_status,
      validation_display~,
      theme~,
      width=content_width,
    ) {
    Some(view) => body_rows.push(view)
    None => ()
  }
  let body = column(
    body_rows,
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Stretch,
  )
  let field = match layout {
    Vertical => column([label_view, body], spacing=theme.spacing_scale.xs)
    Horizontal =>
      row(
        [label_view, body],
        spacing=theme.spacing_scale.md,
        align=CrossAlign::Start,
      )
  }
  field
  .frame(width~)
  .semantics_role(@core.SemanticsRole::FormField)
  .semantics_required(
    required=required || resolved_status == FormFieldStatus::Required,
  )
  .semantics_invalid(invalid=resolved_status == FormFieldStatus::Invalid)
  .semantics_description(
    form_field_semantics_description(resolved_status, helper, error),
  )
  .accessibility_label(
    form_field_accessibility_label(label, resolved_status, error),
  )
}

///|
pub fn[Msg] form_field_state(
  field~ : @core.FormFieldState,
  child~ : @core.View[Msg],
  helper? : String = "",
  validation_display? : FormValidationDisplay = FormValidationDisplay::OnInvalid,
  required? : Bool = false,
  disabled? : Bool = false,
  read_only? : Bool = false,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
  label_width? : Double = 120.0,
) -> @core.View[Msg] {
  let label = if field.label == "" { field.name } else { field.label }
  let error = match field.validate() {
    Some(error) => error.message
    None => ""
  }
  form_field(
    label~,
    child~,
    helper~,
    error~,
    status=if error == "" {
      FormFieldStatus::Normal
    } else {
      FormFieldStatus::Invalid
    },
    validation_display~,
    required~,
    disabled~,
    read_only~,
    theme~,
    width~,
    label_width~,
  )
}

///|
pub fn[Msg] form_validation_summary(
  summary~ : @core.FormValidationSummary,
  title? : String = "Review required",
  valid_message? : String = "",
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  if summary.valid {
    if valid_message == "" {
      empty()
    } else {
      form_validation_success(valid_message, action~, theme~, width~)
    }
  } else {
    form_validation_error_summary(summary, title~, action~, theme~, width~)
  }
}

///|
pub fn[Msg] form_actions(
  primary~ : StateViewAction[Msg],
  secondary? : StateViewAction[Msg]? = None,
  status? : String = "",
  primary_enabled? : Bool = true,
  secondary_enabled? : Bool = true,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let action_width = 116.0
  let rows : Array[@core.View[Msg]] = []
  if status != "" {
    rows.push(
      text(status, role=TextRole::Caption, theme~, width~, height=24.0).foreground(
        theme.palette.muted,
      ),
    )
  }
  let actions : Array[@core.View[Msg]] = []
  match secondary {
    Some(action) =>
      actions.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=action_width,
          height=36.0,
        ).disabled(disabled=!secondary_enabled),
      )
    None => ()
  }
  actions.push(
    button(
      primary.label,
      on_click=primary.message,
      variant=ButtonVariant::Primary,
      theme~,
      width=action_width,
      height=36.0,
    ).disabled(disabled=!primary_enabled),
  )
  rows.push(
    row(
      actions,
      spacing=theme.spacing_scale.sm,
      justify=MainAlign::End,
      align=CrossAlign::Center,
    ).frame(width~, height=40.0),
  )
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Stretch),
    width~,
    height=if status == "" { 52.0 } else { 82.0 },
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Form actions")
}

///|
pub fn[Msg] form_workflow_bar(
  summary~ : @core.FormValidationSummary,
  primary~ : StateViewAction[Msg],
  secondary? : StateViewAction[Msg]? = None,
  focus_scope? : @core.FocusScope? = None,
  focus_invalid? : StateViewAction[Msg]? = None,
  valid_message? : String = "",
  invalid_title? : String = "Review required",
  status? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  if !summary.valid || valid_message != "" {
    rows.push(
      form_validation_summary(
        summary~,
        title=invalid_title,
        valid_message~,
        action=if summary.valid { None } else { focus_invalid },
        theme~,
        width~,
      ),
    )
  }
  rows.push(
    form_actions(
      primary~,
      secondary~,
      status=form_workflow_status(summary, focus_scope, status),
      primary_enabled=summary.valid,
      theme~,
      width~,
    ),
  )
  column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Stretch)
  .frame(width~)
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_invalid(invalid=!summary.valid)
  .semantics_description(form_workflow_description(summary, focus_scope))
  .accessibility_label("Form workflow")
}

///|
fn[Msg] form_validation_error_summary(
  summary : @core.FormValidationSummary,
  title~ : String,
  action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let content_width = views_max_double(
    120.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let rows : Array[@core.View[Msg]] = [
    text(
      title,
      role=TextRole::Control,
      theme~,
      width=content_width,
      height=26.0,
    ).foreground(form_error_color(theme)),
  ]
  match summary.first_invalid_id {
    Some(id) =>
      rows.push(
        text(
          "First invalid: " + id,
          role=TextRole::Caption,
          theme~,
          width=content_width,
          height=22.0,
        ).foreground(theme.palette.muted),
      )
    None => ()
  }
  for error in summary.errors {
    rows.push(
      text(
        form_validation_error_label(error),
        role=TextRole::Caption,
        theme~,
        width=content_width,
        height=24.0,
      ).foreground(form_error_color(theme)),
    )
  }
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Tonal,
          theme~,
          width=144.0,
          height=34.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height=form_validation_summary_height(summary, action, base=70.0),
    background=form_error_color(theme).multiply_alpha(0.12),
    corner_radius=theme.radius_scale.md,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(form_error_color(theme).multiply_alpha(0.72)),
      width=1.0,
    ),
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_invalid()
  .accessibility_label("Validation summary")
}

///|
fn[Msg] form_validation_success(
  message : String,
  action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = [
    text(
      message,
      role=TextRole::Caption,
      theme~,
      width=width - 24.0,
      height=28.0,
    ),
  ]
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Tonal,
          theme~,
          width=144.0,
          height=34.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height=if action is Some(_) { 82.0 } else { 48.0 },
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.sm,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Validation summary")
}

///|
fn form_validation_error_label(error : @core.FormFieldError) -> String {
  if error.name == "" {
    error.message
  } else {
    error.name + ": " + error.message
  }
}

///|
fn form_workflow_status(
  summary : @core.FormValidationSummary,
  focus_scope : @core.FocusScope?,
  status : String,
) -> String {
  if status != "" {
    return status
  }
  match focus_scope {
    Some(scope) =>
      if summary.valid {
        form_workflow_command_status(scope)
      } else {
        "Fix " +
        form_workflow_target(scope.focus_first_invalid(summary)) +
        " before submit"
      }
    None =>
      if summary.valid {
        "Ready to submit"
      } else {
        "Fix validation errors before submit"
      }
  }
}

///|
fn form_workflow_command_status(scope : @core.FocusScope) -> String {
  let submit = form_workflow_target(
    scope.command_target(@core.CommandIntent::Submit),
  )
  let cancel = form_workflow_target(
    scope.command_target(@core.CommandIntent::Cancel),
  )
  if submit == "none" && cancel == "none" {
    "Ready to submit"
  } else if cancel == "none" {
    "Enter: " + submit
  } else if submit == "none" {
    "Escape: " + cancel
  } else {
    "Enter: " + submit + " / Escape: " + cancel
  }
}

///|
fn form_workflow_description(
  summary : @core.FormValidationSummary,
  focus_scope : @core.FocusScope?,
) -> String {
  let validity = if summary.valid { "valid" } else { "invalid" }
  match focus_scope {
    Some(scope) =>
      validity +
      "; focus target: " +
      form_workflow_target(scope.focus_first_invalid(summary)) +
      "; " +
      form_workflow_command_status(scope)
    None => validity
  }
}

///|
fn form_workflow_target(target : String?) -> String {
  match target {
    Some(id) => id
    None => "none"
  }
}

///|
fn[Msg] form_validation_summary_height(
  summary : @core.FormValidationSummary,
  action : StateViewAction[Msg]?,
  base~ : Double,
) -> Double {
  let action_height = if action is Some(_) { 40.0 } else { 0.0 }
  base + summary.errors.length().to_double() * 28.0 + action_height
}

///|
pub fn[Msg] form_error(
  message : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(form_error_color(theme))
  .semantics_role(@core.SemanticsRole::Text)
  .accessibility_label("Error: " + message)
}

///|
pub fn[Msg] form_helper_text(
  message : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(theme.palette.muted)
  .semantics_role(@core.SemanticsRole::Text)
}

///|
fn form_field_resolved_status(
  status : FormFieldStatus,
  required : Bool,
  disabled : Bool,
  read_only : Bool,
  error : String,
) -> FormFieldStatus {
  if disabled {
    FormFieldStatus::Disabled
  } else if error != "" {
    FormFieldStatus::Invalid
  } else if read_only {
    FormFieldStatus::ReadOnly
  } else if status != FormFieldStatus::Normal {
    status
  } else if required {
    FormFieldStatus::Required
  } else {
    FormFieldStatus::Normal
  }
}

///|
fn[Msg] form_field_label(
  label : String,
  status~ : FormFieldStatus,
  required~ : Bool,
  width~ : Double,
  theme~ : @core.Theme,
) -> @core.View[Msg] {
  let label_text = if required { label + " *" } else { label }
  text(label_text, role=TextRole::Control, theme~, width~, height=26.0).foreground(
    form_field_label_color(status, theme),
  )
}

///|
fn[Msg] form_field_support_text(
  helper~ : String,
  error~ : String,
  status~ : FormFieldStatus,
  validation_display~ : FormValidationDisplay,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg]? {
  match validation_display {
    Hidden => None
    Always =>
      if error != "" {
        Some(form_error(error, theme~, width~))
      } else if status == FormFieldStatus::Validating {
        Some(
          form_helper_text(form_field_validating_text(helper), theme~, width~),
        )
      } else if helper != "" {
        Some(form_helper_text(helper, theme~, width~))
      } else {
        None
      }
    OnInvalid =>
      if status == FormFieldStatus::Invalid && error != "" {
        Some(form_error(error, theme~, width~))
      } else if status == FormFieldStatus::Validating {
        Some(
          form_helper_text(form_field_validating_text(helper), theme~, width~),
        )
      } else if helper != "" {
        Some(form_helper_text(helper, theme~, width~))
      } else {
        None
      }
  }
}

///|
fn form_field_label_color(
  status : FormFieldStatus,
  theme : @core.Theme,
) -> @core.Color {
  match status {
    Invalid => form_error_color(theme)
    Validating => theme.palette.primary
    Disabled => theme.palette.muted.multiply_alpha(0.68)
    ReadOnly => theme.palette.muted
    Normal | Required => theme.palette.foreground
  }
}

///|
fn form_field_validating_text(helper : String) -> String {
  if helper == "" {
    "Validating..."
  } else {
    helper + " Validating..."
  }
}

///|
fn form_field_semantics_description(
  status : FormFieldStatus,
  helper : String,
  error : String,
) -> String {
  if error != "" {
    error
  } else if status == FormFieldStatus::Validating {
    form_field_validating_text(helper)
  } else {
    helper
  }
}

///|
fn form_error_color(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => @core.Color::rgba(r=0.74, g=0.12, b=0.16)
    @core.ColorScheme::Dark => @core.Color::rgba(r=1.0, g=0.48, b=0.52)
  }
}

///|
fn form_field_accessibility_label(
  label : String,
  status : FormFieldStatus,
  error : String,
) -> String {
  match status {
    Invalid =>
      if error == "" {
        label + ", invalid"
      } else {
        label + ", invalid, " + error
      }
    Required => label + ", required"
    Validating => label + ", validating"
    Disabled => label + ", disabled"
    ReadOnly => label + ", read only"
    Normal => label
  }
}
