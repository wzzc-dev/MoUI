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
  summary~ : FormValidationSummary,
  primary~ : StateViewAction[Msg],
  secondary? : StateViewAction[Msg]? = None,
  focus_scope? : @core.FocusScope? = None,
  focus_invalid? : StateViewAction[Msg]? = None,
  valid_message? : String = "",
  invalid_title? : String = "Review required",
  status? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  style? : FormValidationStyle,
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
fn form_workflow_status(
  summary : FormValidationSummary,
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
        form_workflow_target(
          scope.focus_target_or_first(summary.first_invalid_id),
        ) +
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
  summary : FormValidationSummary,
  focus_scope : @core.FocusScope?,
) -> String {
  let validity = if summary.valid { "valid" } else { "invalid" }
  match focus_scope {
    Some(scope) =>
      validity +
      "; focus target: " +
      form_workflow_target(
        scope.focus_target_or_first(summary.first_invalid_id),
      ) +
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
