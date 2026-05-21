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
  inspect(defaults.length(), content="5")
  assert_true(defaults.any(command => command.intent == CommandIntent::Undo))
  assert_true(defaults.any(command => command.intent == CommandIntent::SelectAll))
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
          KeyboardShortcut::new(
            key="c",
            modifiers=KeyModifiers::new(meta=true),
          ),
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
  match map.find_shortcut(
    KeyboardEvent::new(key="c", modifiers=KeyModifiers::new(meta=true)),
  ) {
    Some({ intent: CommandIntent::Copy, .. }) => ()
    _ => fail("expected copy shortcut")
  }
  match map.dispatch_shortcut(
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
      PointerEvent::new(position=Point::new(x=8.0, y=8.0), phase=PointerPhase::Down),
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
