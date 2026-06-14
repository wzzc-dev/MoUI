///|
pub fn[Msg] form_validation_summary(
  summary~ : @core.FormValidationSummary,
  title? : String = "Review required",
  valid_message? : String = "",
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FormValidationStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  if summary.valid {
    if valid_message == "" {
      empty()
    } else {
      form_validation_success(valid_message, action~, theme~, style?, width~)
    }
  } else {
    form_validation_error_summary(
      summary,
      title~,
      action~,
      theme~,
      style=resolve_form_validation_style(style, theme),
      width~,
    )
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
  style? : @core.FormValidationStyle,
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
        style?,
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
  style~ : @core.FormValidationStyle,
  width~ : Double,
) -> @core.View[Msg] {
  let content_width = views_max_double(120.0, width - style.padding * 2.0)
  let rows : Array[@core.View[Msg]] = [
    text(
      title,
      role=TextRole::Control,
      theme~,
      width=content_width,
      height=26.0,
    ).foreground(style.foreground),
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
      ).foreground(style.foreground),
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
    background=style.background,
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  )
  .border(
    @core.BorderStyle::new(brush=@core.Brush::solid(style.border), width=1.0),
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
  style? : @core.FormValidationStyle,
  width~ : Double,
) -> @core.View[Msg] {
  let content_width = match style {
    Some(value) => views_max_double(120.0, width - value.padding * 2.0)
    None => width - 24.0
  }
  let message_view = text(
    message,
    role=TextRole::Caption,
    theme~,
    width=content_width,
    height=28.0,
  )
  let rows : Array[@core.View[Msg]] = [
    match style {
      Some(value) => message_view.foreground(value.foreground)
      None => message_view
    },
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
  let summary_view : @core.View[Msg] = match style {
    Some(value) =>
      surface(
        column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
        width~,
        height=if action is Some(_) { 82.0 } else { 48.0 },
        background=value.background,
        corner_radius=value.radius,
        theme~,
        padding=value.padding,
      ).border(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(value.border),
          width=1.0,
        ),
      )
    None =>
      surface(
        column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
        width~,
        height=if action is Some(_) { 82.0 } else { 48.0 },
        variant=SurfaceVariant::Base,
        theme~,
        padding=theme.spacing_scale.sm,
      )
  }
  summary_view
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
  style? : @core.FormValidationStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(resolve_form_validation_style(style, theme).foreground)
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
fn resolve_form_validation_style(
  style : @core.FormValidationStyle?,
  theme : @core.Theme,
) -> @core.FormValidationStyle {
  match style {
    Some(value) => value
    None => @core.FormValidationStyle::default(theme~)
  }
}
