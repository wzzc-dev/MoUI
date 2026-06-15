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
