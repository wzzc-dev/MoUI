///|
pub fn[Msg] slider(
  value : Double,
  min? : Double = 0.0,
  max? : Double = 1.0,
  width? : Double = 180.0,
  height? : Double = 28.0,
  theme? : @core.Theme,
  style? : SliderStyle,
  foreground? : @core.Color,
  background? : @core.Color,
  on_change? : ((Double) -> Msg)? = None,
) -> @core.View[Msg] {
  let range = if max <= min { 1.0 } else { max - min }
  let normalized = clamp_view_double((value - min) / range, 0.0, 1.0)
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  let base = custom_control(
    kind="Slider",
    measure=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      // Resolve the slider style ambient-ly so the track/thumb track
      // dark-mode / palette / thumb-shape changes without a rebuild.
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => SliderStyle::default(theme=resolved_theme)
      }
      let knob = min_view_double(height, resolved_style.thumb_size)
      let track_height = min_view_double(height, resolved_style.track_height)
      let track_radius = min_view_double(
        track_height / 2.0,
        resolved_style.radius,
      )
      // Circle thumbs force a full circle (radius = knob/2) regardless of the
      // theme radius; Rounded thumbs respect the resolved radius.
      let thumb_shape = resolved_theme.components.slider.thumb_shape
      let thumb_radius = match thumb_shape {
        @core.ThumbShape::Circle => knob / 2.0
        @core.ThumbShape::Rounded =>
          min_view_double(knob / 2.0, resolved_style.radius)
      }
      let foreground_color = resolve_control_color(
        foreground,
        resolved_style.foreground,
      )
      let track_background = resolve_control_color(
        background,
        resolved_style.background,
      )
      let thumb_color = resolve_control_color(
        foreground,
        resolved_style.thumb_color,
      )
      let frame = ctx.frame
      // Focus grows the thumb slightly so keyboard users get a visible
      // affordance, and the thumb gains a crisp ring that separates it from
      // the filled track. Ring color is a near-white highlight in light mode
      // and a faint surface-tinted edge in dark mode.
      let focused = ctx.focused
      let thumb_size = knob + (if focused { 3.0 } else { 0.0 })
      let ring_color = match resolved_theme.scheme {
        @core.ColorScheme::Light => @core.Color::white().with_alpha(0.92)
        @core.ColorScheme::Dark =>
          resolved_theme.palette.foreground.with_alpha(0.18)
      }
      let ring_width = 2.0
      let track = @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + (frame.size.height - track_height) / 2.0,
        width=frame.size.width,
        height=track_height,
      )
      let knob_x = frame.origin.x +
        normalized * max_view_double(0.0, frame.size.width - thumb_size)
      let thumb_rect = @core.RoundedRect::new(
        rect=@core.Rect::new(
          x=knob_x,
          y=frame.origin.y + (frame.size.height - thumb_size) / 2.0,
          width=thumb_size,
          height=thumb_size,
        ),
        radius=thumb_radius,
      )
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=track, radius=track_radius),
          @core.Brush::solid(track_background),
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
          thumb_rect,
          @core.Brush::solid(thumb_color),
        ),
        @core.DrawCommand::StrokeRoundedRectBrush(
          thumb_rect,
          @core.Brush::solid(ring_color),
          ring_width,
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Slider,
        label="Slider",
        value="\{value}",
      )
    },
    revision=() => "slider:\{value}:\{width}:\{height}:\{theme_revision}",
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

