///|
/// 白盒：长按/双击识别器的跨事件状态、slot codec 与 modifier 行为。
/// 这两个识别器必须在 pointer 事件之间保留 origin 与起始时刻，否则
/// `recognized` 永远不可达（历史缺陷）。

///|
fn gesture_test_state() -> ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: ViewStateSlots::empty(),
  }
}

///|
fn gesture_event_context(
  event : AppEvent,
  state~ : ViewStateContext,
  now_ms~ : Double = 0.0,
) -> ViewEventContext {
  {
    frame: Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
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
    text_system: TextSystem::fallback(),
    environment: Environment::neutral(),
    style: ViewStyle::empty(),
    now_ms,
  }
}

///|
fn gesture_point(x : Double, y : Double) -> Point {
  Point::new(x~, y~)
}

///|
fn gesture_pointer(phase : PointerPhase, position : Point) -> AppEvent {
  Pointer(PointerEvent::new(position~, phase~))
}

///|
/// One pointer event applied to a modifier, paired with the committed view
/// state. An ignored result carries no state -- the runtime then keeps the
/// previous record -- so the helper must keep it too, or the test would assert
/// a state transition the production path never performs.
fn gesture_step(
  modifier : AnyModifier[Int32],
  phase : PointerPhase,
  position : Point,
  state~ : ViewStateContext,
  now_ms~ : Double = 0.0,
) -> (ViewStateContext, ViewEventResult[Int32]) {
  let result = (modifier.event)(
    gesture_event_context(gesture_pointer(phase, position), state~, now_ms~),
  )
  let committed = match result.state {
    Some(next) => next
    None => state
  }
  (committed, result)
}

///|
fn gesture_bytes(pieces : Array[Bytes]) -> Bytes {
  let output = Buffer(size_hint=64)
  for piece in pieces {
    output.write_bytes(piece)
  }
  output.to_bytes()
}

///|
test "long-press codec round-trips phases, origin and config" {
  let slot = long_press_gesture_view_state_slot()
  let states : Array[LongPressGestureState] = [
    LongPressGestureState::new(),
    {
      phase: Pressing,
      origin: Some(gesture_point(1.5, -2.25)),
      start_time_ms: 1234.5,
      duration_ms: 350.0,
      max_movement: 12.0,
    },
    {
      phase: Recognized,
      origin: Some(gesture_point(0.0, 0.0)),
      start_time_ms: 0.0,
      duration_ms: 500.0,
      max_movement: 8.0,
    },
  ]
  for state in states {
    // Slot bytes are exactly the fixed-length encoding: 1 phase + 1 origin
    // flag + 2 origin doubles + 3 config/timestamp doubles.
    let bytes = ViewStateValue::encode_view_state(state)
    inspect(bytes.length(), content="42")
    // The record is restored from those bytes on every event, so the round
    // trip has to be byte-faithful, not merely numerically equal.
    let stored = gesture_test_state().with_slot(slot, state)
    let from_slot = ViewStateValue::encode_view_state(stored.read_slot(slot))
    inspect(from_slot == bytes, content="true")
    match ViewStateValue::decode_view_state(state, bytes) {
      Some(decoded) =>
        inspect(
          ViewStateValue::encode_view_state(decoded) == bytes,
          content="true",
        )
      None => fail("a well-formed payload must decode")
    }
  }
  // A -0.0 timestamp must not silently round-trip as +0.0.
  let signed_zero = {
    phase: LongPressGesturePhase::Idle,
    origin: None,
    start_time_ms: -0.0,
    duration_ms: 500.0,
    max_movement: 8.0,
  }
  let decoded = gesture_test_state()
    .with_slot(slot, signed_zero)
    .read_slot(slot)
  let bits = decoded.start_time_ms.reinterpret_as_uint64()
  let negative_zero_bits = (-0.0).reinterpret_as_uint64()
  inspect(bits == negative_zero_bits, content="true")
}

///|
test "long-press codec rejects malformed payloads" {
  let witness = LongPressGestureState::new()
  let valid = ViewStateValue::encode_view_state(witness)
  assert_true(
    ViewStateValue::decode_view_state(witness, valid[:41].to_owned()) is None,
  )
  assert_true(
    ViewStateValue::decode_view_state(witness, gesture_bytes([valid, b"\x00"]))
    is None,
  )
  // Unknown phase tag.
  assert_true(
    ViewStateValue::decode_view_state(
      witness,
      gesture_bytes([b"\x03", valid[1:].to_owned()]),
    )
    is None,
  )
  // Origin presence flag outside 0/1.
  assert_true(
    ViewStateValue::decode_view_state(
      witness,
      gesture_bytes([valid[:1].to_owned(), b"\x07", valid[2:].to_owned()]),
    )
    is None,
  )
}

