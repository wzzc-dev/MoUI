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
    has_on_change: on_change is Some(_),
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
      (_node : Slider, context : @core.ViewEventContext) => {
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
              // Release / cancel / leave: clear `pressed` so a subsequent hover
              // does not keep dragging. Keep focus so keyboard users can still
              // operate the slider after a press.
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
          @core.ViewSemanticsActionHandler::scroll((_ctx, direction) => {
            let step = (node.max - node.min) / 10.0
            let delta = match direction {
              @core.SemanticsScrollDirection::Forward
              | @core.SemanticsScrollDirection::Up
              | @core.SemanticsScrollDirection::Right => step
              @core.SemanticsScrollDirection::Backward
              | @core.SemanticsScrollDirection::Down
              | @core.SemanticsScrollDirection::Left => -step
            }
            let next = clamp_view_double(node.value + delta, node.min, node.max)
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
