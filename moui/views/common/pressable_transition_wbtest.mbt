///|
test "pressable transition wire format is stable" {
  let idle : PressableTransition = Idle
  // Idle encodes to a single zero byte.
  assert_eq(@core.ViewStateValue::encode_view_state(idle), b"\x00")
  // Active encodes to tag 1, the from-state byte, then a big-endian double.
  let encoded = @core.ViewStateValue::encode_view_state(
    Active(@core.PressableState::Pressed, 250.0),
  )
  assert_eq(encoded.length(), 10)
  assert_eq(encoded[0].to_int(), 1)
  assert_eq(encoded[1].to_int(), 2)
  assert_eq(
    @core.ViewStateValue::encode_view_state(
      Active(@core.PressableState::Hovered, 0.0),
    )[1].to_int(),
    1,
  )
  // Decode reverses the encode exactly.
  match @core.ViewStateValue::decode_view_state(idle, encoded) {
    Some(Active(from_state, start_ms)) => {
      assert_eq(from_state, @core.PressableState::Pressed)
      assert_eq(start_ms, 250.0)
    }
    _ => assert_true(false)
  }
  // Corrupt payloads are rejected instead of guessed at: wrong tag, wrong
  // length, and an unknown from-state byte all fail.
  assert_eq(
    @core.ViewStateValue::decode_view_state(
      idle, b"\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    ),
    None,
  )
  assert_eq(
    @core.ViewStateValue::decode_view_state(idle, b"\x01\x00\x00\x00\x00"),
    None,
  )
  assert_eq(
    @core.ViewStateValue::decode_view_state(
      idle, b"\x01\x05\x00\x00\x00\x00\x00\x00\x00\x00",
    ),
    None,
  )
}

///|
test "pressable next state machine" {
  let normal = @core.PressableState::Normal
  let hovered = @core.PressableState::Hovered
  let pressed = @core.PressableState::Pressed
  // Move: hover follows the pointer, press survives only while inside.
  assert_eq(pressable_next_state(normal, true, Move), hovered)
  assert_eq(pressable_next_state(normal, false, Move), normal)
  assert_eq(pressable_next_state(pressed, true, Move), pressed)
  assert_eq(pressable_next_state(pressed, false, Move), normal)
  assert_eq(pressable_next_state(hovered, true, Move), hovered)
  assert_eq(pressable_next_state(hovered, false, Move), normal)
  // Down presses inside only; Up lands on hover inside.
  assert_eq(pressable_next_state(hovered, true, Down), pressed)
  assert_eq(pressable_next_state(hovered, false, Down), normal)
  assert_eq(pressable_next_state(pressed, true, Up), hovered)
  assert_eq(pressable_next_state(pressed, false, Up), normal)
  // Exit and Cancel always reset to rest.
  assert_eq(pressable_next_state(pressed, true, Exit), normal)
  assert_eq(pressable_next_state(hovered, true, Cancel), normal)
}

///|
test "pressable transition slot records start on state change only" {
  let idle : PressableTransition = Idle
  let rest : @core.ViewStateContext = {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
  // A rested control has no transition.
  assert_true(pressable_transition(rest, control="button") is None)
  // Writing the same state records no transition and only refreshes flags.
  assert_eq(
    pressable_state_with_transition(
      rest,
      @core.PressableState::Normal,
      @core.PressableState::Normal,
      100.0,
      control="button",
    ),
    rest,
  )
  // A real change records from_state and start time, and moves the flags.
  let pressed = pressable_state_with_transition(
    rest,
    @core.PressableState::Normal,
    @core.PressableState::Pressed,
    100.0,
    control="button",
  )
  assert_true(pressed.pressed)
  assert_false(pressed.hovered)
  assert_eq(
    pressable_transition(pressed, control="button"),
    Some((@core.PressableState::Normal, 100.0)),
  )
  // Storage is per control: another control's slot is untouched.
  assert_true(pressable_transition(pressed, control="checkbox") is None)
  // The button slot key stays stable across the shared-facility rename:
  // a hand-built slot with the historical key reads what the facility wrote.
  let legacy_button_slot = @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.button.transition"),
    initial=idle,
  )
  match pressed.read_slot(legacy_button_slot) {
    Active(from_state, start_ms) => {
      assert_eq(from_state, @core.PressableState::Normal)
      assert_eq(start_ms, 100.0)
    }
    _ => assert_true(false)
  }
  // The instant-clear path drops the recorded transition.
  let cleared = pressed.without_slot(pressable_transition_slot("button"))
  assert_true(pressable_transition(cleared, control="button") is None)
  // Hover writes set the hovered flag, not the pressed flag.
  let hovered_state = pressable_state_with_transition(
    rest,
    @core.PressableState::Normal,
    @core.PressableState::Hovered,
    50.0,
    control="button",
  )
  assert_true(hovered_state.hovered)
  assert_false(hovered_state.pressed)
  assert_eq(
    pressable_transition(hovered_state, control="button"),
    Some((@core.PressableState::Normal, 50.0)),
  )
}

///|
fn pressable_color_test_context(
  state : @core.ViewStateContext,
  now_ms : Double,
  environment~ : @core.Environment,
) -> @core.ViewPaintContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
    child_frames: [],
    focused: false,
    state,
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
      goal_column: None,
      reveal: None,
    },
    environment,
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms,
  }
}

