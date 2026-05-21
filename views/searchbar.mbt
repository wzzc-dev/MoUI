///|
pub fn searchbar(
  query~ : @core.Binding[String],
  placeholder? : String = "Search...",
  font? : @core.FontSpec = @core.Theme::default().typography.body,
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  placeholder_color? : @core.Color = @core.Theme::default().palette.muted,
  background? : @core.Brush = @core.Brush::solid(
    @core.Theme::default().palette.surface,
  ),
  border? : @core.BorderStyle? = Some(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(@core.Theme::default().palette.outline),
      width=1.0,
    ),
  ),
  focused_border? : @core.BorderStyle? = Some(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(@core.Theme::default().palette.primary),
      width=2.0,
    ),
  ),
  cursor_color? : @core.Color = @core.Theme::default().palette.primary,
  corner_radius? : Double = @core.Theme::default().radius_scale.md,
  on_submit? : (() -> Unit)? = None,
  on_clear? : (() -> Unit)? = None,
) -> @core.ViewSpec {
  @core.ViewSpec::SearchBarSpec({
    key: None,
    query,
    placeholder,
    font,
    foreground,
    placeholder_color,
    background,
    border,
    focused_border,
    cursor_color,
    corner_radius,
    on_submit,
    on_clear,
  })
}
