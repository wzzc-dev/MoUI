///|
pub fn[Msg] empty_state(
  title : String,
  message : String,
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  state_panel(
    title,
    message,
    action~,
    theme=resolved_theme,
    style~,
    width~,
    tone=Neutral,
  )
}

///|
pub fn[Msg] loading_state(
  title? : String = "Loading",
  message? : String = "Please wait while content is prepared.",
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  state_panel(
    title,
    message,
    action=None,
    theme=resolved_theme,
    style~,
    width~,
    tone=Info,
  )
}

///|
pub fn[Msg] error_state(
  title : String,
  message : String,
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  state_panel(
    title,
    message,
    action~,
    theme=resolved_theme,
    style~,
    width~,
    tone=Danger,
  )
}

///|
pub fn[Msg] inline_error(
  message : String,
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  badge_style? : @style.BadgeStyle,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  let badge_style = resolve_badge_style(badge_style, resolved_theme)
  let action_width = match action {
    Some(_) => 86.0
    None => 0.0
  }
  let message_width = @common.max_view_double(
    96.0,
    width - 72.0 - action_width - resolved_theme.spacing_scale.sm,
  )
  let body : Array[@core.View[Msg]] = [
    badge(
      "Error",
      tone=Danger,
      theme=resolved_theme,
      style=badge_style,
      width=64.0,
    ),
    @text.text(
      message,
      role=Caption,
      theme=resolved_theme,
      width=message_width,
      height=28.0,
    ).foreground(@controls.feedback_accent(Danger, style)),
  ]
  match action {
    Some(action) =>
      body.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=Ghost,
          theme=resolved_theme,
          width=86.0,
          height=32.0,
        ),
      )
    None => ()
  }
  @container.container(
    @layout.row(body, spacing=resolved_theme.spacing_scale.sm, align=Center),
    width~,
    height=44.0,
    background=@controls.feedback_background(Danger, style),
    corner_radius=style.radius,
    theme=resolved_theme,
    padding=style.padding,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(@controls.feedback_border(Danger, style)),
      width=1.0,
    ),
  )
  .semantics_role(Group)
  .semantics_invalid()
  .accessibility_label("Error: " + message)
}

///|
fn[Msg] state_panel(
  title : String,
  message : String,
  action~ : @controls.StateViewAction[Msg]?,
  theme~ : @core.Theme,
  style~ : @style.FeedbackStyle,
  width~ : Double,
  tone~ : @style.FeedbackTone,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = [
    @text.text(title, role=Control, theme~, width=width - 32.0, height=28.0),
    @text.text(message, role=Caption, theme~, width=width - 32.0, height=42.0),
  ]
  match action {
    Some(action) =>
      rows.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=Primary,
          theme~,
          width=128.0,
        ),
      )
    None => ()
  }
  @container.container(
    @layout.column(rows, spacing=theme.spacing_scale.sm, align=Start),
    width~,
    height=148.0,
    background=@controls.feedback_background(tone, style),
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  ).semantics_role(Group)
}
