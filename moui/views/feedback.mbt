///|
pub fn[Msg] toast(
  message : String,
  tone? : FeedbackTone = FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  feedback_surface(
    message,
    tone~,
    action~,
    theme~,
    style~,
    width~,
    title="",
    height=52.0,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] toast_stack(
  items : Array[ToastStackItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 360.0,
  spacing? : Double = @core.Theme::default().spacing_scale.sm,
) -> @core.View[Msg] {
  if items.length() == 0 {
    empty()
  } else {
    let style = resolve_feedback_style(style, theme)
    let rows : Array[@core.View[Msg]] = []
    for item in items {
      rows.push(toast_stack_row(item, theme~, style~, width~, spacing~))
    }
    column(rows, spacing~, align=CrossAlign::Stretch)
    .semantics_role(@core.SemanticsRole::Group)
    .accessibility_label("Toast stack")
  }
}

///|
pub fn[Msg] snackbar(
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  feedback_surface(
    message,
    tone=FeedbackTone::Neutral,
    action~,
    theme~,
    style~,
    width~,
    title="",
    height=56.0,
  )
}

///|
pub fn[Msg] banner(
  title : String,
  message : String,
  tone? : FeedbackTone = FeedbackTone::Info,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  feedback_surface(
    message,
    tone~,
    action~,
    theme~,
    style~,
    width~,
    title~,
    height=92.0,
  )
}

///|
pub fn[Msg] callout(
  title : String,
  message : String,
  tone? : FeedbackTone = FeedbackTone::Info,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.FeedbackStyle,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  feedback_surface(
    message,
    tone~,
    action=None,
    theme~,
    style~,
    width~,
    title~,
    height=86.0,
  )
}

///|
fn[Msg] toast_stack_row(
  item : ToastStackItem[Msg],
  theme~ : @core.Theme,
  style~ : @core.FeedbackStyle,
  width~ : Double,
  spacing~ : Double,
) -> @core.View[Msg] {
  match item.dismiss {
    Some(message) => {
      let dismiss_width = 86.0
      row(
        [
          toast(
            item.message,
            tone=item.tone,
            action=item.action,
            theme~,
            style~,
            width=views_max_double(120.0, width - dismiss_width - spacing),
          ),
          button(
            "Dismiss",
            on_click=message,
            variant=ButtonVariant::Ghost,
            theme~,
            width=dismiss_width,
            height=36.0,
          ).semantics_dismiss_action(),
        ],
        spacing~,
        align=CrossAlign::Center,
      ).frame(width~, height=52.0)
    }
    None =>
      toast(
        item.message,
        tone=item.tone,
        action=item.action,
        theme~,
        style~,
        width~,
      )
  }
}

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
