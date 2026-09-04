///|
pub fn[Msg] slider(
  value : Double,
  min? : Double = 0.0,
  max? : Double = 1.0,
  step? : Double,
  label? : String = "",
  value_text? : String,
  width? : Double = 180.0,
  height? : Double = 28.0,
  theme? : @core.Theme,
  style? : @style.SliderStyle,
  foreground? : @core.Color,
  background? : @core.Color,
  on_change? : ((Double) -> Msg)? = None,
) -> @core.View[Msg] {
  let resolved_max = if max <= min { min + 1.0 } else { max }
  let resolved_range = resolved_max - min
  let resolved_step = match step {
    Some(value) => if value > 0.0 { value } else { resolved_range / 10.0 }
    None => resolved_range / 10.0
  }
  let node = Slider::{
    value: @common.clamp_view_double(value, min, resolved_max),
    min,
    max: resolved_max,
    step: resolved_step,
    label,
    value_text,
    width,
    height,
    theme,
    style,
    foreground,
    background,
    has_on_change: on_change is Some(_),
  }
  let event_adapter = match on_change {
    Some(handler) =>
      (_node : Slider, context : @core.ViewEventContext) => {
        match context.event {
          @core.AppEvent::Pointer(pointer) =>
            match pointer.phase {
              @core.PointerPhase::Down =>
                if context.frame.contains(pointer.position) {
                  let local_x = pointer.position.x - context.frame.origin.x
                  let next = slider_value_at(
                    context.frame,
                    local_x,
                    _node.min,
                    _node.max,
                  )
                  {
                    ..@core.ViewEventResult::message(handler(next)),
                    focused: true,
                    captured: true,
                    state: Some({
                      ..context.state,
                      focused: true,
                      pressed: true,
                    }),
                    dirty: @core.ViewDirtyHint::ViewPaintDirty,
                  }
                } else {
                  @core.ViewEventResult::ignored()
                }
              @core.PointerPhase::Move =>
                if context.state.pressed {
                  let local_x = pointer.position.x - context.frame.origin.x
                  let next = slider_value_at(
                    context.frame,
                    local_x,
                    _node.min,
                    _node.max,
                  )
                  {
                    ..@core.ViewEventResult::message(handler(next)),
                    captured: true,
                    state: Some({ ..context.state, pressed: true }),
                    dirty: @core.ViewDirtyHint::ViewPaintDirty,
                  }
                } else {
                  @core.ViewEventResult::ignored()
                }
              @core.PointerPhase::Up
              | @core.PointerPhase::Cancel
              | @core.PointerPhase::Exit =>
                if context.state.pressed {
                  {
                    ..@core.ViewEventResult::ignored(),
                    state: Some({ ..context.state, pressed: false }),
                    dirty: @core.ViewDirtyHint::ViewPaintDirty,
                  }
                } else {
                  @core.ViewEventResult::ignored()
                }
            }
          _ => @core.ViewEventResult::ignored()
        }
      }
    None =>
      (_node : Slider, _context : @core.ViewEventContext) => {
        @core.ViewEventResult::ignored()
      }
  }
  @core.View::from_node(node, event=event_adapter, semantics_actions=node => {
    match on_change {
      Some(handler) =>
        [
          @core.ViewSemanticsActionHandler::increment(_ctx => {
            let next = @common.clamp_view_double(
              node.value + node.step,
              node.min,
              node.max,
            )
            if next == node.value {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(handler(next))
            }
          }),
          @core.ViewSemanticsActionHandler::decrement(_ctx => {
            let next = @common.clamp_view_double(
              node.value - node.step,
              node.min,
              node.max,
            )
            if next == node.value {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(handler(next))
            }
          }),
          @core.ViewSemanticsActionHandler::set_numeric_value((_ctx, value) => {
            let next = @common.clamp_view_double(value, node.min, node.max)
            if next == node.value {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(handler(next))
            }
          }),
          @core.ViewSemanticsActionHandler::scroll((_ctx, direction) => {
            let delta = match direction {
              @core.SemanticsScrollDirection::Forward
              | @core.SemanticsScrollDirection::Up
              | @core.SemanticsScrollDirection::Right => node.step
              @core.SemanticsScrollDirection::Backward
              | @core.SemanticsScrollDirection::Down
              | @core.SemanticsScrollDirection::Left => -node.step
            }
            let next = @common.clamp_view_double(
              node.value + delta,
              node.min,
              node.max,
            )
            if next == node.value {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(handler(next))
            }
          }),
        ]
      None => []
    }
  })
}

