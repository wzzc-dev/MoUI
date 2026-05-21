///|
pub fn datepicker(
  selected~ : @core.Binding[@core.DateValue],
  mode? : @core.DatePickerMode = @core.DatePickerMode::Date,
  placeholder? : String = "Select date",
  font? : @core.FontSpec = @core.Theme::default().typography.control,
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  background? : @core.Brush = @core.Brush::solid(
    @core.Theme::default().palette.surface,
  ),
  corner_radius? : Double = 8.0,
  min_date? : @core.DateValue? = None,
  max_date? : @core.DateValue? = None,
) -> @core.ViewSpec {
  @core.ViewSpec::DatePickerSpec({
    key: None,
    selected,
    mode,
    placeholder,
    font,
    foreground,
    background,
    corner_radius,
    min_date,
    max_date,
  })
}