///|
test "double-tap codec round-trips position and config" {
  let slot = double_tap_gesture_view_state_slot()
  let states : Array[DoubleTapGestureState] = [
    DoubleTapGestureState::new(),
    {
      first_position: Some(gesture_point(9.75, 8.25)),
      first_time_ms: 4096.0,
      timeout_ms: 250.0,
      max_distance: 24.0,
    },
  ]
  for state in states {
    let bytes = ViewStateValue::encode_view_state(state)
    // 1 presence flag + 2 position doubles + 3 config/timestamp doubles.
    inspect(bytes.length(), content="41")
    let stored = gesture_test_state().with_slot(slot, state)
    let from_slot = ViewStateValue::encode_view_state(stored.read_slot(slot))
    inspect(from_slot == bytes, content="true")
    match ViewStateValue::decode_view_state(state, bytes) {
      Some(decoded) =>
        inspect(
          ViewStateValue::encode_view_state(decoded) == bytes,
          content="true",
        )
      None => fail("a well-formed payload must decode")
    }
  }
  let witness = DoubleTapGestureState::new()
  let valid = ViewStateValue::encode_view_state(witness)
  assert_true(
    ViewStateValue::decode_view_state(witness, valid[:40].to_owned()) is None,
  )
  assert_true(
    ViewStateValue::decode_view_state(
      witness,
      gesture_bytes([b"\x07", valid[1:].to_owned()]),
    )
    is None,
  )
}

///|
test "long-press modifier recognizes once the hold duration elapses" {
  let modifier = OnLongPressModifier::{ message: 42, }.to_any_modifier()
  let origin = gesture_point(20.0, 20.0)
  let (down, down_result) = gesture_step(
    modifier,
    Down,
    origin,
    state=gesture_test_state(),
    now_ms=1000.0,
  )
  assert_true(down_result.messages.is_empty())
  // No capture: the following `Up` must keep travelling by hit test, so a
  // press that ends over another control is never mis-routed here.
  assert_true(!down_result.captured)
  assert_true(down != gesture_test_state())
  let (before, before_result) = gesture_step(
    modifier,
    Move,
    origin,
    state=down,
    now_ms=1300.0,
  )
  assert_true(before_result.messages.is_empty())
  assert_true(!before_result.activated)
  let (due, due_result) = gesture_step(
    modifier,
    Move,
    origin,
    state=before,
    now_ms=1501.0,
  )
  assert_eq(due_result.messages, [42])
  assert_true(due_result.activated)
  assert_true(due != gesture_test_state())
  // Already-recognized presses must not fire a second message.
  let (again, again_result) = gesture_step(
    modifier,
    Move,
    origin,
    state=due,
    now_ms=2000.0,
  )
  assert_true(again_result.messages.is_empty())
  let (released, released_result) = gesture_step(
    modifier,
    Up,
    origin,
    state=again,
    now_ms=2100.0,
  )
  assert_true(released_result.messages.is_empty())
  assert_eq(released, gesture_test_state())
}

///|
test "long-press modifier cancels when the pointer leaves the slop" {
  let modifier = OnLongPressModifier::{ message: 42, }.to_any_modifier()
  let origin = gesture_point(20.0, 20.0)
  let (down, _) = gesture_step(
    modifier,
    Down,
    origin,
    state=gesture_test_state(),
  )
  let (moved, moved_result) = gesture_step(
    modifier,
    Move,
    gesture_point(40.0, 20.0),
    state=down,
    now_ms=600.0,
  )
  assert_true(moved_result.messages.is_empty())
  assert_eq(moved, gesture_test_state())
}

///|
test "long-press modifier ignores a press released early" {
  let modifier = OnLongPressModifier::{ message: 42, }.to_any_modifier()
  let origin = gesture_point(20.0, 20.0)
  let (down, _) = gesture_step(
    modifier,
    Down,
    origin,
    state=gesture_test_state(),
  )
  let (up, up_result) = gesture_step(
    modifier,
    Up,
    origin,
    state=down,
    now_ms=120.0,
  )
  assert_true(up_result.messages.is_empty())
  assert_eq(up, gesture_test_state())
}

