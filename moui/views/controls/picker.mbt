///|
pub fn picker_item(id : String, label : String) -> @style.PickerItem {
  @style.PickerItem::new(id~, label~)
}

///|
fn picker_options(items : Array[@style.PickerItem]) -> Array[PickerOption] {
  let options : Array[PickerOption] = []
  for item in items {
    options.push(PickerOption::new(id=item.id(), label=item.label()))
  }
  options
}

///|
pub fn[Msg] picker(
  items : Array[@style.PickerItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  placeholder? : String = "Select...",
  theme? : @core.Theme,
  style? : @style.PickerStyle,
  max_height? : Double = 200.0,
) -> @core.View[Msg] {
  picker_control(
    items=picker_options(items),
    selected=@core.ControlledValue::new(value=selected, changed=on_select),
    placeholder~,
    theme?,
    style?,
    max_height~,
  )
}
