///|
pub fn[Msg] form_error(
  message : String,
  theme? : @core.Theme = default_theme(),
  style? : FormValidationStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(resolve_form_validation_style(style, theme).foreground)
  .semantics_role(@core.SemanticsRole::Text)
  .accessibility_label("Error: " + message)
}

///|
pub fn[Msg] form_helper_text(
  message : String,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(theme.palette.muted)
  .semantics_role(@core.SemanticsRole::Text)
}

///|
fn resolve_form_validation_style(
  style : FormValidationStyle?,
  theme : @core.Theme,
) -> FormValidationStyle {
  match style {
    Some(value) => value
    None => FormValidationStyle::default(theme~)
  }
}
