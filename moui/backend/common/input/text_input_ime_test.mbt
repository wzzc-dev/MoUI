///|
test "text input session enables updates and disables ime requests" {
  let text = Ref("ab")
  let runtime = window_test_text_field_runtime(
    value=text,
    width=120.0,
    height=40.0,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let session = TextInputSession::new()
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unfocused runtime should not change ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=110.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    EnableIme(@window_core.ImeRequest::Enable(_)) => ()
    _ => fail("focused text field should enable ime")
  }
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unchanged focused text field should not repeat ime updates")
  }
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("c")),
  )
  match session.sync(runtime.focused_text_input()) {
    UpdateIme(@window_core.ImeRequest::Update(data)) => {
      match data.cursor_area() {
        Some((_, size)) => assert_true(size.to_logical(1.0).height() > 0.0)
        None => fail("expected cursor area")
      }
      match data.surrounding_text() {
        Some(surrounding) => inspect(surrounding.text(), content="abc")
        None => fail("expected surrounding text")
      }
    }
    _ => fail("changed focused text field should update active ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=230.0, y=55.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    DisableIme(@window_core.ImeRequest::Disable) => ()
    _ => fail("blur should disable ime")
  }
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unfocused runtime should stay idle after disabling ime")
  }
}

///|
test "text input session enables ime when surrounding text is too long" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    text: "a".repeat(@window_core.ImeSurroundingText::max_text_bytes() + 1),
    caret: 0,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) => {
      assert_true(!request.capabilities().surrounding_text())
      assert_true(!request.request_data().has_surrounding_text())
      match session.last_diagnostics() {
        Some(diagnostics) => {
          assert_false(diagnostics.has_surrounding_text)
          assert_true(
            diagnostics.surrounding_text_utf8_length >
            @window_core.ImeSurroundingText::max_text_bytes(),
          )
        }
        None => fail("expected ime diagnostics")
      }
    }
    _ => fail("focused text field should still enable ime")
  }
}

///|
test "text input ime diagnostics normalize grapheme cursor and candidate anchor" {
  let state = @core.TextInputState::{
    focused: true,
    text: "A👩‍💻B",
    caret: 2,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=12.0, y=18.0, width=0.0, height=-4.0),
  }
  let diagnostics = text_input_ime_request_diagnostics(state)
  inspect(diagnostics.cursor, content="1")
  inspect(diagnostics.anchor, content="1")
  inspect(diagnostics.cursor_utf8, content="1")
  inspect(diagnostics.anchor_utf8, content="1")
  inspect(diagnostics.text_length, content="5")
  inspect(diagnostics.text_utf8_length, content="13")
  assert_true(diagnostics.cursor_is_grapheme_boundary)
  assert_true(diagnostics.anchor_is_grapheme_boundary)
  inspect(diagnostics.candidate_anchor.origin.x, content="12")
  inspect(diagnostics.candidate_anchor.origin.y, content="18")
  inspect(diagnostics.candidate_anchor.size.width, content="1")
  inspect(diagnostics.candidate_anchor.size.height, content="1")
  let request = text_input_ime_request_data(state)
  match request.surrounding_text() {
    Some(surrounding) => {
      inspect(surrounding.cursor(), content="1")
      inspect(surrounding.anchor(), content="1")
    }
    None => fail("expected surrounding text")
  }
  match request.cursor_area() {
    Some((position, size)) => {
      inspect(position.to_logical(1.0).x(), content="12")
      inspect(position.to_logical(1.0).y(), content="18")
      inspect(size.to_logical(1.0).width(), content="1")
      inspect(size.to_logical(1.0).height(), content="1")
    }
    None => fail("expected cursor area")
  }
}

///|
test "text input session preserves selection anchor in ime surrounding text" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    text: "你ab好",
    caret: 3,
    selection: Some(@core.TextRange::new(start=1, end=3)),
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) =>
      match request.request_data().surrounding_text() {
        Some(surrounding) => {
          inspect(surrounding.cursor(), content="5")
          inspect(surrounding.anchor(), content="3")
          match session.last_diagnostics() {
            Some(diagnostics) => {
              inspect(diagnostics.cursor, content="3")
              inspect(diagnostics.anchor, content="1")
              inspect(diagnostics.cursor_utf8, content="5")
              inspect(diagnostics.anchor_utf8, content="3")
            }
            None => fail("expected ime diagnostics")
          }
        }
        None => fail("expected surrounding text")
      }
    _ => fail("focused text field should enable ime")
  }
}

///|
test "text input session preserves reverse selection anchor in ime surrounding text" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    text: "你ab好",
    caret: 1,
    selection: Some(@core.TextRange::new(start=3, end=1)),
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) =>
      match request.request_data().surrounding_text() {
        Some(surrounding) => {
          inspect(surrounding.cursor(), content="3")
          inspect(surrounding.anchor(), content="5")
        }
        None => fail("expected surrounding text")
      }
    _ => fail("focused text field should enable ime")
  }
}

///|
test "host event converts to current core event model" {
  let event = @backend_host.Event::TextInput(
    @core.TextInputEvent::InsertText("x"),
  ).to_core()
  match event {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="x")
    _ => fail("expected text input event")
  }
  let composition = @backend_host.Event::TextInput(
    @core.TextInputEvent::CompositionEnd("你"),
  ).to_core()
  match composition {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="你")
    _ => fail("expected composition text input event")
  }
  let scroll = @backend_host.Event::Scroll(
    @backend_host.HostScrollEvent::new(
      position=@core.Point::new(x=8.0, y=9.0),
      delta=@backend_host.HostScrollDelta::Lines(
        @core.Point::new(x=1.0, y=-2.0),
      ),
    ),
  ).to_core()
  match scroll {
    Some(@core.AppEvent::Pointer({ wheel_delta: { x: 40.0, y: -80.0 }, .. })) =>
      ()
    _ => fail("expected scroll pointer event")
  }
  let blur = @backend_host.Event::Focus(
    @backend_host.HostFocusEvent::new(
      focused=false,
      pointer_cancel_position=Some(@core.Point::new(x=2.0, y=3.0)),
    ),
  ).to_core()
  match blur {
    Some(@core.AppEvent::Pointer({ phase: @core.PointerPhase::Cancel, .. })) =>
      ()
    _ => fail("expected blur cancel pointer event")
  }
}
