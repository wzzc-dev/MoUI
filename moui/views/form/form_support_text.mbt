///|
pub fn[Msg] form_error(
  message : String,
  theme? : @core.Theme,
  style? : @style.FormValidationStyle,
  width~ : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  @text.text(message, role=Caption, theme=resolved_theme, width~, height=24.0)
  .foreground(
    style.unwrap_or_else(() => {
      @style.FormValidationStyle::default(theme=resolved_theme)
    }).foreground,
  )
  .semantics_role(Text)
  .accessibility_label("Error: " + message)
}

///|
pub fn[Msg] form_helper_text(
  message : String,
  theme? : @core.Theme,
  width~ : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  @text.text(message, role=Caption, theme=resolved_theme, width~, height=24.0)
  .foreground(resolved_theme.palette.muted)
  .semantics_role(Text)
}
