///|
pub fn theme(
  font? : @core.FontSpec,
  foreground? : @core.Color,
  background? : @core.Color,
  accent? : @core.Color,
  spacing? : Double,
  corner_radius? : Double,
) -> @core.Theme {
  let base = @core.Theme::default()
  {
    font: font.unwrap_or(base.font),
    foreground: foreground.unwrap_or(base.foreground),
    background: background.unwrap_or(base.background),
    accent: accent.unwrap_or(base.accent),
    spacing: spacing.unwrap_or(base.spacing),
    corner_radius: corner_radius.unwrap_or(base.corner_radius),
  }
}

///|
pub fn environment(
  theme? : @core.Theme = @core.Theme::default(),
) -> @core.Environment {
  @core.Environment::default().with_theme(theme)
}
