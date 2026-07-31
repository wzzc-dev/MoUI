///|
pub fn[Msg] progress_status(
  title : String,
  value~ : Double,
  message? : String = "",
  status? : String = "",
  tone? : @style.FeedbackTone = @style.FeedbackTone::Info,
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  badge_style? : @style.BadgeStyle,
  progress_style? : @style.ProgressStyle,
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  let badge_style = resolve_badge_style(badge_style, resolved_theme)
  let progress_style = match progress_style {
    Some(value) => value
    None => @style.ProgressStyle::default(theme=resolved_theme)
  }
  let inner_width = @common.max_view_double(
    120.0,
    width - resolved_theme.spacing_scale.md * 2.0,
  )
  let status_text = if status == "" {
    progress_status_label(value)
  } else {
    status
  }
  let status_width = @common.max_view_double(
    72.0,
    status_text.to_array().length().to_double() * 8.0 + 22.0,
  )
  let title_width = @common.max_view_double(
    80.0,
    inner_width - status_width - 10.0,
  )
  let rows : Array[@core.View[Msg]] = [
    row(
      [
        @text.text(
          title,
          role=@style.TextRole::Control,
          theme=resolved_theme,
          width=title_width,
          height=24.0,
        ),
        status_badge(
          status_text,
          tone=progress_status_badge_tone(tone),
          detail="Progress status for " + title,
          theme=resolved_theme,
          style=badge_style,
          width=status_width,
        ),
      ],
      spacing=resolved_theme.spacing_scale.xs,
      align=@style.CrossAlign::Center,
    ),
  ]
  if message != "" {
    rows.push(
      @text.text(
        message,
        role=@style.TextRole::Caption,
        theme=resolved_theme,
        width=inner_width,
        height=28.0,
      ),
    )
  }
  rows.push(
    @progress.progress(value, width=inner_width, height=8.0, style={
      ..progress_style,
      foreground: @controls.feedback_accent(tone, style),
    }),
  )
  match action {
    Some(action) =>
      rows.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=@style.ButtonVariant::Tonal,
          theme=resolved_theme,
          width=128.0,
          height=34.0,
        ),
      )
    None => ()
  }
  @container.container(
    column(
      rows,
      spacing=resolved_theme.spacing_scale.sm,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height=progress_status_height(message != "", action is Some(_)),
    background=@controls.feedback_background(tone, style),
    corner_radius=style.radius,
    theme=resolved_theme,
    padding=style.padding,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        @controls.feedback_accent(tone, style).multiply_alpha(0.64),
      ),
      width=1.0,
    ),
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_description(status_text)
  .accessibility_label("Progress: " + title)
}

///|
fn progress_status_label(value : Double) -> String {
  let normalized = @common.clamp_view_double(value, 0.0, 1.0)
  if normalized <= 0.0 {
    "Pending"
  } else if normalized >= 1.0 {
    "Complete"
  } else {
    "In progress"
  }
}

///|
fn progress_status_badge_tone(tone : @style.FeedbackTone) -> @style.BadgeTone {
  match tone {
    Success => @style.BadgeTone::Success
    Warning => @style.BadgeTone::Warning
    Danger => @style.BadgeTone::Danger
    Neutral | Info => @style.BadgeTone::Accent
  }
}

///|
fn progress_status_height(has_message : Bool, has_action : Bool) -> Double {
  86.0 +
  (if has_message { 32.0 } else { 0.0 }) +
  (if has_action { 42.0 } else { 0.0 })
}
