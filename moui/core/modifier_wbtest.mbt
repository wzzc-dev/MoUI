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

///|
/// 白盒：OnHoverModifier is a priv struct, so the black-box suite cannot
/// construct it. These tests drive `event` directly with synthetic pointer
/// events and thread the committed state forward exactly as the runtime does
/// between dispatches (the `ViewEventResult.state` of one dispatch is the
/// `state` of the next context), which is what proves the transition logic.
fn hover_test_pointer(x : Double, y : Double, phase : PointerPhase) -> AppEvent {
  Pointer(PointerEvent::new(position=Point::new(x~, y~), phase~))
}

///|
/// Drives one pointer event through the modifier at `context` and returns the
/// result plus the context carrying the committed state, so the next call sees
/// the hover transition the previous one produced.
fn hover_test_step(
  modifier : AnyModifier[Bool],
  context : ViewEventContext,
  event : AppEvent,
) -> (ViewEventResult[Bool], ViewEventContext) {
  let result = (modifier.event)({ ..context, event, })
  let next = match result.state {
    Some(state) => { ..context, state, }
    None => context
  }
  (result, next)
}

///|
test "on_hover fires once on enter, stays quiet on repeated Move, and fires once on leave" {
  let modifier = OnHoverModifier::{ handler: hovered => hovered, }.to_any_modifier()
  assert_true(modifier.identity_kind == "OnHover")
  // Transparent observer: no focus stop, no semantics role, no action.
  assert_true(!modifier.focusable)
  assert_true(modifier.semantics.role == None)
  assert_true(modifier.semantics_actions.is_empty())
  let base = tap_with_frame_test_context(hover_test_pointer(10.0, 5.0, Move))
  // (a) Entering the frame fires the handler exactly once with `true`.
  let (enter, entered) = hover_test_step(
    modifier,
    base,
    hover_test_pointer(10.0, 5.0, Move),
  )
  assert_eq(enter.messages, [true])
  assert_true(enter.changed)
  assert_true(enter.dirty == ViewPaintDirty)
  // An observer owns no gesture and no press state.
  assert_true(!enter.captured)
  assert_true(!enter.activated)
  assert_true(!enter.focused)
  assert_true(entered.state.hovered)
  // (b) The runtime delivers a `Move` for every pointer sample inside the
  // element, so repeated motion inside must not re-fire the handler.
  let mut context = entered
  for _ in 0..<3 {
    let (repeat, next) = hover_test_step(
      modifier,
      context,
      hover_test_pointer(12.0, 6.0, Move),
    )
    assert_true(repeat.messages.is_empty())
    assert_true(!repeat.changed)
    assert_true(repeat.dirty == ViewClean)
    context = next
  }
  // (c) Leaving fires the handler exactly once with `false`. The runtime
  // delivers the leave as a synthetic `Exit` (host backends never emit one),
  // and its position is outside the frame by definition.
  let (leave, left) = hover_test_step(
    modifier,
    context,
    hover_test_pointer(90.0, 5.0, Exit),
  )
  assert_eq(leave.messages, [false])
  assert_true(leave.changed)
  assert_true(leave.dirty == ViewPaintDirty)
  assert_true(!leave.captured)
  assert_true(!left.state.hovered)
  // Repeated leave events stay quiet too.
  let (leave_again, _) = hover_test_step(
    modifier,
    left,
    hover_test_pointer(90.0, 5.0, Exit),
  )
  assert_true(leave_again.messages.is_empty())
  assert_true(leave_again.dirty == ViewClean)
  // (d) Re-entering fires `true` again.
  let (reenter, _) = hover_test_step(
    modifier,
    left,
    hover_test_pointer(10.0, 5.0, Move),
  )
  assert_eq(reenter.messages, [true])
}

///|
test "on_hover ignores non-pointer events and out-of-frame Move" {
  let modifier = OnHoverModifier::{ handler: hovered => hovered, }.to_any_modifier()
  let base = tap_with_frame_test_context(hover_test_pointer(10.0, 5.0, Move))
  // A `Move` that misses the frame does not claim hover.
  let (miss, missed) = hover_test_step(
    modifier,
    base,
    hover_test_pointer(90.0, 5.0, Move),
  )
  assert_true(miss.messages.is_empty())
  assert_true(!missed.state.hovered)
  // Non-pointer events are not hover observations.
  let (keyboard, _) = hover_test_step(
    modifier,
    base,
    Keyboard(KeyboardEvent::new(key="a", pressed=true)),
  )
  assert_true(keyboard.messages.is_empty())
  assert_true(!keyboard.changed)
}

