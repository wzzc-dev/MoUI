///|
fn[Msg] feedback_panel(
  message : String,
  tone~ : @style.FeedbackTone,
  action~ : @controls.StateViewAction[Msg]?,
  theme~ : @core.Theme,
  style~ : @style.FeedbackStyle,
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
      @text.text(
        title,
        role=@style.TextRole::Control,
        theme~,
        width=text_width,
        height=24.0,
      ),
    )
  }
  rows.push(
    @text.text(
      message,
      role=@style.TextRole::Caption,
      theme~,
      width=text_width,
      height=28.0,
    ),
  )
  let body = @layout.column(
    rows,
    spacing=theme.spacing_scale.xs,
    align=@style.CrossAlign::Start,
  )
  let content : @core.View[Msg] = match action {
    Some(action) =>
      @layout.row(
        [
          body.expanded(),
          @button.button(
            action.label,
            on_click=action.message,
            variant=@style.ButtonVariant::Tonal,
            theme~,
            width=92.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@style.CrossAlign::Center,
      )
    None => body
  }
  @container.container(
    content,
    width~,
    height~,
    background=@controls.feedback_background(tone, style),
    corner_radius=style.radius,
    theme~,
    padding=style.padding,
  )
  // Toasts and snackbars float above content; use the large elevation shadow
  // (the only non-zero tier in the minimal theme) so they lift off content.
  .shadow(theme.shadow_scale.lg)
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(@controls.feedback_border(tone, style)),
      width=1.0,
    ),
  )
}

///|
fn resolve_feedback_style(
  style : @style.FeedbackStyle?,
  theme : @core.Theme,
) -> @style.FeedbackStyle {
  match style {
    Some(value) => value
    None => @style.FeedbackStyle::default(theme~)
  }
}

// feedback_accent, feedback_background, feedback_border, feedback_tone_style
// moved to controls/ sub-package. Use @controls.feedback_* from here.
