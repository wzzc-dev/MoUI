///|
pub fn[Msg] empty_state(
  title : String,
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  state_panel(
    title,
    message,
    action~,
    theme~,
    style~,
    width~,
    tone=FeedbackTone::Neutral,
  )
}

///|
pub fn[Msg] loading_state(
  title? : String = "Loading",
  message? : String = "Please wait while content is prepared.",
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  state_panel(
    title,
    message,
    action=None,
    theme~,
    style~,
    width~,
    tone=FeedbackTone::Info,
  )
}

///|
pub fn[Msg] error_state(
  title : String,
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  state_panel(
    title,
    message,
    action~,
    theme~,
    style~,
    width~,
    tone=FeedbackTone::Danger,
  )
}

///|
pub fn[Msg] inline_error(
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  badge_style? : @core.BadgeStyle,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  let badge_style = resolve_badge_style(badge_style, theme)
  let action_width = match action {
    Some(_) => 86.0
    None => 0.0
  }
  let message_width = views_max_double(
    96.0,
    width - 72.0 - action_width - theme.spacing_scale.sm,
  )
  let body : Array[@core.View[Msg]] = [
    badge(
      "Error",
      tone=BadgeTone::Danger,
      theme~,
      style=badge_style,
      width=64.0,
    ),
    text(
      message,
      role=TextRole::Caption,
      theme~,
      width=message_width,
      height=28.0,
    ).foreground(feedback_accent(FeedbackTone::Danger, style)),
  ]
  match action {
    Some(action) =>
      body.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=86.0,
          height=32.0,
        ),
      )
    None => ()
  }
  surface(
    row(body, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height=44.0,
    background=feedback_background(FeedbackTone::Danger, style),
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(feedback_border(FeedbackTone::Danger, style)),
      width=1.0,
    ),
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_invalid()
  .accessibility_label("Error: " + message)
}

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
pub fn[Msg] badge(
  label : String,
  tone? : BadgeTone = BadgeTone::Neutral,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.BadgeStyle,
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let style = resolve_badge_style(style, theme)
  surface(
    text(
      label,
      role=TextRole::Caption,
      theme~,
      width=width - style.padding * 2.0,
      height=height - style.padding * 2.0,
    ).foreground(badge_foreground(tone, style)),
    width~,
    height~,
    background=badge_background(tone, style),
    corner_radius=min_view_double(height / 2.0, style.radius),
    padding=style.padding,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] status_badge(
  label : String,
  tone? : BadgeTone = BadgeTone::Neutral,
  detail? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.BadgeStyle,
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let base = badge(label, tone~, theme~, style?, width~, height~).accessibility_label(
    "Status: " + label,
  )
  if detail == "" {
    base
  } else {
    base.semantics_description(detail)
  }
}

///|
pub fn[Msg] stat_card(
  label : String,
  value : String,
  caption? : String = "",
  tone? : FeedbackTone = FeedbackTone::Neutral,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 180.0,
  height? : Double = 116.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  let rows : Array[@core.View[Msg]] = [
    text(label, role=TextRole::Caption, theme~, width=width - 24.0, height=22.0),
    text(value, role=TextRole::Title, theme~, width=width - 24.0, height=34.0).foreground(
      feedback_accent(tone, style),
    ),
  ]
  if caption != "" {
    rows.push(
      text(
        caption,
        role=TextRole::Caption,
        theme~,
        width=width - 24.0,
        height=22.0,
      ),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn[Msg] state_panel(
  title : String,
  message : String,
  action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  style~ : @core.FeedbackStyle,
  width~ : Double,
  tone~ : FeedbackTone,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=width - 32.0, height=28.0),
    text(
      message,
      role=TextRole::Caption,
      theme~,
      width=width - 32.0,
      height=42.0,
    ),
  ]
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Primary,
          theme~,
          width=128.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height=148.0,
    background=feedback_background(tone, style),
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  ).semantics_role(@core.SemanticsRole::Group)
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

///|
fn resolve_badge_style(
  style : @core.BadgeStyle?,
  theme : @core.Theme,
) -> @core.BadgeStyle {
  match style {
    Some(value) => value
    None => @core.BadgeStyle::default(theme~)
  }
}

///|
fn badge_background(tone : BadgeTone, style : @core.BadgeStyle) -> @core.Color {
  badge_tone_style(tone, style).background
}

///|
fn badge_foreground(tone : BadgeTone, style : @core.BadgeStyle) -> @core.Color {
  badge_tone_style(tone, style).foreground
}

///|
fn badge_tone_style(
  tone : BadgeTone,
  style : @core.BadgeStyle,
) -> @core.ToneStyle {
  match tone {
    Neutral => style.neutral
    Accent => style.accent
    Success => style.success
    Warning => style.warning
    Danger => style.danger
  }
}
