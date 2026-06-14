///|
fn[Msg] feedback_surface(
  message : String,
  tone~ : FeedbackTone,
  action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  style~ : @core.FeedbackStyle,
  width~ : Double,
  title~ : String,
  height~ : Double,
) -> @core.View[Msg] {
  let text_width = match action {
    Some(_) => width - 128.0
    None => width - 28.0
  }
  let rows : Array[@core.View[Msg]] = []
  if title != "" {
    rows.push(
      text(title, role=TextRole::Control, theme~, width=text_width, height=24.0),
    )
  }
  rows.push(
    text(message, role=TextRole::Caption, theme~, width=text_width, height=28.0),
  )
  let body = column(
    rows,
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Start,
  )
  let content : @core.View[Msg] = match action {
    Some(action) =>
      row(
        [
          body.expanded(),
          button(
            action.label,
            on_click=action.message,
            variant=ButtonVariant::Tonal,
            theme~,
            width=92.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=CrossAlign::Center,
      )
    None => body
  }
  surface(
    content,
    width~,
    height~,
    background=feedback_background(tone, style),
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(feedback_border(tone, style)),
      width=1.0,
    ),
  )
}

///|
fn resolve_feedback_style(
  style : @core.FeedbackStyle?,
  theme : @core.Theme,
) -> @core.FeedbackStyle {
  match style {
    Some(value) => value
    None => @core.FeedbackStyle::default(theme~)
  }
}

///|
fn feedback_accent(
  tone : FeedbackTone,
  style : @core.FeedbackStyle,
) -> @core.Color {
  feedback_tone_style(tone, style).foreground
}

///|
fn feedback_background(
  tone : FeedbackTone,
  style : @core.FeedbackStyle,
) -> @core.Color {
  feedback_tone_style(tone, style).background
}

///|
fn feedback_border(
  tone : FeedbackTone,
  style : @core.FeedbackStyle,
) -> @core.Color {
  feedback_tone_style(tone, style).border
}

///|
fn feedback_tone_style(
  tone : FeedbackTone,
  style : @core.FeedbackStyle,
) -> @core.ToneStyle {
  match tone {
    Neutral => style.neutral
    Info => style.info
    Success => style.success
    Warning => style.warning
    Danger => style.danger
  }
}
