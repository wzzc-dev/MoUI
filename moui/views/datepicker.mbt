///|
pub fn[Msg] datepicker(
  selected~ : @core.DateValue,
  on_select~ : (@core.DateValue) -> Msg,
  mode? : @core.DatePickerMode = @core.DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme = @core.Theme::default(),
  style? : PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => PickerStyle::default(theme~)
  }
  @widget.datepicker(
    selected=@core.Binding::new(get=() => selected, set=_value => ()),
    mode~,
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
  mode? : @core.DatePickerMode = @core.DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme = @core.Theme::default(),
  style? : PickerStyle,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => PickerStyle::default(theme~)
  }
  @widget.datepicker(
    selected~,
    mode~,
    placeholder~,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    min_date~,
    max_date~,
  )
}
