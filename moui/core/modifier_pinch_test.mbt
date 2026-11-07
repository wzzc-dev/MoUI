///|
/// Coverage for the two-finger pinch/rotation recognizer: arming on the
/// second `PointerEvent.id` stream, per-stream movement deltas, the angle
/// wrap across ±π, terminal cleanup, and the modifier identity.

///|
fn pinch_test_leaf() -> @core.View[Unit] {
  @core.View::from_node(ModTestNode::{
    kind: "pinchable",
    size: @core.Size::new(width=300.0, height=300.0),
  })
}

///|
fn pinch_test_context(
  event~ : @core.AppEvent,
  state~ : @core.ViewStateContext = pinch_test_state(),
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=300.0, height=300.0),
    child_frames: [],
    event,
    focused: false,
    state,
    text_control: {
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
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn pinch_test_state(
  slots~ : @core.ViewStateSlots = @core.ViewStateSlots::empty(),
) -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots,
  }
}

///|
fn pinch_test_pointer(
  id~ : Int32,
  x~ : Double,
  y~ : Double,
  phase~ : @core.PointerPhase,
) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~, id~),
  )
}

///|
fn pinch_test_view(
  received~ : Array[@core.PinchGestureEvent],
) -> @core.View[Unit] {
  pinch_test_leaf().on_pinch(event => received.push(event))
}

///|
test "on_pinch modifier identity" {
  let received : Array[@core.PinchGestureEvent] = []
  let view : @core.View[Unit] = pinch_test_view(received~)
  assert_true(view.identity().kind.contains("OnPinch"))
}

///|
test "the second finger arms the gesture with a Started sample" {
  let received : Array[@core.PinchGestureEvent] = []
  let view : @core.View[Unit] = pinch_test_view(received~)
  // The first finger only arms: no sample, state committed.
  let down0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=100.0, y=100.0, phase=Down),
    ),
  )
  assert_true(received.length() == 0)
  assert_true(down0.state.unwrap().slots != pinch_test_state().slots)
  // The second finger lands: Started with identity deltas at the midpoint.
  ignore(
    view.event(
      pinch_test_context(
        event=pinch_test_pointer(id=1, x=200.0, y=100.0, phase=Down),
        state=down0.state.unwrap(),
      ),
    ),
  )
  assert_true(received.length() == 1)
  let started = received[0]
  assert_true(started.phase == Started)
  assert_true(started.scale_delta == 1.0)
  assert_true(started.rotation_delta == 0.0)
  assert_true(started.focus.x == 150.0)
  assert_true(started.focus.y == 100.0)
}

///|
test "either finger's movement emits span and angle deltas" {
  let received : Array[@core.PinchGestureEvent] = []
  let view : @core.View[Unit] = pinch_test_view(received~)
  let down0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=100.0, y=100.0, phase=Down),
    ),
  )
  let down1 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=1, x=200.0, y=100.0, phase=Down),
      state=down0.state.unwrap(),
    ),
  )
  // Finger 1 moves diagonally out: span 100 -> sqrt(2)*100, angle 0 -> π/4.
  let move1 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=1, x=200.0, y=200.0, phase=Move),
      state=down1.state.unwrap(),
    ),
  )
  assert_true(move1.changed)
  assert_true(received.length() == 2)
  let moved = received[1]
  assert_true(moved.phase == Moved)
  assert_true((moved.scale_delta - 1.41421356).abs() < 0.000001)
  assert_true((moved.rotation_delta - @math.PI / 4.0).abs() < 0.000001)
  assert_true(moved.focus.x == 150.0)
  assert_true(moved.focus.y == 150.0)
  // Finger 0 moves instead: the same geometry measured from the other side.
  let move0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=100.0, y=200.0, phase=Move),
      state=move1.state.unwrap(),
    ),
  )
  assert_true(move0.changed)
  assert_true(received.length() == 3)
  let last = received[2]
  assert_true(last.phase == Moved)
  // Span back to 100: the scale ratio folds the previous growth out again.
  assert_true((last.scale_delta - 100.0 / 141.421356).abs() < 0.000001)
}

