///|
/// The two bounds of a `range_slider` selection, with `start <= end`.
#derive(Eq, Debug)
pub(all) struct SliderRange {
  start : Double
  end : Double
}

///|
pub extend SliderRange with Debug::{to_repr}

///|
pub extend SliderRange with Eq::{not_equal, equal}

///|
/// Transient per-element state for a range-slider drag: which thumb the
/// pointer is holding. Runtime-owned, exactly like the scroll container's
/// drag state, so it survives the rebuild a drag's `on_change` triggers.
priv struct RangeSliderDrag {
  active : Bool
  upper : Bool
}

///|
impl @core.ViewStateValue for RangeSliderDrag with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.RangeSliderDrag.v1")
}

///|
impl @core.ViewStateValue for RangeSliderDrag with fn encode_view_state(self) {
  let output = Buffer(size_hint=2)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_byte(if self.upper { 1 } else { 0 })
  output.to_bytes()
}

///|
impl @core.ViewStateValue for RangeSliderDrag with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 2 {
    None
  } else {
    match (bytes[0], bytes[1]) {
      (0, 0) => Some({ active: false, upper: false, })
      (1, 0) => Some({ active: true, upper: false, })
      (1, 1) => Some({ active: true, upper: true, })
      _ => None
    }
  }
}

///|
fn range_slider_drag_slot() -> @core.ViewStateSlot[RangeSliderDrag] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.range_slider.drag"),
    initial={ active: false, upper: false, },
  )
}

///|
/// Concrete view node for the `range_slider` control: one track, two thumbs,
/// a highlighted span between them.
priv struct RangeSlider {
  start : Double
  end : Double
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
}

///|
fn range_slider_resolved(
  values : SliderRange,
  min : Double,
  max : Double,
  step? : Double,
) -> (Double, Double, Double, Double, Double) {
  let resolved_max = if max <= min { min + 1.0 } else { max }
  let resolved_range = resolved_max - min
  let resolved_step = match step {
    Some(value) => if value > 0.0 { value } else { resolved_range / 10.0 }
    None => resolved_range / 10.0
  }
  // A degenerate span still renders: the thumbs collapse onto one point
  // rather than crossing.
  let start = @common.clamp_view_double(
    @common.view_min_double(values.start, values.end),
    min,
    resolved_max,
  )
  let end = @common.clamp_view_double(
    @common.view_max_double(values.start, values.end),
    min,
    resolved_max,
  )
  (start, end, min, resolved_max, resolved_step)
}