///|
/// Concrete view node for the `slider` control.
priv struct Slider {
  value : Double
  min : Double
  max : Double
  step : Double
  label : String
  value_text : String?
  width : Double
  height : Double
  theme : @core.Theme?
  style : @style.SliderStyle?
  foreground : @core.Color?
  background : @core.Color?
  has_on_change : Bool
}

///|
impl @core.ViewNode for Slider with fn identity(_self) {
  @core.ViewIdentity::new(kind="Slider")
}

///|
impl @core.ViewNode for Slider with fn declaration(self) {
  @common.view_declaration_auto(
    "Slider",
    self.theme,
    [
      ("width", @core.DeclarationKey::double(self.width)),
      ("height", @core.DeclarationKey::double(self.height)),
    ],
    [
      ("value", @core.DeclarationKey::double(self.value)),
      ("min", @core.DeclarationKey::double(self.min)),
      ("max", @core.DeclarationKey::double(self.max)),
      ("step", @core.DeclarationKey::double(self.step)),
      (
        "style",
        @core.DeclarationKey::option(
          self.style.map(style => {
            @common.view_record_key("SliderStyle", [
              ("foreground", @common.view_color_key(style.foreground)),
              ("background", @common.view_color_key(style.background)),
              ("thumb_color", @common.view_color_key(style.thumb_color)),
              ("track_height", @core.DeclarationKey::double(style.track_height)),
              ("thumb_size", @core.DeclarationKey::double(style.thumb_size)),
              ("radius", @core.DeclarationKey::double(style.radius)),
            ])
          }),
        ),
      ),
      (
        "foreground",
        @core.DeclarationKey::option(
          self.foreground.map(@common.view_color_key),
        ),
      ),
      (
        "background",
        @core.DeclarationKey::option(
          self.background.map(@common.view_color_key),
        ),
      ),
    ],
    [
      ("value", @core.DeclarationKey::double(self.value)),
      ("label", @core.DeclarationKey::string(self.label)),
      ("scroll", @core.DeclarationKey::bool(self.has_on_change)),
      (
        "value_text",
        @core.DeclarationKey::option(
          self.value_text.map(@core.DeclarationKey::string),
        ),
      ),
    ],
    layout_theme_dependent=false,
  )
}

///|
impl @core.ViewNode for Slider with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for Slider with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let set = @style.views_ambient_control_theme(resolved_theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => {
      let s = set.slider
      @style.SliderStyle::{
        foreground: s.foreground,
        background: s.background,
        thumb_color: s.thumb_color,
        track_height: s.track_height,
        thumb_size: s.thumb_size,
        radius: s.radius,
      }
    }
  }
  let range = if self.max <= self.min { 1.0 } else { self.max - self.min }
  let normalized = @common.clamp_view_double(
    (self.value - self.min) / range,
    0.0,
    1.0,
  )
  let knob = @common.min_view_double(self.height, resolved_style.thumb_size)
  let track_height = @common.min_view_double(
    self.height,
    resolved_style.track_height,
  )
  let track_radius = @common.min_view_double(
    track_height / 2.0,
    resolved_style.radius,
  )
  let thumb_shape = set.slider.thumb_shape
  let thumb_radius = match thumb_shape {
    @style.ThumbShape::Circle => knob / 2.0
    @style.ThumbShape::Rounded =>
      @common.min_view_double(knob / 2.0, resolved_style.radius)
  }
  let foreground_color = @common.resolve_control_color(
    self.foreground,
    resolved_style.foreground,
  )
  let track_background = @common.resolve_control_color(
    self.background,
    resolved_style.background,
  )
  let thumb_color = @common.resolve_control_color(
    self.foreground,
    resolved_style.thumb_color,
  )
  let frame = ctx.frame
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
    normalized * @common.max_view_double(0.0, frame.size.width - thumb_size)
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
}

///|
impl @core.ViewNode for Slider with fn focusable(_self) {
  true
}

///|
impl @core.ViewNode for Slider with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Slider,
    label=self.label,
    value="\{self.value}",
    numeric=@core.SemanticsNumericValue::new(
      current=self.value,
      min=self.min,
      max=self.max,
      step=self.step,
      value_text?=self.value_text,
    ),
  )
}

///|
fn slider_value_at(
  frame : @core.Rect,
  local_x : Double,
  min : Double,
  max : Double,
) -> Double {
  let range = if max <= min { 1.0 } else { max - min }
  let track_width = @common.max_view_double(1.0, frame.size.width)
  let clamped = @common.clamp_view_double(local_x, 0.0, track_width)
  @common.clamp_view_double(min + clamped / track_width * range, min, max)
}
