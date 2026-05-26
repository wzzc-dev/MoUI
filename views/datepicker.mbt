///|
pub fn datepicker(
  selected~ : @core.Binding[@core.DateValue],
  mode? : @core.DatePickerMode = @core.DatePickerMode::Date,
  placeholder? : String = "Select date",
  theme? : @core.Theme = @core.Theme::default(),
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.ViewSpec {
  @core.ViewSpec::DatePickerSpec({
    key: None,
    selected,
    mode,
    placeholder,
    font: theme.typography.control,
    foreground: theme.foreground,
    background: @core.Brush::solid(theme.palette.surface),
    corner_radius: theme.radius_scale.md,
    min_date,
    max_date,
  })
}
