///|
pub fn toggle(
  label : String,
  checked : @core.Binding[Bool],
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  check_color? : @core.Color = @core.Theme::default().palette.primary,
) -> @core.ViewSpec {
  checkbox(label, checked~, foreground~, check_color~).semantics_role(
    @core.SemanticsRole::Switch,
  )
}

///|
pub fn toggle_switch(
  label : String,
  checked : @core.Binding[Bool],
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  check_color? : @core.Color = @core.Theme::default().palette.primary,
) -> @core.ViewSpec {
  toggle(label, checked, foreground~, check_color~)
}

///|
pub fn radio(
  label : String,
  selected : @core.Binding[Bool],
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  check_color? : @core.Color = @core.Theme::default().palette.primary,
) -> @core.ViewSpec {
  checkbox(label, checked=selected, foreground~, check_color~).semantics_role(
    @core.SemanticsRole::Radio,
  )
}

///|
pub fn progress(
  value : Double,
  width? : Double = 180.0,
  height? : Double = 8.0,
  foreground? : @core.Color = @core.Theme::default().palette.primary,
  background? : @core.Color = @core.Theme::default().palette.surface_variant,
) -> @core.ViewSpec {
  let value = clamp_view_double(value, 0.0, 1.0)
  @core.ViewSpec::custom(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height~))
    },
    paint=frame => {
      let radius = height / 2.0
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
pub fn slider(
  value : @core.Binding[Double],
  min? : Double = 0.0,
  max? : Double = 1.0,
  width? : Double = 180.0,
  height? : Double = 28.0,
  foreground? : @core.Color = @core.Theme::default().palette.primary,
  background? : @core.Color = @core.Theme::default().palette.surface_variant,
) -> @core.ViewSpec {
  let range = if max <= min { 1.0 } else { max - min }
  let normalized = clamp_view_double((value.get() - min) / range, 0.0, 1.0)
  let knob = height * 0.72
  @core.ViewSpec::custom(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height~))
    },
    paint=frame => {
      let track_height = 6.0
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
          @core.RoundedRect::new(rect=track, radius=track_height / 2.0),
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
            radius=track_height / 2.0,
          ),
          @core.Brush::solid(foreground),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=knob_x,
              y=frame.origin.y + (frame.size.height - knob) / 2.0,
              width=knob,
              height=knob,
            ),
            radius=knob / 2.0,
          ),
          @core.Brush::solid(foreground),
        ),
      ]
    },
    semantics_role=@core.SemanticsRole::Slider,
    semantics_label="Slider",
  )
}

///|
pub fn menu_button(
  label : String,
  on_click? : @core.ClickHandler,
  variant? : ButtonVariant = ButtonVariant::Tonal,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 160.0,
  height? : Double = 40.0,
) -> @core.ViewSpec {
  let spec = match on_click {
    Some(handler) =>
      button(label, on_click=handler, variant~, theme~, width~, height~)
    None => button(label, variant~, theme~, width~, height~)
  }
  spec.semantics_role(@core.SemanticsRole::Menu)
}

///|
pub fn tooltip(
  child : @core.ViewSpec,
  message : String,
  visible? : Bool = false,
) -> @core.ViewSpec {
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
