///|
pub fn checkbox(
  label : String,
  checked~ : @core.Binding[Bool],
  font? : @core.FontSpec = @core.Theme::default().typography.control,
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  check_color? : @core.Color = @core.Theme::default().palette.primary,
  box_size? : Double = 20.0,
  height? : Double = 32.0,
) -> @core.ViewSpec {
  @core.ViewSpec::CheckboxSpec({
    key: None,
    label,
    checked,
    font,
    foreground,
    check_color,
    size: @core.Size::new(width=box_size, height~),
  })
}
