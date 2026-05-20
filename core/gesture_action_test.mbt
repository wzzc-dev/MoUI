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
test "action commands match enabled shortcuts" {
  let copy = ActionCommand::new(
    intent=CommandIntent::Copy,
    label="Copy",
    shortcut=Some(
      KeyboardShortcut::new(key="c", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
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
  inspect(defaults.length(), content="4")
  assert_true(defaults.any(command => command.intent == CommandIntent::Undo))
}
