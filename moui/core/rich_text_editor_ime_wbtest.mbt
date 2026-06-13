///|
test "rich text editor ime composition commits canonical text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
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
  inspect(state.get(), content="")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="你")
}

///|
test "rich text editor ime composition replaces selection" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
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
}
