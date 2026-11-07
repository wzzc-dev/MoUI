///|
/// White-box coverage for the `range_slider`: thumb picking, non-crossing
/// clamps, drag-state survival across rebuilds, and the pure drag mapping.

///|
fn range_test_state(
  pressed~ : Bool = false,
  focused~ : Bool = false,
  slots~ : @core.ViewStateSlots = @core.ViewStateSlots::empty(),
) -> @core.ViewStateContext {
  {
    focused,
    hovered: false,
    pressed,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots,
  }
}

///|
fn range_test_text_control_context() -> @core.TextControlStateContext {
  {
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    goal_column: None,
    reveal: None,
    text_selection_origin: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn range_test_event_context(
  event~ : @core.AppEvent,
  state~ : @core.ViewStateContext = range_test_state(),
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=28.0),
    child_frames: [],
    event,
    focused: false,
    state,
    text_control: range_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn range_test_pointer(
  x~ : Double,
  phase~ : @core.PointerPhase,
) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x~, y=14.0), phase~),
  )
}

///|
fn range_test_slider(received~ : Array[SliderRange]) -> @core.View[Unit] {
  range_slider(
    { start: 0.2, end: 0.8, },
    min=0.0,
    max=1.0,
    on_change=Some(range => received.push(range)),
  )
}

///|
test "a press grabs the nearest thumb and drags it without crossing" {
  let received : Array[SliderRange] = []
  let view : @core.View[Unit] = range_test_slider(received~)
  // Press at x=90 (the upper thumb sits at 80, the lower at 20): the upper
  // thumb takes it and a further drag pushes only the upper bound.
  let down = view.event(
    range_test_event_context(event=range_test_pointer(x=90.0, phase=Down)),
  )
  assert_true(down.changed)
  assert_true(down.captured)
  let drag_move = view.event(
    range_test_event_context(
      event=range_test_pointer(x=97.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  assert_true(drag_move.changed)
  assert_true(received.length() >= 2)
  let dragged = received[received.length() - 1]
  assert_true(dragged.start == 0.2)
  assert_true(dragged.end > 0.8)
  assert_true(dragged.end <= 1.0)
  // Press at x=10: the lower thumb takes it and cannot cross the upper bound.
  let down_low = view.event(
    range_test_event_context(event=range_test_pointer(x=10.0, phase=Down)),
  )
  let drag_low = view.event(
    range_test_event_context(
      event=range_test_pointer(x=95.0, phase=Move),
      state=down_low.state.unwrap(),
    ),
  )
  assert_true(drag_low.changed)
  let low_dragged = received[received.length() - 1]
  assert_true(low_dragged.start <= low_dragged.end)
  // The lower thumb stops at the upper bound instead of crossing it.
  assert_true(low_dragged.start == 0.8)
  assert_true(low_dragged.end == 0.8)
}

///|
test "the drag thumb survives the rebuild through the runtime slot" {
  let received : Array[SliderRange] = []
  let view : @core.View[Unit] = range_test_slider(received~)
  let down = view.event(
    range_test_event_context(event=range_test_pointer(x=90.0, phase=Down)),
  )
  let drag = down.state.unwrap().read_slot(range_slider_drag_slot())
  assert_true(drag.active)
  assert_true(drag.upper)
  // The state the runtime carries into the next event still names the upper
  // thumb, so a Move after the on_change rebuild drags the same one.
  let drag_move = view.event(
    range_test_event_context(
      event=range_test_pointer(x=5.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  assert_true(drag_move.changed)
  let after = received[received.length() - 1]
  assert_true(after.start == 0.2)
  // The upper thumb stops at the lower bound instead of crossing it.
  assert_true(after.end == 0.2)
}

///|
test "release clears the drag state and the press" {
  let received : Array[SliderRange] = []
  let view : @core.View[Unit] = range_test_slider(received~)
  let down = view.event(
    range_test_event_context(event=range_test_pointer(x=90.0, phase=Down)),
  )
  let up = view.event(
    range_test_event_context(
      event=range_test_pointer(x=90.0, phase=Up),
      state=down.state.unwrap(),
    ),
  )
  assert_false(up.state.unwrap().pressed)
  assert_false(up.state.unwrap().read_slot(range_slider_drag_slot()).active)
}

///|
test "the drag mapping clamps to the declared range" {
  let node : RangeSlider = {
    start: 0.4,
    end: 0.6,
    min: 0.0,
    max: 1.0,
    step: 0.1,
    label: "",
    value_text: None,
    width: 100.0,
    height: 28.0,
    theme: None,
    style: None,
    foreground: None,
    background: None,
  }
  let upper_past_end = range_slider_with_drag(node, 2.0, upper=true)
  assert_true(upper_past_end.end == 1.0)
  let lower_past_min = range_slider_with_drag(node, 0.0 - 1.0, upper=false)
  assert_true(lower_past_min.start == 0.0)
  let lower_at_upper = range_slider_with_drag(node, 0.9, upper=false)
  assert_true(lower_at_upper.start == 0.6)
  let upper_at_lower = range_slider_with_drag(node, 0.1, upper=true)
  assert_true(upper_at_lower.end == 0.4)
}

///|
test "a degenerate span renders as a collapsed range, not a crossed one" {
  let (start, end, _min, _max, _step) = range_slider_resolved(
    { start: 0.7, end: 0.3, },
    0.0,
    1.0,
    step=0.1,
  )
  assert_true(start == 0.3)
  assert_true(end == 0.7)
}
