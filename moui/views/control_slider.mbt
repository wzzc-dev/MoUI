///|
pub fn[Msg] slider(
  value : Double,
  min? : Double = 0.0,
  max? : Double = 1.0,
  width? : Double = 180.0,
  height? : Double = 28.0,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.SliderStyle,
  foreground? : @core.Color,
  background? : @core.Color,
  on_change? : ((Double) -> Msg)? = None,
) -> @core.View[Msg] {
  let range = if max <= min { 1.0 } else { max - min }
  let normalized = clamp_view_double((value - min) / range, 0.0, 1.0)
  let resolved_style = match style {
    Some(value) => value
    None => @core.SliderStyle::default(theme~)
  }
  let knob = min_view_double(height, resolved_style.thumb_size)
  let track_height = min_view_double(height, resolved_style.track_height)
  let track_radius = min_view_double(track_height / 2.0, resolved_style.radius)
  let thumb_radius = min_view_double(knob / 2.0, resolved_style.radius)
  let foreground_color = resolve_control_color(
    foreground,
    resolved_style.foreground,
  )
  let background = resolve_control_color(background, resolved_style.background)
  let thumb_color = resolve_control_color(
    foreground,
    resolved_style.thumb_color,
  )
  let base = @widget.custom(
    kind="Slider",
    measure=ctx => {
      @core.WidgetLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      let frame = ctx.frame
      let track = @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + (frame.size.height - track_height) / 2.0,
        width=frame.size.width,
        height=track_height,
      )
      let knob_x = frame.origin.x +
        normalized * max_view_double(0.0, frame.size.width - knob)
      @core.WidgetPaintPlan::commands([
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=track, radius=track_radius),
          @core.Brush::solid(background),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=track.origin.x,
              y=track.origin.y,
              width=track.size.width * normalized,
              height=track.size.height,
            ),
            radius=track_radius,
          ),
          @core.Brush::solid(foreground_color),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=knob_x,
              y=frame.origin.y + (frame.size.height - knob) / 2.0,
              width=knob,
              height=knob,
            ),
            radius=thumb_radius,
          ),
          @core.Brush::solid(thumb_color),
        ),
      ])
    },
    semantics=() => {
      @core.WidgetSemanticsInfo::new(
        role=@core.SemanticsRole::Slider,
        label="Slider",
        value="\{value}",
      )
    },
  )
  match on_change {
    Some(handler) =>
      base.on_drag_with_frame((event, frame) => {
        let track_width = max_view_double(1.0, width)
        let local_x = clamp_view_double(
          event.position.x - frame.origin.x,
          0.0,
          track_width,
        )
        let next = min + local_x / track_width * range
        handler(clamp_view_double(next, min, max))
      })
    None => base
  }
}

///|
pub fn[Msg] slider_binding(
  value : @core.Binding[Double],
  min? : Double = 0.0,
  max? : Double = 1.0,
  width? : Double = 180.0,
  height? : Double = 28.0,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.SliderStyle,
  foreground? : @core.Color,
  background? : @core.Color,
) -> @core.View[Msg] {
  slider(
    value.get(),
    min~,
    max~,
    width~,
    height~,
    theme~,
    style?,
    foreground?,
    background?,
  )
}
