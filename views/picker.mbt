///|
pub fn picker_item(id : String, label : String) -> @core.PickerItem {
  { id, label }
}

///|
pub fn picker(
  items : Array[@core.PickerItem],
  selected~ : @core.Binding[String],
  placeholder? : String = "Select...",
  theme? : @core.Theme = @core.Theme::default(),
  max_height? : Double = 200.0,
) -> @core.ViewSpec {
  @core.ViewSpec::PickerSpec({
    key: None,
    items,
    selected,
    placeholder,
    font: theme.typography.control,
    foreground: theme.foreground,
    background: @core.Brush::solid(theme.palette.surface),
    cornerRadius: theme.radius_scale.md,
    maxHeight: max_height,
  })
}