///|
/// A `Cancel` (the host aborted the pointer stream) also ends hover, matching
/// `recognize_press_tap`'s phase mapping.
test "on_hover clears hover on Cancel" {
  let modifier = OnHoverModifier::{ handler: hovered => hovered, }.to_any_modifier()
  let base = tap_with_frame_test_context(hover_test_pointer(10.0, 5.0, Move))
  let (_, hovered) = hover_test_step(
    modifier,
    base,
    hover_test_pointer(10.0, 5.0, Move),
  )
  assert_true(hovered.state.hovered)
  let (cancel, cancelled) = hover_test_step(
    modifier,
    hovered,
    hover_test_pointer(10.0, 5.0, Cancel),
  )
  assert_eq(cancel.messages, [false])
  assert_true(!cancelled.state.hovered)
}

///|
test "on_pointer forwards every phase with child-frame geometry" {
  let modifier = OnPointerModifier::{
    handler: fn(event, frame) {
      let local_x = event.position.x - frame.origin.x
      let local_y = event.position.y - frame.origin.y
      let phase = match event.phase {
        Move => "Move"
        Down => "Down"
        Up => "Up"
        Cancel => "Cancel"
        Exit => "Exit"
      }
      "phase=\{phase} at (\{local_x},\{local_y}) wheel=\{event.wheel_delta.y}"
    },
  }.to_any_modifier()
  assert_true(modifier.identity_kind == "OnPointer")
  assert_true(!modifier.focusable)
  let hover = (modifier.event)(
    tap_with_frame_test_context(
      Pointer(PointerEvent::new(position=Point::new(x=10.0, y=5.0), phase=Move)),
    ),
  )
  assert_eq(hover.messages, ["phase=Move at (10,5) wheel=0"])
  assert_false(hover.captured)
  let down = (modifier.event)(
    tap_with_frame_test_context(
      Pointer(
        PointerEvent::new(
          position=Point::new(x=10.0, y=5.0),
          phase=Down,
          button=0,
        ),
      ),
    ),
  )
  assert_eq(down.messages, ["phase=Down at (10,5) wheel=0"])
  // The raw observer never claims focus; geometry hit-testing focuses the
  // nearest focusable wrapper (e.g. `on_key`) so keyboard events reach it.
  assert_false(down.focused)
  assert_true(down.captured)
  let wheel = (modifier.event)(
    tap_with_frame_test_context(
      Pointer(
        PointerEvent::new(
          position=Point::new(x=10.0, y=5.0),
          phase=Move,
          wheel_delta=Point::new(x=0.0, y=12.0),
        ),
      ),
    ),
  )
  assert_eq(wheel.messages, ["phase=Move at (10,5) wheel=12"])
}

///|
test "on_key forwards only while focused and is focusable" {
  let modifier = OnKeyModifier::{ handler: event => event.key, }.to_any_modifier()
  assert_true(modifier.identity_kind == "OnKey")
  assert_true(modifier.focusable)
  let unfocused = (modifier.event)(
    tap_with_frame_test_context(Keyboard(KeyboardEvent::new(key="a"))),
  )
  assert_true(unfocused.messages.is_empty())
  let focused_context = {
    ..tap_with_frame_test_context(Keyboard(KeyboardEvent::new(key="a"))),
    focused: true,
  }
  let focused = (modifier.event)(focused_context)
  assert_eq(focused.messages, ["a"])
  assert_true(focused.captured)
}

///|
test "on_keyboard_input forwards keyboard and text input on one focusable wrapper" {
  let modifier = OnKeyboardInputModifier::{
    key_handler: event => "key:" + event.key,
    text_input_handler: event => {
      match event {
        InsertText(text) => "text:" + text
        CompositionStart => "composition:start"
        CompositionEnd(text) => "composition:end:" + text
        _ => "other"
      }
    },
  }.to_any_modifier()
  assert_true(modifier.identity_kind == "OnKeyboardInput")
  assert_true(modifier.focusable)
  let unfocused = (modifier.event)(
    tap_with_frame_test_context(Keyboard(KeyboardEvent::new(key="a"))),
  )
  assert_true(unfocused.messages.is_empty())
  let focused = {
    ..tap_with_frame_test_context(Keyboard(KeyboardEvent::new(key="a"))),
    focused: true,
  }
  let key = (modifier.event)(focused)
  assert_eq(key.messages, ["key:a"])
  let text = (modifier.event)({
    ..focused,
    event: TextInput(InsertText("日")),
  })
  assert_eq(text.messages, ["text:日"])
  let start = (modifier.event)({
    ..focused,
    event: TextInput(CompositionStart),
  })
  assert_eq(start.messages, ["composition:start"])
}
