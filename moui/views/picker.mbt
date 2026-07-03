///|
pub fn picker_item(id : String, label : String) -> PickerItem {
  PickerItem::new(id~, label~)
}

///|
fn picker_options(items : Array[PickerItem]) -> Array[PickerOption] {
  let options : Array[PickerOption] = []
  for item in items {
    options.push(PickerOption::new(id=item.id(), label=item.label()))
  }
  options
}

///|
pub fn[Msg] picker(
  items : Array[PickerItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  placeholder? : String = "Select...",
  theme? : @core.Theme,
  style? : PickerStyle,
  max_height? : Double = 200.0,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside picker_control so the picker tracks
  // dark-mode / palette changes without the caller rebuilding the view tree.
  picker_control(
    items=picker_options(items),
    selected=@core.Binding::new(get=() => selected, set=_value => ()),
    placeholder~,
    theme?,
    style?,
    max_height~,
    on_select=Some(on_select),
  )
}

