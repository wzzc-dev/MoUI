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
  let runtime = AppRuntime::new_spec(
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
  let runtime = AppRuntime::new_spec(
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
  let runtime = AppRuntime::new_spec(
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
