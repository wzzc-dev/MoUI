///|
pub fn[Msg] toggle(
  label : String,
  checked : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox(label, checked~, on_change~, theme~, foreground?, check_color?).semantics_role(
    @core.SemanticsRole::Switch,
  )
}

///|
pub fn[Msg] toggle_switch(
  label : String,
  checked : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  toggle(label, checked, on_change~, theme~, foreground?, check_color?)
}

///|
pub fn[Msg] radio(
  label : String,
  selected : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox(
    label,
    checked=selected,
    on_change~,
    theme~,
    foreground?,
    check_color?,
  ).semantics_role(@core.SemanticsRole::Radio)
}

///|
pub fn[Msg] toggle_binding(
  label : String,
  checked : @core.Binding[Bool],
  theme? : @core.Theme = @core.Theme::default(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox_binding(label, checked~, theme~, foreground?, check_color?).semantics_role(
    @core.SemanticsRole::Switch,
  )
}

///|
pub fn[Msg] toggle_switch_binding(
  label : String,
  checked : @core.Binding[Bool],
  theme? : @core.Theme = @core.Theme::default(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  toggle_binding(label, checked, theme~, foreground?, check_color?)
}

///|
pub fn[Msg] radio_binding(
  label : String,
  selected : @core.Binding[Bool],
  theme? : @core.Theme = @core.Theme::default(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox_binding(label, checked=selected, theme~, foreground?, check_color?).semantics_role(
    @core.SemanticsRole::Radio,
  )
}

///|
fn resolve_control_color(
  color : @core.Color?,
  fallback : @core.Color,
) -> @core.Color {
  match color {
    Some(value) => value
    None => fallback
  }
}

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
  @core.View::custom_view(
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
  let base = @core.View::custom_view(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height~))
    },
    paint=frame => {
      let track = @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + (frame.size.height - track_height) / 2.0,
        width=frame.size.width,
        height=track_height,
      )
      let knob_x = frame.origin.x +
        normalized * max_view_double(0.0, frame.size.width - knob)
      [
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
      ]
    },
    semantics_role=@core.SemanticsRole::Slider,
    semantics_label="Slider",
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

///|
pub fn[Msg] focus_ring(
  child : @core.View[Msg],
  focused~ : Bool,
  label? : String = "Focused item",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double,
  height? : Double,
  padding? : Double = 3.0,
  radius? : Double = 8.0,
) -> @core.View[Msg] {
  let ring = @core.BorderStyle::new(
    brush=@core.Brush::solid(
      if focused {
        theme.palette.primary
      } else {
        theme.palette.outline.multiply_alpha(0.42)
      },
    ),
    width=if focused { 2.0 } else { 1.0 },
  )
  let wrapped = @core.View::container(
    child=Some(child.padding(padding)),
    size=None,
    border=Some(ring),
    corner_radius=radius,
  )
  let framed = match (width, height) {
    (None, None) => wrapped
    _ => wrapped.frame(width?, height?)
  }
  framed
  .focusable()
  .semantics_selected(selected=focused)
  .semantics_description(if focused { "Focused" } else { "Not focused" })
  .accessibility_label(label)
}

///|
pub fn[Msg] menu_button(
  label : String,
  on_click? : Msg,
  variant? : ButtonVariant = ButtonVariant::Tonal,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 160.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let spec = match on_click {
    Some(message) =>
      button(label, on_click=message, variant~, theme~, width~, height~)
    None => button(label, variant~, theme~, width~, height~)
  }
  spec.semantics_role(@core.SemanticsRole::Menu)
}

///|
pub fn[Msg] tooltip(
  child : @core.View[Msg],
  message : String,
  visible? : Bool = false,
) -> @core.View[Msg] {
  if visible {
    stack([
      child,
      surface(
        text(message, width=180.0, height=24.0).semantics_role(
          @core.SemanticsRole::Tooltip,
        ),
        variant=SurfaceVariant::Raised,
      ).align(alignment=@core.Alignment::top_trailing()),
    ])
  } else {
    child
  }
}

///|
fn clamp_view_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn max_view_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_view_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}
