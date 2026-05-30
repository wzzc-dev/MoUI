///|
test "gesture arena resolves highest priority non rejected member" {
  let tap = GestureArenaMember::new(
    element_id=ElementId::new(1),
    kind=GestureKind::Tap,
    priority=1,
  )
  let drag = GestureArenaMember::new(
    element_id=ElementId::new(2),
    kind=GestureKind::Drag,
    priority=4,
  )
  let long_press = GestureArenaMember::new(
    element_id=ElementId::new(3),
    kind=GestureKind::LongPress,
    priority=3,
  )
  long_press.reject()
  let result = resolve_gesture_arena([tap, drag, long_press])
  guard result.winner is Some({ element_id: { value: 2 }, kind: Drag, .. }) else {
    fail("expected drag to win")
  }
  assert_true(
    result.members[0].disposition == GestureArenaDisposition::Rejected,
  )
  assert_true(
    result.members[1].disposition == GestureArenaDisposition::Accepted,
  )
  assert_true(
    result.members[2].disposition == GestureArenaDisposition::Rejected,
  )
}

///|
test "long press recognizer separates tap from held press" {
  let state = LongPressGestureState::new(duration_ms=500.0, max_movement=8.0)
  let pressing = state.update(
    PointerEvent::new(
      position=Point::new(x=10.0, y=10.0),
      phase=PointerPhase::Down,
      time_ms=0.0,
    ),
  )
  assert_false(pressing.recognized)
  let early = pressing.state.update(
    PointerEvent::new(
      position=Point::new(x=10.0, y=10.0),
      phase=PointerPhase::Move,
      time_ms=240.0,
    ),
  )
  assert_false(early.recognized)
  let held = early.state.update(
    PointerEvent::new(
      position=Point::new(x=10.0, y=10.0),
      phase=PointerPhase::Move,
      time_ms=540.0,
    ),
  )
  assert_true(held.recognized)
  inspect(held.state.phase.label(), content="Recognized")
  let tap = LongPressGestureState::new(duration_ms=500.0).update(
    PointerEvent::new(
      position=Point::new(x=10.0, y=10.0),
      phase=PointerPhase::Down,
      time_ms=0.0,
    ),
  ).state.update(
    PointerEvent::new(
      position=Point::new(x=10.0, y=10.0),
      phase=PointerPhase::Up,
      time_ms=120.0,
    ),
  )
  assert_false(tap.recognized)
  assert_true(tap.cancelled)
}

///|
test "double tap recognizer matches nearby taps inside timeout" {
  let first = DoubleTapGestureState::new(timeout_ms=300.0, max_distance=16.0).tap(
    Point::new(x=4.0, y=4.0),
    100.0,
  )
  assert_false(first.recognized)
  let second = first.state.tap(Point::new(x=10.0, y=8.0), 320.0)
  assert_true(second.recognized)
  assert_true(second.state.first_position is None)
  let expired = DoubleTapGestureState::new(timeout_ms=120.0).tap(
    Point::new(x=0.0, y=0.0),
    0.0,
  ).state.tap(Point::new(x=0.0, y=0.0), 200.0)
  assert_false(expired.recognized)
  assert_true(expired.state.first_position is Some(_))
}

///|
test "drag recognizer emits start update and end phases" {
  let down = DragGestureState::new(min_distance=4.0).update(
    PointerEvent::new(
      position=Point::new(x=2.0, y=2.0),
      phase=PointerPhase::Down,
    ),
  )
  assert_true(down.event is None)
  let small = down.state.update(
    PointerEvent::new(
      position=Point::new(x=4.0, y=3.0),
      phase=PointerPhase::Move,
    ),
  )
  assert_true(small.event is None)
  let started = small.state.update(
    PointerEvent::new(
      position=Point::new(x=9.0, y=4.0),
      phase=PointerPhase::Move,
    ),
  )
  guard started.event is Some(start_event) else { fail("expected drag start") }
  inspect(start_event.phase.label(), content="Started")
  inspect(start_event.translation.x, content="7")
  let changed = started.state.update(
    PointerEvent::new(
      position=Point::new(x=12.0, y=9.0),
      phase=PointerPhase::Move,
    ),
  )
  guard changed.event is Some(change_event) else {
    fail("expected drag change")
  }
  inspect(change_event.phase.label(), content="Changed")
  inspect(change_event.delta.y, content="5")
  let ended = changed.state.update(
    PointerEvent::new(
      position=Point::new(x=14.0, y=10.0),
      phase=PointerPhase::Up,
    ),
  )
  guard ended.event is Some(end_event) else { fail("expected drag end") }
  inspect(end_event.phase.label(), content="Ended")
  inspect(end_event.translation.x, content="12")
  inspect(ended.state.phase.label(), content="Idle")
}

