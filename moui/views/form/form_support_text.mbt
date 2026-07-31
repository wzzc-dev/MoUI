///|
pub fn[Msg] form_error(
  message : String,
  theme? : @core.Theme,
  style? : @style.FormValidationStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  @text.text(
    message,
    role=@style.TextRole::Caption,
    theme=resolved_theme,
    width~,
    height=24.0,
  )
  .foreground(resolve_form_validation_style(style, resolved_theme).foreground)
  .semantics_role(@core.SemanticsRole::Text)
  .accessibility_label("Error: " + message)
}

///|
pub fn[Msg] form_helper_text(
  message : String,
  theme? : @core.Theme,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  @text.text(
    message,
    role=@style.TextRole::Caption,
    theme=resolved_theme,
    width~,
    height=24.0,
  )
  .foreground(resolved_theme.palette.muted)
  .semantics_role(@core.SemanticsRole::Text)
}

///|
fn resolve_form_validation_style(
  style : @style.FormValidationStyle?,
  theme : @core.Theme,
) -> @style.FormValidationStyle {
  match style {
    Some(value) => value
    None => @style.FormValidationStyle::default(theme~)
  }
}