///|
pub fn[Msg] range_slider(
  values : SliderRange,
  min~ : Double = 0.0,
  max~ : Double = 1.0,
  step? : Double,
  label~ : String = "",
  value_text? : String,
  width~ : Double = 180.0,
  height~ : Double = 28.0,
  theme? : @core.Theme,
  style? : @style.SliderStyle,
  foreground? : @core.Color,
  background? : @core.Color,
  on_change~ : ((SliderRange) -> Msg)? = None,
) -> @core.View[Msg] {
  let (start, end, resolved_min, resolved_max, resolved_step) = range_slider_resolved(
    values,
    min,
    max,
    step?,
  )
  let node = RangeSlider::{
    start,
    end,
    min: resolved_min,
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
  }
  let event_adapter = match on_change {
    Some(handler) =>
      (node : RangeSlider, context : @core.ViewEventContext) => {
        match context.event {
          // Primary button only: secondary presses belong to context menus.
          Pointer(pointer) if pointer.button == 0 =>
            match pointer.phase {
              Down =>
                if context.frame.contains(pointer.position) {
                  let local_x = pointer.position.x - context.frame.origin.x
                  let value_at = slider_value_at(
                    context.frame,
                    local_x,
                    node.min,
                    node.max,
                  )
                  // The nearest thumb takes the press; a tie goes to the
                  // upper bound so an edge-to-edge drag grows the span.
                  let upper = (value_at - node.end).abs() <=
                    (value_at - node.start).abs()
                  let next = range_slider_with_drag(node, value_at, upper~)
                  {
                    ..@core.ViewEventResult::message(handler(next)),
                    focused: true,
                    captured: true,
                    state: Some({
                      ..context.state.with_slot(range_slider_drag_slot(), {
                        active: true,
                        upper,
                      }),
                      focused: true,
                      pressed: true,
                    }),
                    dirty: ViewPaintDirty,
                  }
                } else {
                  @core.ViewEventResult::ignored()
                }
              Move =>
                if context.state.pressed {
                  let upper = context.state.read_slot(range_slider_drag_slot()).upper
                  let local_x = pointer.position.x - context.frame.origin.x
                  let value_at = slider_value_at(
                    context.frame,
                    local_x,
                    node.min,
                    node.max,
                  )
                  let next = range_slider_with_drag(node, value_at, upper~)
                  {
                    ..@core.ViewEventResult::message(handler(next)),
                    captured: true,
                    state: Some({ ..context.state, pressed: true, }),
                    dirty: ViewPaintDirty,
                  }
                } else {
                  @core.ViewEventResult::ignored()
                }
              Up | Cancel | Exit =>
                if context.state.pressed {
                  {
                    ..@core.ViewEventResult::ignored(),
                    state: Some({
                      ..context.state.without_slot(range_slider_drag_slot()),
                      pressed: false,
                    }),
                    dirty: ViewPaintDirty,
                  }
                } else {
                  @core.ViewEventResult::ignored()
                }
            }
          _ => @core.ViewEventResult::ignored()
        }
      }
    None =>
      (_node : RangeSlider, _context : @core.ViewEventContext) => {
        @core.ViewEventResult::ignored()
      }
  }
  @core.View::from_node(node, event=event_adapter, semantics_actions=node => {
    match on_change {
      Some(handler) =>
        [
          // Range semantics act on the reported (start) bound; a per-bound
          // numeric surface is the documented follow-up.
          @core.ViewSemanticsActionHandler::increment(_ctx => {
            let next = @common.clamp_view_double(
              node.start + node.step,
              node.min,
              node.end,
            )
            if next == node.start {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(
                handler({ start: next, end: node.end, }),
              )
            }
          }),
          @core.ViewSemanticsActionHandler::decrement(_ctx => {
            let next = @common.clamp_view_double(
              node.start - node.step,
              node.min,
              node.end,
            )
            if next == node.start {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(
                handler({ start: next, end: node.end, }),
              )
            }
          }),
          @core.ViewSemanticsActionHandler::set_numeric_value((_ctx, value) => {
            let next = @common.clamp_view_double(value, node.min, node.end)
            if next == node.start {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(
                handler({ start: next, end: node.end, }),
              )
            }
          }),
          @core.ViewSemanticsActionHandler::scroll((_ctx, direction) => {
            let delta = match direction {
              Forward | Up | Right => node.step
              Backward | Down | Left => 0.0 - node.step
            }
            let next = @common.clamp_view_double(
              node.start + delta,
              node.min,
              node.end,
            )
            if next == node.start {
              @core.ViewSemanticsActionResult::rejected()
            } else {
              @core.ViewSemanticsActionResult::message(
                handler({ start: next, end: node.end, }),
              )
            }
          }),
        ]
      None => []
    }
  })
}

///|
/// The span after moving the held thumb to `value_at`, clamped so the bounds
/// never cross: a dragged lower thumb stops at the upper one and vice versa.
fn range_slider_with_drag(
  node : RangeSlider,
  value_at : Double,
  upper~ : Bool,
) -> SliderRange {
  if upper {
    {
      start: node.start,
      end: @common.clamp_view_double(value_at, node.start, node.max),
    }
  } else {
    {
      start: @common.clamp_view_double(value_at, node.min, node.end),
      end: node.end,
    }
  }
}