///|
test "action commands match enabled shortcuts" {
  let copy = ActionCommand::new(
    intent=CommandIntent::Copy,
    label="Copy",
    group="Edit",
    description="Copy the current selection.",
    shortcut=Some(
      KeyboardShortcut::new(key="c", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  inspect(copy.display_label(), content="Copy")
  inspect(copy.shortcut_label(), content="Meta+c")
  inspect(copy.group, content="Edit")
  inspect(copy.description, content="Copy the current selection.")
  assert_true(
    copy.matches(
      KeyboardEvent::new(key="c", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  assert_false(
    copy.matches(
      KeyboardEvent::new(key="c", modifiers=KeyModifiers::new(control=true)),
    ),
  )
  let disabled = ActionCommand::new(
    intent=CommandIntent::Paste,
    shortcut=Some(
      KeyboardShortcut::new(key="v", modifiers=KeyModifiers::new(meta=true)),
    ),
    enabled=false,
  )
  assert_false(
    disabled.matches(
      KeyboardEvent::new(key="v", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  let defaults = default_text_commands()
  inspect(defaults.length(), content="6")
  assert_true(defaults.any(command => command.intent == CommandIntent::Cut))
  assert_true(defaults.any(command => command.intent == CommandIntent::Undo))
  assert_true(
    defaults.any(command => command.intent == CommandIntent::SelectAll),
  )
  assert_true(defaults.all(command => command.group == "Edit"))
  assert_true(defaults.all(command => command.description != ""))
}

///|
test "action command metadata has stable display fallbacks" {
  let submit = ActionCommand::new(intent=CommandIntent::Submit)
  inspect(submit.display_label(), content="Submit")
  inspect(submit.shortcut_label(), content="")
  let shortcut = KeyboardShortcut::new(
    key="Escape",
    modifiers=KeyModifiers::new(control=true, shift=true),
  )
  inspect(shortcut.display_label(), content="Ctrl+Shift+Esc")
  inspect(
    CommandIntent::OpenContextMenu.display_label(),
    content="Open Context Menu",
  )
}

///|
test "action command map dispatches shortcuts and intents" {
  let copied = Ref(0)
  let pasted = Ref(0)
  let map = ActionCommandMap::new(bindings=[
    CommandBinding::new(
      command=ActionCommand::new(
        intent=CommandIntent::Copy,
        label="Copy",
        shortcut=Some(
          KeyboardShortcut::new(key="c", modifiers=KeyModifiers::new(meta=true)),
        ),
      ),
      handle=() => copied.val = copied.val + 1,
    ),
    CommandBinding::new(
      command=ActionCommand::new(
        intent=CommandIntent::Paste,
        label="Paste",
        enabled=false,
      ),
      handle=() => pasted.val = pasted.val + 1,
    ),
  ])
  match
    map.find_shortcut(
      KeyboardEvent::new(key="c", modifiers=KeyModifiers::new(meta=true)),
    ) {
    Some({ intent: CommandIntent::Copy, .. }) => ()
    _ => fail("expected copy shortcut")
  }
  match
    map.dispatch_shortcut(
      KeyboardEvent::new(key="c", modifiers=KeyModifiers::new(meta=true)),
    ) {
    Some(CommandIntent::Copy) => ()
    _ => fail("expected dispatched copy shortcut")
  }
  inspect(copied.val, content="1")
  assert_false(map.dispatch_intent(CommandIntent::Paste))
  inspect(pasted.val, content="0")
  inspect(map.commands().length(), content="2")
}

///|
test "runtime dispatches action command shortcuts before focused text input" {
  let copied = Ref(0)
  let text = State::new("")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: Size::new(width=160.0, height=36.0),
      font: FontSpec::new(size=12.0, weight=400),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: Brush::solid(Color::white()),
      border: None,
      focused_border: None,
      cursor_color: Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=Size::new(width=160.0, height=40.0),
  )
  runtime.set_action_commands(
    ActionCommandMap::new(bindings=[
      CommandBinding::new(
        command=ActionCommand::new(
          intent=CommandIntent::Copy,
          shortcut=Some(
            KeyboardShortcut::new(
              key="c",
              modifiers=KeyModifiers::new(meta=true),
            ),
          ),
        ),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=8.0, y=8.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Keyboard(
      KeyboardEvent::new(key="c", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  inspect(copied.val, content="1")
  inspect(text.get(), content="")
}
