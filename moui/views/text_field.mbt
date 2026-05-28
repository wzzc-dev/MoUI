///|
pub fn[Msg] text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @core.View::controlled_text_field(
    value~,
    on_input~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    font=style.font,
    foreground=normal.foreground,
    placeholder_color=style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=style.cursor_color,
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
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @core.View::text_field(
    value~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    font=style.font,
    foreground=normal.foreground,
    placeholder_color=style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=style.cursor_color,
    corner_radius=normal.radius,
    on_submit~,
  )
}
