///|
pub fn[Msg] progress_status(
  title : String,
  value~ : Double,
  message? : String = "",
  status? : String = "",
  tone? : FeedbackTone = FeedbackTone::Info,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  badge_style? : @core.BadgeStyle,
  progress_style? : @core.ProgressStyle,
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  let badge_style = resolve_badge_style(badge_style, theme)
  let progress_style = match progress_style {
    Some(value) => value
    None => @core.ProgressStyle::default(theme~)
  }
  let inner_width = views_max_double(
    120.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let status_text = if status == "" {
    progress_status_label(value)
  } else {
    status
  }
  let status_width = views_max_double(
    72.0,
    status_text.to_array().length().to_double() * 8.0 + 22.0,
  )
  let title_width = views_max_double(80.0, inner_width - status_width - 10.0)
  let rows : Array[@core.View[Msg]] = [
    row(
      [
        text(
          title,
          role=TextRole::Control,
          theme~,
          width=title_width,
          height=24.0,
        ),
        status_badge(
          status_text,
          tone=progress_status_badge_tone(tone),
          detail="Progress status for " + title,
          theme~,
          style=badge_style,
          width=status_width,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=CrossAlign::Center,
    ),
  ]
  if message != "" {
    rows.push(
      text(
        message,
        role=TextRole::Caption,
        theme~,
        width=inner_width,
        height=28.0,
      ),
    )
  }
  rows.push(
    progress(value, width=inner_width, height=8.0, style={
      ..progress_style,
      foreground: feedback_accent(tone, style),
    }),
  )
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Tonal,
          theme~,
          width=128.0,
          height=34.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height=progress_status_height(message != "", action is Some(_)),
    background=feedback_background(tone, style),
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        feedback_accent(tone, style).multiply_alpha(0.64),
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
  let normalized = clamp_view_double(value, 0.0, 1.0)
  if normalized <= 0.0 {
    "Pending"
  } else if normalized >= 1.0 {
    "Complete"
  } else {
    "In progress"
  }
}

///|
fn progress_status_badge_tone(tone : FeedbackTone) -> BadgeTone {
  match tone {
    Success => BadgeTone::Success
    Warning => BadgeTone::Warning
    Danger => BadgeTone::Danger
    Neutral | Info => BadgeTone::Accent
  }
}

///|
fn progress_status_height(has_message : Bool, has_action : Bool) -> Double {
  86.0 +
  (if has_message { 32.0 } else { 0.0 }) +
  (if has_action { 42.0 } else { 0.0 })
}
