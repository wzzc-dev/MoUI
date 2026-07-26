///|
/// Concrete view node for the `slider` control.
///
/// Carries only immutable declaration data: value, range, geometry, theme,
/// optional style, and optional foreground/background overrides. The node is
/// message-independent; `View::from_node` wires the typed `on_change` event
/// adapter. The `revision` deliberately captures every paint-affecting field
/// (value, range, geometry, theme, style, colors) so the runtime reconcile
/// path does not reuse a stale RenderNode when only the colors changed.
///
/// The slider owns its pointer interaction directly: the event adapter
/// handles `Pointer` phases (`Down`/`Move`/`Up`) inside the rendered frame,
/// requests focus + capture on `Down`, and maps the pointer x to a clamped
/// `value` via `on_change`. This replaces the previous `on_drag_with_frame`
/// modifier wiring, which had two problems: (1) the slider had no focus/event
/// ownership of its own, and (2) the drag modifier also produced Button
/// semantics. The slider node reports `Slider` semantics directly and is the
/// sole owner of the pointer interaction.
priv struct Slider {
  value : Double
  min : Double
  max : Double
  width : Double
  height : Double
  theme : @core.Theme?
  style : SliderStyle?
  foreground : @core.Color?
  background : @core.Color?
}

///|
impl @core.ViewNode for Slider with fn identity(_self) {
  @core.ViewIdentity::new(kind="Slider")
}

///|
impl @core.ViewNode for Slider with fn revision(self) {
  // The previous revision only captured value/width/height/theme; range,
  // style, foreground, and background overrides were painted from closures
  // but did not flow into the revision. That meant the runtime could judge
  // the node clean and reuse a stale RenderNode when only the colors (or the
  // min/max range) changed. Fold every paint-affecting field into the
  // revision so reconcile is honest.
  let theme_token = match self.theme {
    Some(theme) => theme.revision_fingerprint()
    None => "context"
  }
  let style_token = match self.style {
    Some(style) =>
      "\{round4(style.foreground.r)},\{round4(style.foreground.g)},\{round4(style.foreground.b)},\{round4(style.foreground.a)}:\{round4(style.background.r)},\{round4(style.background.g)},\{round4(style.background.b)},\{round4(style.background.a)}:\{round4(style.thumb_color.r)},\{round4(style.thumb_color.g)},\{round4(style.thumb_color.b)},\{round4(style.thumb_color.a)}:\{style.track_height}:\{style.thumb_size}:\{style.radius}"
    None => "default"
  }
  let foreground_token = match self.foreground {
    Some(color) => "\{round4(color.r)},\{round4(color.g)},\{round4(color.b)},\{round4(color.a)}"
    None => "auto"
  }
  let background_token = match self.background {
    Some(color) => "\{round4(color.r)},\{round4(color.g)},\{round4(color.b)},\{round4(color.a)}"
    None => "auto"
  }
  "slider:\{self.value}:\{self.min}:\{self.max}:\{self.width}:\{self.height}:\{theme_token}:\{style_token}:\{foreground_token}:\{background_token}"
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
  // Resolve the slider style ambient-ly so the track/thumb track
  // dark-mode / palette / thumb-shape changes without a rebuild.
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => SliderStyle::default(theme=resolved_theme)
  }
  let range = if self.max <= self.min { 1.0 } else { self.max - self.min }
  let normalized = clamp_view_double((self.value - self.min) / range, 0.0, 1.0)
  let knob = min_view_double(self.height, resolved_style.thumb_size)
  let track_height = min_view_double(self.height, resolved_style.track_height)
  let track_radius = min_view_double(track_height / 2.0, resolved_style.radius)
  // Circle thumbs force a full circle (radius = knob/2) regardless of the
  // theme radius; Rounded thumbs respect the resolved radius.
  let thumb_shape = resolved_theme.components.slider.thumb_shape
  let thumb_radius = match thumb_shape {
    @core.ThumbShape::Circle => knob / 2.0
    @core.ThumbShape::Rounded =>
      min_view_double(knob / 2.0, resolved_style.radius)
  }
  let foreground_color = resolve_control_color(
    self.foreground,
    resolved_style.foreground,
  )
  let track_background = resolve_control_color(
    self.background,
    resolved_style.background,
  )
  let thumb_color = resolve_control_color(
    self.foreground,
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
}

///|
impl @core.ViewNode for Slider with fn focusable(_self) {
  true
}

///|
impl @core.ViewNode for Slider with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Slider,
    label="Slider",
    value="\{self.value}",
  )
}

///|
/// Map a pointer x position inside `frame` to the slider's value range,
/// clamped to `[min, max]`. Used by both the drag handler and (in the future)
/// accessibility action handlers.
fn slider_value_at(
  frame : @core.Rect,
  local_x : Double,
  min : Double,
  max : Double,
) -> Double {
  let range = if max <= min { 1.0 } else { max - min }
  let track_width = max_view_double(1.0, frame.size.width)
  let clamped = clamp_view_double(local_x, 0.0, track_width)
  clamp_view_double(min + clamped / track_width * range, min, max)
}

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
  let node = Slider::{
    value,
    min,
    max,
    width,
    height,
    theme,
    style,
    foreground,
    background,
  }
  // The slider owns its pointer interaction directly. On `Down` inside the
  // frame we focus + capture and immediately emit the first `on_change` so
  // the thumb jumps to the press point (matches native slider behavior). On
  // `Move` while captured we emit the new value. On `Up`/`Cancel` we keep
  // the last value. There is no `on_drag_with_frame` modifier wiring — the
  // slider node is the sole owner of the pointer interaction and reports
  // `Slider` semantics directly.
  let event_adapter = match on_change {
    Some(handler) =>
      (
        _node : Slider,
        context : @core.ViewEventContext,
      ) => {
        match context.event {
          @core.AppEvent::Pointer(pointer) =>
            match pointer.phase {
              // Focus is claimed only on press (`Down`) inside the frame, not
              // on hover (`Move`). Native slider semantics: the thumb follows
              // the pointer while dragging, but simply moving the cursor over
              // the track without pressing must not steal focus from whatever
              // owned it (keyboard focus, a sibling field, etc.).
              //
              // `pressed` is written back into state on `Down` and carried
              // through `Move` so the runtime surfaces it to subsequent events
              // — the `Move` branch reads `context.state.pressed` to know the
              // press is still held. `Up`/`Cancel`/`Exit` clear it so a later
              // hover does not keep dragging.
              @core.PointerPhase::Down => {
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
              }
              // `Move` tracks the value while the press is still held
              // (i.e. `pressed` was set by the prior `Down`). It must not
              // claim focus on its own.
              //
              // While pressed the thumb follows the pointer even outside the
              // frame — native slider semantics: drag starts on press, ends on
              // release, and the user can drag past either end without losing
              // the gesture. `slider_value_at` clamps the local x to the track
              // so leaving the frame still produces a meaningful value at the
              // near endpoint. When not pressed, `Move` is a hover and must
              // not steer the value or claim focus.
              @core.PointerPhase::Move => {
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
              }
              // Release / cancel / leave: clear `pressed` so a subsequent hover
              // does not keep dragging. Keep focus so keyboard users can still
              // operate the slider after a press.
              @core.PointerPhase::Up
              | @core.PointerPhase::Cancel
              | @core.PointerPhase::Exit => {
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
            }
          _ => @core.ViewEventResult::ignored()
        }
      }
    None =>
      (
        _node : Slider,
        _context : @core.ViewEventContext,
      ) => @core.ViewEventResult::ignored()
  }
  @core.View::from_node(node, event=event_adapter)
}
