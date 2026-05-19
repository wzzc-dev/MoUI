///|
pub fn rich_text_editor(
  value : @core.Binding[String],
  format : @core.RichTextFormatter,
  placeholder? : String = "Write",
  style? : @core.TextFieldStyle = @core.TextFieldStyle::filled(),
  width? : Double = 520.0,
  height? : Double = 360.0,
) -> @core.ViewSpec {
  let normal = style.normal
  let focused = style.focused
  @core.ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder,
    size: @core.Size::new(width~, height~),
    format,
    font: style.font,
    foreground: normal.foreground,
    placeholder_color: style.placeholder_color,
    background: normal.background,
    border: normal.border,
    focused_border: focused.border,
    cursor_color: style.cursor_color,
    corner_radius: normal.radius,
  })
}

///|
pub fn markdown_editor(
  value : @core.Binding[String],
  format : @core.RichTextFormatter,
  placeholder? : String = "Write markdown",
  style? : @core.TextFieldStyle = @core.TextFieldStyle::filled(),
  width? : Double = 520.0,
  height? : Double = 360.0,
) -> @core.ViewSpec {
  rich_text_editor(value, format, placeholder~, style~, width~, height~)
}
