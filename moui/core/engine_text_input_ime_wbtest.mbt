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
