///|
pub fn[Msg] banner(
  title : String,
  message : String,
  tone~ : @style.FeedbackTone = Info,
  action~ : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width~ : Double = 420.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = style.unwrap_or_else(() => {
    @style.FeedbackStyle::default(theme=resolved_theme)
  })
  feedback_panel(
    message,
    tone~,
    action~,
    theme=resolved_theme,
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
  tone~ : @style.FeedbackTone = Info,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width~ : Double = 360.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = style.unwrap_or_else(() => {
    @style.FeedbackStyle::default(theme=resolved_theme)
  })
  feedback_panel(
    message,
    tone~,
    action=None,
    theme=resolved_theme,
    style~,
    width~,
    title~,
    height=86.0,
  )
}
