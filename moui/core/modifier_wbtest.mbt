///|
/// 白盒：OnTapWithFrameModifier 是 priv 结构体，黑盒测试无法构造。

///|
fn tap_with_frame_test_context(event : AppEvent) -> ViewEventContext {
  {
    frame: Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
    child_frames: [],
    event,
    focused: false,
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: ViewStateSlots::empty(),
    },
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    },
    text_system: TextSystem::fallback(),
    environment: Environment::neutral(),
    style: ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
test "on_tap_with_frame fires on plain click with local hit geometry" {
  // A drag recognizer swallows plain clicks (no event crosses the slop);
  // on_tap_with_frame exists so canvas surfaces can hit-test clicks.
  let modifier = OnTapWithFrameModifier::{
    handler: fn(position, frame) {
      "tap@(\{position.x - frame.origin.x},\{position.y - frame.origin.y})"
    },
  }.to_any_modifier()
  assert_true(modifier.identity_kind == "OnTapWithFrame")
  // Transparent observer: no focus stop, no semantics role override.
  assert_true(!modifier.focusable)
  assert_true(modifier.semantics.role == None)
  // Down then Up inside the frame: a plain click activates the tap. The
  // committed view state threads from the Down result into the Up context,
  // exactly as the runtime does between event dispatches.
  let down = (modifier.event)(
    tap_with_frame_test_context(
      Pointer(PointerEvent::new(position=Point::new(x=10.0, y=5.0), phase=Down)),
    ),
  )
  assert_true(down.messages.is_empty())
  let up_context = match down.state {
    Some(state) => {
      let base = tap_with_frame_test_context(
        Pointer(PointerEvent::new(position=Point::new(x=10.0, y=5.0), phase=Up)),
      )
      { ..base, state, }
    }
    None => fail("down must commit pressable state")
  }
  let up = (modifier.event)(up_context)
  assert_eq(up.messages, ["tap@(10,5)"])
  // Press outside the frame never arms the tap; release outside never fires.
  let outside_down = (modifier.event)(
    tap_with_frame_test_context(
      Pointer(PointerEvent::new(position=Point::new(x=90.0, y=5.0), phase=Down)),
    ),
  )
  assert_true(outside_down.messages.is_empty())
  let outside_up = (modifier.event)(
    tap_with_frame_test_context(
      Pointer(PointerEvent::new(position=Point::new(x=90.0, y=5.0), phase=Up)),
    ),
  )
  assert_true(outside_up.messages.is_empty())
}
