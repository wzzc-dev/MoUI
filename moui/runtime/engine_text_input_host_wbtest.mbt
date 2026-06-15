///|
test "text field selection draws highlight before text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  guard test_selection_highlight_color(commands) is Some(color) else {
    fail("expected selection highlight")
  }
  inspect(color.a, content="0.18")
  assert_true(test_draw_text_frame(commands, "abc") is Some(_))
}

///|
test "text field aligns rendered text with caret origin" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  let commands = runtime.build_draw_commands()
  guard test_draw_text_frame(commands, "abc") is Some(text_frame) else {
    fail("expected left-aligned text field text")
  }
  guard test_text_field_caret_rect(commands) is Some(cursor) else {
    fail("expected focused text field cursor")
  }
  let layout = TextSystem::fallback().measure_text(
    TextLayoutInput::new(
      text="abc",
      font=FontSpec::new(size=16.0, weight=400),
      max_width=text_frame.size.width,
    ),
  )
  assert_true(text_frame.origin.x == 10.0)
  assert_true(
    cursor.origin.x == text_frame.origin.x + layout.caret_positions[3],
  )
}

///|
test "runtime exposes focused text input state for hosts" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  inspect(runtime.focused_text_input().focused, content="false")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  inspect(input.text, content="abc")
  inspect(input.caret, content="2")
  assert_true(input.frame == Rect::new(x=0.0, y=0.0, width=160.0, height=60.0))
  assert_true(input.caret_rect.origin.x > input.frame.origin.x)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}

///|
test "runtime exposes focused searchbar text input state for hosts" {
  let query = State::new("abc")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::SearchBarSpec({
      key: None,
      query: query.binding(),
      placeholder: "Search",
      font: FontSpec::new(size=14.0, weight=400),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: Brush::solid(Color::white()),
      border: None,
      focused_border: None,
      cursor_color: Color::blue(),
      corner_radius: 8.0,
      on_submit: None,
      on_clear: None,
    }),
    size=Size::new(width=240.0, height=44.0),
  )
  inspect(runtime.focused_text_input().focused, content="false")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=40.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  inspect(input.text, content="abc")
  inspect(input.caret, content="3")
  assert_true(input.frame == Rect::new(x=0.0, y=0.0, width=240.0, height=44.0))
  assert_true(input.caret_rect.origin.x > input.frame.origin.x + 32.0)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}

///|
test "buttons participate in focus traversal and keyboard activation" {
  let clicks = Ref(0)
  let value = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        ViewSpec::ButtonSpec({
          key: None,
          text: "Run",
          size: Size::new(width=120.0, height=40.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => clicks.val = clicks.val + 1),
        }),
        test_text_field(value.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  inspect(clicks.val, content="1")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="x", text=Some("x"))))
  inspect(value.get(), content="x")
}
