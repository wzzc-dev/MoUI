///|
pub fn[Msg] datepicker(
  selected~ : @core.Binding[@core.DateValue],
  mode? : @core.DatePickerMode = @core.DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme = @core.Theme::default(),
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.View[Msg] {
  @core.View::datepicker(
    selected~,
    mode~,
    placeholder~,
    font=theme.typography.control,
    foreground=theme.foreground,
    background=@core.Brush::solid(theme.palette.surface),
    corner_radius=theme.radius_scale.md,
    min_date~,
    max_date~,
  )
}
