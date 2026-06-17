///|
pub fn[Msg] banner(
  title : String,
  message : String,
  tone? : FeedbackTone = FeedbackTone::Info,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = default_theme(),
  style? : FeedbackStyle,
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
  theme? : @core.Theme = default_theme(),
  style? : FeedbackStyle,
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
