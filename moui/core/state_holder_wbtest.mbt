///|
test "state holders expose mutable app navigation and focus state" {
  let scroll = ScrollState::new(offset=Point::new(x=4.0, y=8.0))
  let focus = FocusState::new()
  let nav = NavigationState::new(initial="overview")
  inspect(scroll.offset().y, content="8")
  focus.focus("title")
  assert_true(focus.focused_key() == Some("title"))
  nav.push("controls")
  assert_true(nav.current() == "controls")
  assert_true(nav.pop())
  assert_true(nav.current() == "overview")
}

///|
test "keyboard shortcuts activate wrapped buttons" {
  let clicks = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Shortcut",
      size: Size::new(width=120.0, height=44.0),
      font: FontSpec::new(size=16.0, weight=600),
      foreground: Color::black(),
      background: Brush::solid(Color::gray()),
      hovered_background: Brush::solid(Color::gray()),
      pressed_background: Brush::solid(Color::blue()),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: Some(() => clicks.val = clicks.val + 1),
    }).keyboard_shortcut(
      KeyboardShortcut::new(key="k", modifiers=KeyModifiers::new(meta=true)),
    ),
    size=Size::new(width=160.0, height=80.0),
  )
  runtime.dispatch_event(
    AppEvent::Keyboard(
      KeyboardEvent::new(key="k", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  inspect(clicks.val, content="1")
}

///|
test "disabled wrapper suppresses pointer activation" {
  let clicks = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Disabled",
      size: Size::new(width=120.0, height=44.0),
      font: FontSpec::new(size=16.0, weight=600),
      foreground: Color::black(),
      background: Brush::solid(Color::gray()),
      hovered_background: Brush::solid(Color::gray()),
      pressed_background: Brush::solid(Color::blue()),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: Some(() => clicks.val = clicks.val + 1),
    }).disabled(),
    size=Size::new(width=160.0, height=80.0),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="0")
}

///|
test "focusable wrapper contributes focus order" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::TextSpec({
      key: None,
      text: "Focusable",
      size: Size::new(width=120.0, height=24.0),
      font: FontSpec::new(size=16.0, weight=400),
      color: Color::black(),
    }).focusable(),
    size=Size::new(width=160.0, height=80.0),
  )
  let semantics = runtime.semantics()
  assert_true(semantics.focus_order == Some(0))
}

///|
test "app runtime exposes explicit focus traversal helpers" {
  let first = State::new("")
  let second = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(first.binding()),
        test_text_field(second.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  assert_true(runtime.focus_next())
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("a")))
  inspect(first.get(), content="a")
  inspect(second.get(), content="")
  assert_true(runtime.focus_next())
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("b")))
  inspect(first.get(), content="a")
  inspect(second.get(), content="b")
  assert_true(runtime.focus_previous())
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("c")))
  inspect(first.get(), content="ac")
  inspect(second.get(), content="b")
}

///|
test "app runtime focus traversal skips disabled controls" {
  let first = State::new("")
  let disabled = State::new("")
  let third = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(first.binding()),
        test_text_field(disabled.binding()).disabled(),
        test_text_field(third.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=180.0),
  )
  assert_true(runtime.focus_next())
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("a")))
  assert_true(runtime.focus_next())
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("b")))
  assert_true(runtime.focus_previous())
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("c")))
  inspect(first.get(), content="ac")
  inspect(disabled.get(), content="")
  inspect(third.get(), content="b")
}

///|
test "focus scope traversal wraps and skips disabled items" {
  let scope = FocusScope::new(current=Some("first"), items=[
    FocusScopeItem::new(id="first"),
    FocusScopeItem::new(id="disabled", enabled=false),
    FocusScopeItem::new(id="third"),
  ])
  inspect(scope.next().unwrap_or(""), content="third")
  let wrapped = FocusScope::new(
    current=Some("third"),
    items=scope.items,
    wrap=true,
  )
  inspect(wrapped.next().unwrap_or(""), content="first")
  let clamped = FocusScope::new(
    current=Some("third"),
    items=scope.items,
    wrap=false,
  )
  inspect(clamped.next().unwrap_or(""), content="third")
  inspect(clamped.previous().unwrap_or(""), content="first")
}

///|
test "focus scope maps invalid fields and default actions" {
  let scope = FocusScope::new(
    current=Some("name"),
    default_action="submit",
    dismiss_action="close",
    items=[
      FocusScopeItem::new(id="name"),
      FocusScopeItem::new(id="email"),
      FocusScopeItem::new(id="submit", focusable=false),
    ],
  )
  let summary = FormValidationSummary::from_errors([
    { name: "email", message: "Email required" },
  ])
  inspect(scope.focus_first_invalid(summary).unwrap_or(""), content="email")
  inspect(
    scope.command_target(CommandIntent::Submit).unwrap_or(""),
    content="submit",
  )
  inspect(
    scope.command_target(CommandIntent::Cancel).unwrap_or(""),
    content="close",
  )
  match focus_scope_command_intent(KeyboardEvent::new(key="Enter")) {
    Some(Submit) => ()
    _ => fail("expected Enter to map to submit")
  }
  match focus_scope_command_intent(KeyboardEvent::new(key="Escape")) {
    Some(Cancel) => ()
    _ => fail("expected Escape to map to cancel")
  }
}