///|
test "pressable transition color blends mid-flight and snaps under reduced motion" {
  let rest : @core.ViewStateContext = {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
  let normal = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let hovered = @core.Color::rgba(r=0.2, g=0.4, b=0.8, a=1.0)
  let pressed = @core.Color::rgba(r=0.1, g=0.2, b=0.4, a=1.0)
  let environment = @core.Environment::neutral()
  let recorded = pressable_state_with_transition(
    rest,
    @core.PressableState::Normal,
    @core.PressableState::Hovered,
    0.0,
    control="probe",
  )
  let (mid, animating) = pressable_transition_color(
    pressable_color_test_context(recorded, 60.0, environment~),
    control="probe",
    normal~,
    hovered~,
    pressed~,
  )
  assert_true(animating)
  assert_true(mid != normal)
  assert_true(mid != hovered)

  let reduced_environment = environment.with_reduced_motion(true)
  let (snapped, still_animating) = pressable_transition_color(
    pressable_color_test_context(
      recorded,
      60.0,
      environment=reduced_environment,
    ),
    control="probe",
    normal~,
    hovered~,
    pressed~,
  )
  assert_false(still_animating)
  assert_true(snapped == hovered)

  // No recorded transition: paint the terminal color.
  let settled = { ..rest, hovered: true, }
  let (terminal, idle) = pressable_transition_color(
    pressable_color_test_context(settled, 60.0, environment~),
    control="probe",
    normal~,
    hovered~,
    pressed~,
  )
  assert_false(idle)
  assert_true(terminal == hovered)
}

///|
test "pressable transition duration is capped at 150 ms" {
  let rest : @core.ViewStateContext = {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
  let recorded = pressable_state_with_transition(
    rest,
    @core.PressableState::Normal,
    @core.PressableState::Hovered,
    0.0,
    control="slow",
  )
  let base = @core.Theme::neutral()
  let slow_motion = { ..base.motion, fast_ms: 500.0, }
  let slow_environment = @core.Environment::neutral().with_theme(
    base.with_motion(slow_motion),
  )
  let (color, animating) = pressable_transition_color(
    pressable_color_test_context(recorded, 160.0, environment=slow_environment),
    control="slow",
    normal=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    hovered=@core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    pressed=@core.Color::rgba(r=0.5, g=0.0, b=0.0, a=1.0),
  )
  // 500 ms would still be mid-flight at 160 ms; the 150 ms cap means the
  // transition has settled.
  assert_false(animating)
  assert_true(color == @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0))
}
