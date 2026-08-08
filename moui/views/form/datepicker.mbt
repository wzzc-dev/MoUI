// DatePickerMode moved to style/ sub-package.

///|
pub fn[Msg] datepicker(
  selected~ : @core.DateValue,
  on_select~ : (@core.DateValue) -> Msg,
  mode? : @style.DatePickerMode = @style.DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme,
  style? : @style.PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside date_picker_control so the picker
  // tracks dark-mode / palette changes without the caller rebuilding the tree.
  date_picker_control(
    selected~,
    mode=datepicker_mode_to_view_mode(mode),
    placeholder~,
    theme?,
    style?,
    min_date~,
    max_date~,
    on_select=Some(on_select),
  )
}

///|
fn datepicker_mode_to_view_mode(
  mode : @style.DatePickerMode,
) -> DatePickerDisplayMode {
  match mode {
    Date => DatePickerDisplayMode::Date
    DateAndTime => DatePickerDisplayMode::DateAndTime
    Time => DatePickerDisplayMode::Time
  }
}
