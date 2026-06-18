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
  theme? : @core.Theme = default_theme(),
  style? : PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => PickerStyle::default(theme~)
  }
  date_picker_control(
    selected=@core.Binding::new(get=() => selected, set=_value => ()),
    mode=mode.to_view_mode(),
    placeholder~,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    min_date~,
    max_date~,
    on_select=Some(on_select),
  )
}

///|
pub fn[Msg] datepicker_binding(
  selected~ : @core.Binding[@core.DateValue],
  mode? : DatePickerMode = DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme = default_theme(),
  style? : PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => PickerStyle::default(theme~)
  }
  date_picker_control(
    selected~,
    mode=mode.to_view_mode(),
    placeholder~,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    min_date~,
    max_date~,
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
