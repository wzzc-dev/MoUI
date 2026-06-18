///|
pub fn[Msg] text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  controlled_text_field_control(
    value~,
    on_input~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    font=resolved_style.font,
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    on_submit~,
  )
}

///|
pub fn[Msg] text_field_binding(
  value : @core.Binding[String],
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  text_field_control(
    value~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    font=resolved_style.font,
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    on_submit~,
  )
}