///|
test "long-press modifier discards a press record left by a lost up" {
  // The leftover `Pressing` came from a press that started long before the
  // horizon; a hover move landing on the stale origin must not fire.
  let stale = gesture_test_state().with_slot(
    long_press_gesture_view_state_slot(),
    {
      phase: Pressing,
      origin: Some(gesture_point(20.0, 20.0)),
      start_time_ms: 0.0,
      duration_ms: 500.0,
      max_movement: 8.0,
    },
  )
  let (settled, result) = gesture_step(
    OnLongPressModifier::{ message: 42, }.to_any_modifier(),
    Move,
    gesture_point(20.0, 20.0),
    state=stale,
    now_ms=30000.0,
  )
  assert_true(result.messages.is_empty())
  assert_eq(settled, gesture_test_state())
}

///|
test "double-tap modifier recognizes the second press-down in the window" {
  let modifier = OnDoubleTapModifier::{ message: 42, }.to_any_modifier()
  let origin = gesture_point(20.0, 20.0)
  let (first, first_result) = gesture_step(
    modifier,
    Down,
    origin,
    state=gesture_test_state(),
  )
  assert_true(first_result.messages.is_empty())
  // Arming happens on `Down`, not `Up`: a child tap modifier activates on the
  // second `Up` and an activated child short-circuits its ancestors.
  assert_true(first != gesture_test_state())
  let (up, up_result) = gesture_step(
    modifier,
    Up,
    origin,
    state=first,
    now_ms=80.0,
  )
  assert_true(up_result.messages.is_empty())
  assert_true(up != gesture_test_state())
  let (second, second_result) = gesture_step(
    modifier,
    Down,
    origin,
    state=up,
    now_ms=180.0,
  )
  assert_eq(second_result.messages, [42])
  assert_true(!second_result.captured)
  assert_eq(second, gesture_test_state())
}

///|
test "double-tap modifier re-arms instead of recognizing when the window fails" {
  let modifier = OnDoubleTapModifier::{ message: 42, }.to_any_modifier()
  let origin = gesture_point(20.0, 20.0)
  let (first, _) = gesture_step(
    modifier,
    Down,
    origin,
    state=gesture_test_state(),
  )
  let (too_slow, too_slow_result) = gesture_step(
    modifier,
    Down,
    origin,
    state=first,
    now_ms=400.0,
  )
  assert_true(too_slow_result.messages.is_empty())
  let re_armed = too_slow.read_slot(double_tap_gesture_view_state_slot())
  assert_eq(re_armed.first_position, Some(origin))
  inspect(re_armed.first_time_ms, content="400")
  inspect(re_armed.timeout_ms, content="300")
  inspect(re_armed.max_distance, content="18")
  let (too_far, too_far_result) = gesture_step(
    modifier,
    Down,
    gesture_point(80.0, 80.0),
    state=first,
    now_ms=100.0,
  )
  assert_true(too_far_result.messages.is_empty())
  let re_placed = too_far.read_slot(double_tap_gesture_view_state_slot())
  assert_eq(re_placed.first_position, Some(gesture_point(80.0, 80.0)))
  inspect(re_placed.first_time_ms, content="100")
}

///|
test "double-tap modifier drops the pending record on cancel" {
  let modifier = OnDoubleTapModifier::{ message: 42, }.to_any_modifier()
  let origin = gesture_point(20.0, 20.0)
  let (first, _) = gesture_step(
    modifier,
    Down,
    origin,
    state=gesture_test_state(),
  )
  let (cancelled, _) = gesture_step(
    modifier,
    Cancel,
    origin,
    state=first,
    now_ms=60.0,
  )
  assert_eq(cancelled, gesture_test_state())
}

///|
test "gesture slots are typed and independent per element" {
  let long_press = gesture_test_state().with_slot(
    long_press_gesture_view_state_slot(),
    LongPressGestureState::new(duration_ms=250.0),
  )
  let double_tap = long_press.with_slot(
    double_tap_gesture_view_state_slot(),
    DoubleTapGestureState::new(timeout_ms=200.0),
  )
  assert_eq(
    double_tap.read_slot(long_press_gesture_view_state_slot()).duration_ms,
    250.0,
  )
  assert_eq(
    double_tap.read_slot(double_tap_gesture_view_state_slot()).timeout_ms,
    200.0,
  )
  // Reading the other modifier's slot from the same element yields its initial
  // value, not the neighbouring record's bytes.
  let untouched = long_press.read_slot(double_tap_gesture_view_state_slot())
  assert_true(untouched.first_position is None)
  inspect(untouched.timeout_ms, content="300")
  inspect(untouched.max_distance, content="18")
}
