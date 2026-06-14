///|
pub fn[Msg] progress(
  value : Double,
  width? : Double = 180.0,
  height? : Double = 8.0,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.ProgressStyle,
  foreground? : @core.Color,
  background? : @core.Color,
) -> @core.View[Msg] {
  let value = clamp_view_double(value, 0.0, 1.0)
  let resolved_style = match style {
    Some(value) => value
    None => @core.ProgressStyle::default(theme~)
  }
  let foreground = resolve_control_color(foreground, resolved_style.foreground)
  let background = resolve_control_color(background, resolved_style.background)
  @core.View::primitive_custom_view(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height~))
    },
    paint=frame => {
      let radius = min_view_double(height / 2.0, resolved_style.radius)
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=frame, radius~),
          @core.Brush::solid(background),
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
          @core.Brush::solid(foreground),
        ),
      ]
    },
    semantics_role=@core.SemanticsRole::Progress,
    semantics_label="Progress",
  )
}
