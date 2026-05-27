///|
pub fn picker_item(id : String, label : String) -> @core.PickerItem {
  { id, label }
}

///|
pub fn[Msg] picker(
  items : Array[@core.PickerItem],
  selected~ : @core.Binding[String],
  placeholder? : String = "Select...",
  theme? : @core.Theme = @core.Theme::default(),
  max_height? : Double = 200.0,
) -> @core.View[Msg] {
  @core.View::picker(
    items~,
    selected~,
    placeholder~,
    font=theme.typography.control,
    foreground=theme.foreground,
    background=@core.Brush::solid(theme.palette.surface),
    corner_radius=theme.radius_scale.md,
    max_height~,
  )
}
