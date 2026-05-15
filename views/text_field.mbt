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
    background: normal.background.fallback_color(),
    border_color: optional_brush_color(normal.border, @core.Color::gray()),
    focused_border_color: optional_brush_color(
      focused.border, @core.Color::blue(),
    ),
    cursor_color: style.cursor_color,
    corner_radius: normal.radius,
    on_submit,
  })
}

///|
fn optional_brush_color(brush : @core.Brush?, fallback : @core.Color) -> @core.Color {
  match brush {
    Some(brush) => brush.fallback_color()
    None => fallback
  }
}
