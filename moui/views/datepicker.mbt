///|
pub(all) enum DatePickerMode {
  Date
  DateAndTime
  Time
} derive(Eq, Debug, ToJson)

///|
pub fn[Msg] datepicker(
  selected~ : @core.DateValue,
  on_select~ : (@core.DateValue) -> Msg,
  mode? : DatePickerMode = DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme,
  style? : PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside date_picker_control so the picker
  // tracks dark-mode / palette changes without the caller rebuilding the tree.
  date_picker_control(
    selected=@core.Binding::new(get=() => selected, set=_value => ()),
    mode=mode.to_view_mode(),
    placeholder~,
    theme?,
    style?,
    min_date~,
    max_date~,
    on_select=Some(on_select),
  )
}

///|
fn DatePickerMode::to_view_mode(self : DatePickerMode) -> DatePickerDisplayMode {
  match self {
    Date => DatePickerDisplayMode::Date
    DateAndTime => DatePickerDisplayMode::DateAndTime
    Time => DatePickerDisplayMode::Time
  }
}
