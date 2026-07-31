// Feedback tone/style helpers used by dialog_alert and feedback_panel.
// Moved here so controls/ can reference them without importing the parent
// package. Root feedback_panel.mbt re-uses them via @controls.

///|
pub fn feedback_accent(
  tone : @style.FeedbackTone,
  style : @style.FeedbackStyle,
) -> @core.Color {
  feedback_tone_style(tone, style).foreground
}

///|
pub fn feedback_background(
  tone : @style.FeedbackTone,
  style : @style.FeedbackStyle,
) -> @core.Color {
  feedback_tone_style(tone, style).background
}

///|
pub fn feedback_border(
  tone : @style.FeedbackTone,
  style : @style.FeedbackStyle,
) -> @core.Color {
  feedback_tone_style(tone, style).border
}

///|
pub fn feedback_tone_style(
  tone : @style.FeedbackTone,
  style : @style.FeedbackStyle,
) -> @style.ToneStyle {
  match tone {
    @style.FeedbackTone::Neutral => style.neutral
    @style.FeedbackTone::Info => style.info
    @style.FeedbackTone::Success => style.success
    @style.FeedbackTone::Warning => style.warning
    @style.FeedbackTone::Danger => style.danger
  }
}