///|
test "a finger lift ends the gesture and clears the pair" {
  let received : Array[@core.PinchGestureEvent] = []
  let view : @core.View[Unit] = pinch_test_view(received~)
  let down0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=100.0, y=100.0, phase=Down),
    ),
  )
  let down1 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=1, x=200.0, y=100.0, phase=Down),
      state=down0.state.unwrap(),
    ),
  )
  let up = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=110.0, y=100.0, phase=Up),
      state=down1.state.unwrap(),
    ),
  )
  assert_true(up.changed)
  assert_true(received.length() == 2)
  let ended = received[1]
  assert_true(ended.phase == Ended)
  assert_true(ended.scale_delta == 1.0)
  assert_true(ended.rotation_delta == 0.0)
  // The state cleared: a fresh pair arms from scratch with a new Started.
  let fresh0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=5, x=10.0, y=10.0, phase=Down),
      state=up.state.unwrap(),
    ),
  )
  ignore(
    view.event(
      pinch_test_context(
        event=pinch_test_pointer(id=6, x=60.0, y=10.0, phase=Down),
        state=fresh0.state.unwrap(),
      ),
    ),
  )
  assert_true(received.length() == 3)
  assert_true(received[2].phase == Started)
  assert_true(received[2].focus.x == 35.0)
}

///|
test "a third finger never joins and cancel tears down silently" {
  let received : Array[@core.PinchGestureEvent] = []
  let view : @core.View[Unit] = pinch_test_view(received~)
  let down0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=100.0, y=100.0, phase=Down),
    ),
  )
  let down1 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=1, x=200.0, y=100.0, phase=Down),
      state=down0.state.unwrap(),
    ),
  )
  // A third finger: no sample, and the tracked pair is untouched.
  let third = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=2, x=150.0, y=250.0, phase=Down),
      state=down1.state.unwrap(),
    ),
  )
  assert_true(received.length() == 1)
  ignore(third)
  // Cancel tears the recognition down with no Ended sample.
  let cancel = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=100.0, y=100.0, phase=Cancel),
      state=third.state.unwrap(),
    ),
  )
  assert_true(received.length() == 1)
  // The cleared state arms a fresh pair afterwards.
  let fresh_down = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=0.0, y=0.0, phase=Down),
      state=cancel.state.unwrap(),
    ),
  )
  ignore(
    view.event(
      pinch_test_context(
        event=pinch_test_pointer(id=1, x=100.0, y=0.0, phase=Down),
        state=fresh_down.state.unwrap(),
      ),
    ),
  )
  assert_true(received.length() == 2)
  assert_true(received[1].phase == Started)
}

///|
test "rotation deltas wrap across the angle seam" {
  let received : Array[@core.PinchGestureEvent] = []
  let view : @core.View[Unit] = pinch_test_view(received~)
  // Fingers horizontal, angle 0.
  let down0 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=0, x=0.0, y=100.0, phase=Down),
    ),
  )
  let down1 = view.event(
    pinch_test_context(
      event=pinch_test_pointer(id=1, x=100.0, y=100.0, phase=Down),
      state=down0.state.unwrap(),
    ),
  )
  // Step one: finger 1 swings to just under +pi (angle ~ +3.0).
  let move_a = view.event(
    pinch_test_context(
      event=pinch_test_pointer(
        id=1,
        x=100.0 * @math.cos(3.0),
        y=100.0 + 100.0 * @math.sin(3.0),
        phase=Move,
      ),
      state=down1.state.unwrap(),
    ),
  )
  assert_true(received.length() == 2)
  let first_delta = received[1].rotation_delta
  assert_true(first_delta.abs() < @math.PI)
  // Step two: continue counterclockwise to just past -pi (angle ~ -3.0).
  // The raw difference (-6.0) exceeds pi; the wrap folds it to a small
  // positive delta crossing the seam the short way.
  let move_b = view.event(
    pinch_test_context(
      event=pinch_test_pointer(
        id=1,
        x=100.0 * @math.cos(0.0 - 3.0),
        y=100.0 + 100.0 * @math.sin(0.0 - 3.0),
        phase=Move,
      ),
      state=move_a.state.unwrap(),
    ),
  )
  assert_true(received.length() == 3)
  let second_delta = received[2].rotation_delta
  assert_true(second_delta.abs() < @math.PI)
  assert_true(second_delta > 0.0)
  assert_true(second_delta < 0.5)
}
