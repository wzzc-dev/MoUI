///|
pub fn text_field(
  value : @core.Binding[String],
  on_submit? : (() -> Unit)? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.ViewSpec {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @core.ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder,
    size: @core.Size::new(width~, height~),
    font: style.font,
    foreground: normal.foreground,
    placeholder_color: style.placeholder_color,
    background: normal.background,
    border: normal.border,
    focused_border: focused.border,
    cursor_color: style.cursor_color,
    corner_radius: normal.radius,
    on_submit,
  })
}