///|
impl @core.ViewNode for RangeSlider with fn identity(_self) {
  @core.ViewIdentity::new(kind="RangeSlider")
}

///|
impl @core.ViewNode for RangeSlider with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for RangeSlider with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let set = @style.views_ambient_control_theme(resolved_theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => {
      let s = set.slider
      {
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
  let normalized_start = @common.clamp_view_double(
    (self.start - self.min) / range,
    0.0,
    1.0,
  )
  let normalized_end = @common.clamp_view_double(
    (self.end - self.min) / range,
    0.0,
    1.0,
  )
  let knob = @common.view_min_double(self.height, resolved_style.thumb_size)
  let track_height = @common.view_min_double(
    self.height,
    resolved_style.track_height,
  )
  let track_radius = @common.view_min_double(
    track_height / 2.0,
    resolved_style.radius,
  )
  let thumb_shape = set.slider.thumb_shape
  let thumb_radius = match thumb_shape {
    Circle => knob / 2.0
    Rounded => @common.view_min_double(knob / 2.0, resolved_style.radius)
  }
  let foreground_color = self.foreground.unwrap_or(resolved_style.foreground)
  let track_background = self.background.unwrap_or(resolved_style.background)
  let thumb_color = self.foreground.unwrap_or(resolved_style.thumb_color)
  let frame = ctx.frame
  let focused = ctx.focused
  let thumb_size = knob + (if focused { 3.0 } else { 0.0 })
  let ring_color = match resolved_theme.scheme {
    Light => @core.Color::white().with_alpha(0.92)
    Dark => resolved_theme.palette.foreground.with_alpha(0.18)
  }
  let ring_width = 2.0
  let track = @core.Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + (frame.size.height - track_height) / 2.0,
    width=frame.size.width,
    height=track_height,
  )
  let track_travel = @common.view_max_double(0.0, frame.size.width - thumb_size)
  let start_x = frame.origin.x + normalized_start * track_travel
  let end_x = frame.origin.x + normalized_end * track_travel
  let thumb_rect_at = x => {
    @core.RoundedRect::new(
      rect=@core.Rect::new(
        x~,
        y=frame.origin.y + (frame.size.height - thumb_size) / 2.0,
        width=thumb_size,
        height=thumb_size,
      ),
      radius=thumb_radius,
    )
  }
  @core.ViewPaintPlan::commands([
    FillRoundedRectBrush(
      @core.RoundedRect::new(rect=track, radius=track_radius),
      @core.Brush::solid(track_background),
    ),
    // The selected span sits between the thumbs.
    FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(
          x=track.origin.x + track.size.width * normalized_start,
          y=track.origin.y,
          width=track.size.width * (normalized_end - normalized_start),
          height=track.size.height,
        ),
        radius=track_radius,
      ),
      @core.Brush::solid(foreground_color),
    ),
    FillRoundedRectBrush(
      thumb_rect_at(start_x),
      @core.Brush::solid(thumb_color),
    ),
    FillRoundedRectBrush(thumb_rect_at(end_x), @core.Brush::solid(thumb_color)),
    StrokeRoundedRectBrush(
      thumb_rect_at(start_x),
      @core.Brush::solid(ring_color),
      ring_width,
    ),
    StrokeRoundedRectBrush(
      thumb_rect_at(end_x),
      @core.Brush::solid(ring_color),
      ring_width,
    ),
  ])
}

///|
impl @core.ViewNode for RangeSlider with fn focusable(_self) {
  true
}

///|
impl @core.ViewNode for RangeSlider with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(
    role=Slider,
    label=self.label,
    value="\{self.start} – \{self.end}",
    numeric=@core.SemanticsNumericValue::new(
      current=self.start,
      min=self.min,
      max=self.max,
      step=self.step,
      value_text?=self.value_text,
    ),
  )
}
