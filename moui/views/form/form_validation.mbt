///|
pub fn[Msg] form_validation_summary(
  summary~ : FormValidationSummary,
  title? : String = "Review required",
  valid_message? : String = "",
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FormValidationStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  if summary.valid {
    if valid_message == "" {
      @container.empty()
    } else {
      form_validation_success(
        valid_message,
        action~,
        theme=resolved_theme,
        style?,
        width~,
      )
    }
  } else {
    form_validation_error_summary(
      summary,
      title~,
      action~,
      theme=resolved_theme,
      style=resolve_form_validation_style(style, resolved_theme),
      width~,
    )
  }
}

///|
fn[Msg] form_validation_error_summary(
  summary : FormValidationSummary,
  title~ : String,
  action~ : @controls.StateViewAction[Msg]?,
  theme~ : @core.Theme,
  style~ : @style.FormValidationStyle,
  width~ : Double,
) -> @core.View[Msg] {
  let content_width = @common.view_max_double(
    120.0,
    width - style.padding * 2.0,
  )
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=@style.TextRole::Control,
      theme~,
      width=content_width,
      height=26.0,
    ).foreground(style.foreground),
  ]
  match summary.first_invalid_id {
    Some(id) =>
      rows.push(
        @text.text(
          "First invalid: " + id,
          role=@style.TextRole::Caption,
          theme~,
          width=content_width,
          height=22.0,
        ).foreground(theme.palette.muted),
      )
    None => ()
  }
  for error in summary.errors {
    rows.push(
      @text.text(
        form_validation_error_label(error),
        role=@style.TextRole::Caption,
        theme~,
        width=content_width,
        height=24.0,
      ).foreground(style.foreground),
    )
  }
  match action {
    Some(action) =>
      rows.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=@style.ButtonVariant::Tonal,
          theme~,
          width=144.0,
          height=34.0,
        ),
      )
    None => ()
  }
  @container.container(
    column(rows, spacing=theme.spacing_scale.xs, align=@style.CrossAlign::Start),
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
  action~ : @controls.StateViewAction[Msg]?,
  theme~ : @core.Theme,
  style? : @style.FormValidationStyle,
  width~ : Double,
) -> @core.View[Msg] {
  let content_width = match style {
    Some(value) => @common.view_max_double(120.0, width - value.padding * 2.0)
    None => width - 24.0
  }
  let message_view = @text.text(
    message,
    role=@style.TextRole::Caption,
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
        @button.button(
          action.label,
          on_click=action.message,
          variant=@style.ButtonVariant::Tonal,
          theme~,
          width=144.0,
          height=34.0,
        ),
      )
    None => ()
  }
  let summary_view : @core.View[Msg] = match style {
    Some(value) =>
      @container.container(
        column(
          rows,
          spacing=theme.spacing_scale.xs,
          align=@style.CrossAlign::Start,
        ),
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
      @container.container(
        column(
          rows,
          spacing=theme.spacing_scale.xs,
          align=@style.CrossAlign::Start,
        ),
        width~,
        height=if action is Some(_) { 82.0 } else { 48.0 },
        variant=@style.ContainerVariant::Base,
        theme~,
        padding=theme.spacing_scale.sm,
      )
  }
  summary_view
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Validation summary")
}

///|
fn form_validation_error_label(error : FormFieldError) -> String {
  if error.name == "" {
    error.message
  } else {
    error.name + ": " + error.message
  }
}

///|
fn[Msg] form_validation_summary_height(
  summary : FormValidationSummary,
  action : @controls.StateViewAction[Msg]?,
  base~ : Double,
) -> Double {
  let action_height = if action is Some(_) { 40.0 } else { 0.0 }
  base + summary.errors.length().to_double() * 28.0 + action_height
}
