///|
pub fn text_field(
  value : @core.Binding[String],
  on_submit? : (() -> Unit)? = None,
  placeholder? : String = "",
  style? : @core.TextFieldStyle = @core.TextFieldStyle::filled(),
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.ViewSpec {
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
