///|
/// Append the standard control-background draw sequence to `commands`: an
/// elevation shadow (when a key shadow is supplied), a rounded-rect fill in the
/// resolved `background` brush, and a stroked border that honors high-contrast
/// accessibility mode (thickened and forced to the theme foreground so control
/// edges stay legible regardless of the theme's subtle outline alpha).
///
/// `background` is taken already-resolved so callers that interpolate the
/// background across interaction states (e.g. `button_control`'s hover/press
/// transition) can pass the blended brush through. `border` is the control's
/// own border for standard contrast; it is overridden wholesale in
/// high-contrast mode. The `frame` and `radius` define the rounded rect; the
/// `shadow` and the ambient contrast/scheme are read from `ctx.environment` so
/// every control shares the same a11y + elevation behavior without
/// reimplementing it.
fn append_control_background(
  ctx : @core.ViewPaintContext,
  commands : Array[@core.DrawCommand],
  background : @core.Brush,
  border : @core.BorderStyle?,
  shadow : @core.ShadowStyle?,
  radius : Double,
) -> Unit {
  let rounded = @core.RoundedRect::new(rect=ctx.frame, radius~)
  emit_elevation_shadow(
    commands,
    rounded,
    shadow,
    ctx.environment.color_scheme(),
  )
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  // High-contrast accessibility mode thickens borders and renders them in the
  // foreground color so control edges stay legible regardless of the theme's
  // subtle outline alpha. Borderless controls gain a thin outline so their
  // bounds are always discoverable.
  let resolved_border = match ctx.environment.accessibility_contrast {
    @core.AccessibilityContrast::High =>
      Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(ctx.environment.theme.palette.foreground),
          width=2.0,
        ),
      )
    @core.AccessibilityContrast::Standard =>
      match border {
        Some(b) => Some(b)
        None => None
      }
  }
  match resolved_border {
    Some(b) =>
      if b.width > 0.0 {
        commands.push(
          @core.DrawCommand::StrokeRoundedRectBrush(rounded, b.brush, b.width),
        )
      }
    None => ()
  }
}
