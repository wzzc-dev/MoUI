///|
pub fn[Msg] progress(
  value : Double,
  width? : Double = 180.0,
  height? : Double = 8.0,
  theme? : @core.Theme,
  style? : ProgressStyle,
  foreground? : @core.Color,
  background? : @core.Color,
) -> @core.View[Msg] {
  let value = clamp_view_double(value, 0.0, 1.0)
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  custom_control(
    kind="Progress",
    measure=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      // Resolve the progress style ambient-ly so the bar tracks dark-mode /
      // palette changes without the caller rebuilding the view tree.
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => ProgressStyle::default(theme=resolved_theme)
      }
      let resolved_foreground = resolve_control_color(
        foreground,
        resolved_style.foreground,
      )
      let resolved_background = resolve_control_color(
        background,
        resolved_style.background,
      )
      let frame = ctx.frame
      let radius = min_view_double(height / 2.0, resolved_style.radius)
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=frame, radius~),
          @core.Brush::solid(resolved_background),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=frame.origin.x,
              y=frame.origin.y,
              width=frame.size.width * value,
              height=frame.size.height,
            ),
            radius~,
          ),
          @core.Brush::solid(resolved_foreground),
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Progress,
        label="Progress",
        value="\{value}",
      )
    },
    revision=() => "progress:\{value}:\{width}:\{height}:\{theme_revision}",
  )
}
