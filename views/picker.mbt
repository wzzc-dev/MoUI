///|
pub fn picker_item(id : String, label : String) -> @core.PickerItem {
  { id, label }
}

///|
pub fn picker(
  items : Array[@core.PickerItem],
  selected~ : @core.Binding[String],
  placeholder? : String = "Select...",
  font? : @core.FontSpec = @core.Theme::default().typography.control,
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  background? : @core.Brush = @core.Brush::solid(
    @core.Theme::default().palette.surface,
  ),
  corner_radius? : Double = 8.0,
  max_height? : Double = 200.0,
) -> @core.ViewSpec {
  @core.ViewSpec::PickerSpec({
    key: None,
    items,
    selected,
    placeholder,
    font,
    foreground,
    background,
    cornerRadius: corner_radius,
    maxHeight: max_height,
  })
}
