///|
pub fn picker_item(id : String, label : String) -> @core.PickerItem {
  @core.PickerItem::new(id~, label~)
}

///|
pub fn[Msg] picker(
  items : Array[@core.PickerItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  placeholder? : String = "Select...",
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.PickerStyle,
  max_height? : Double = 200.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => @core.PickerStyle::default(theme~)
  }
  @widget.picker(
    items~,
    selected=@core.Binding::new(get=() => selected, set=_value => ()),
    placeholder~,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    max_height~,
    on_select=Some(on_select),
  )
}

///|
pub fn[Msg] picker_binding(
  items : Array[@core.PickerItem],
  selected~ : @core.Binding[String],
  placeholder? : String = "Select...",
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.PickerStyle,
  max_height? : Double = 200.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => @core.PickerStyle::default(theme~)
  }
  @widget.picker(
    items~,
    selected~,
    placeholder~,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    max_height~,
  )
}
