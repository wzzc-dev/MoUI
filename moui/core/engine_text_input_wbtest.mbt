///|
test "text input events edit at caret and support delete ranges" {
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(TextInput(InsertText("Z")))
  inspect(state.get(), content="abZc")
  runtime.dispatch_event(TextInput(DeleteRange(TextRange::new(start=1, end=2))))
  inspect(state.get(), content="aZc")
}

///|
test "text field keyboard selection replaces and deletes ranges" {
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
  runtime.dispatch_event(TextInput(InsertText("abcd")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
  match input.selection {
    Some(selection) => {
      inspect(selection.normalized().start, content="2")
      inspect(selection.normalized().end, content="4")
    }
    None => fail("expected selection")
  }
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abX")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="End", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="")
}

///|
test "text field select all shortcut replaces unicode text" {
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
  runtime.dispatch_event(TextInput(InsertText("你好abc")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="5")
  match input.selection {
    Some(selection) => {
      inspect(selection.normalized().start, content="0")
      inspect(selection.normalized().end, content="5")
    }
    None => fail("expected select all range")
  }
  runtime.dispatch_event(TextInput(InsertText("done")))
  inspect(state.get(), content="done")
}

///|
test "text field command undo and redo restore edit history" {
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
  runtime.dispatch_event(TextInput(InsertText("a")))
  runtime.dispatch_event(TextInput(InsertText("b")))
  inspect(state.get(), content="ab")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(state.get(), content="a")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(state.get(), content="ab")
}

///|
test "text field undo and redo restore edit caret" {
  let state = State::new("abcd")
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abXcd")
  inspect(runtime.focused_text_input().caret, content="3")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(state.get(), content="abcd")
  inspect(runtime.focused_text_input().caret, content="2")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(state.get(), content="abXcd")
  inspect(runtime.focused_text_input().caret, content="3")
}

///|
test "text field can undo multiple edits without replaying restored states" {
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
  runtime.dispatch_event(TextInput(InsertText("a")))
  runtime.dispatch_event(TextInput(InsertText("b")))
  runtime.dispatch_event(TextInput(InsertText("c")))
  inspect(state.get(), content="abc")
  ignore(runtime.dispatch_focused_text_command(Undo))
  inspect(state.get(), content="ab")
  ignore(runtime.dispatch_focused_text_command(Undo))
  inspect(state.get(), content="a")
  ignore(runtime.dispatch_focused_text_command(Undo))
  inspect(state.get(), content="")
  ignore(runtime.dispatch_focused_text_command(Redo))
  inspect(state.get(), content="a")
  ignore(runtime.dispatch_focused_text_command(Redo))
  inspect(state.get(), content="ab")
  ignore(runtime.dispatch_focused_text_command(Redo))
  inspect(state.get(), content="abc")
}

///|
test "text field undo restores previous selection" {
  let state = State::new("abcd")
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
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("done")))
  inspect(state.get(), content="done")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  inspect(state.get(), content="abcd")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="4")
  guard input.selection is Some(selection) else {
    fail("expected restored selection")
  }
  inspect(selection.normalized().start, content="0")
  inspect(selection.normalized().end, content="4")
}

///|
test "text field keyboard undo and redo use edit history" {
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
  runtime.dispatch_event(TextInput(InsertText("ab")))
  runtime.dispatch_event(TextInput(InsertText("c")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="z", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  inspect(state.get(), content="ab")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="z",
        modifiers=KeyModifiers::new(shift=true, meta=true),
      ),
    ),
  )
  inspect(state.get(), content="abc")
}

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
test "ime composition updates paint preview and commit into text field" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(CompositionUpdate(CompositionUpdate::new(text="ni", cursor=None))),
  )
  let preview = runtime.build_draw_commands()
  guard preview[3] is DrawText({ text: "ni", align: TextAlign::TextStart, .. }) else {
    fail("expected composition preview")
  }
  inspect(state.get(), content="")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="你")
  let committed = runtime.build_draw_commands()
  guard committed[3]
    is DrawText({ text: "你", align: TextAlign::TextStart, .. }) else {
    fail("expected committed text")
  }
}

///|
test "ime composition replaces selected text and undo restores selection edit" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abcd")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(CompositionUpdate::new(text="你", cursor=None)),
    ),
  )
  inspect(state.get(), content="abcd")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="ab你")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  inspect(state.get(), content="abcd")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  inspect(state.get(), content="ab你")
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
test "text field caret follows ime composition cursor" {
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
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="ni",
          cursor=Some(TextRange::new(start=1, end=1)),
        ),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  guard test_text_field_caret_rect(commands) is Some(cursor) else {
    fail("expected focused text field cursor")
  }
  let layout = TextSystem::fallback().measure_text(
    TextLayoutInput::new(
      text="ni",
      font=FontSpec::new(size=16.0, weight=400),
      max_width=140.0,
    ),
  )
  inspect(cursor.origin.x, content="18")
  assert_true(cursor.origin.x == 10.0 + layout.caret_positions[1])
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
test "focused text input caret rect follows ime composition cursor" {
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
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="你",
          cursor=Some(TextRange::new(start=1, end=1)),
        ),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="0")
  match input.composition_cursor {
    Some(cursor) => inspect(cursor.end, content="1")
    None => fail("expected composition cursor")
  }
  inspect(input.caret_rect.origin.x, content="18")
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

///|
test "ime delete surrounding removes text around caret" {
  let state = State::new("abc")
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(TextInput(DeleteSurrounding(1, 1)))
  inspect(state.get(), content="a")
}
