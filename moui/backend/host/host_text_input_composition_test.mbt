///|
test "host driver dispatches ime composition text input events" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(
      text.binding(),
      width=240.0,
      height=40.0,
      outlined=true,
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionEnd("你")),
    ),
  )
  inspect(text.get(), content="你")
}

///|
test "host driver keeps unicode composition update in focused text state" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("ab")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(
        @core.TextInputEvent::CompositionUpdate(
          @core.CompositionUpdate::new(
            text="你☕️",
            cursor=Some(@core.TextRange::new(start=3, end=3)),
          ),
        ),
      ),
    ),
  )
  let composing = driver.focused_text_input()
  guard composing.composition is Some(composition) else {
    fail("expected host-routed composition text")
  }
  inspect(composition, content="你☕️")
  guard composing.composition_cursor is Some(cursor) else {
    fail("expected host-routed composition cursor")
  }
  inspect(cursor.start, content="3")
  inspect(cursor.end, content="3")
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionEnd("你☕️")),
    ),
  )
  inspect(text.get(), content="ab你☕️")
  inspect(driver.focused_text_input().caret, content="5")
}
