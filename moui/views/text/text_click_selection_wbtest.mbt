///|
/// 白盒：触屏时代的点击选择。双击选词、三击选行、点击计数窗口与
/// caret 拖拽的静止判定都必须跨 pointer 事件成立，因此状态沿着
/// `result.state` / `result.text_control` 串起来喂回下一次派发。

///|
struct ClickTestSession {
  state : @core.ViewStateContext
  control : @core.TextControlStateContext
}

///|
fn click_test_value() -> String {
  "one two\nthree four\nfive six seven"
}

///|
fn click_test_frame() -> @core.Rect {
  @core.Rect::new(x=0.0, y=0.0, width=240.0, height=104.0)
}

///|
fn click_test_font() -> @core.FontSpec {
  @core.FontSpec::new(size=14.0)
}

///|
let click_test_line_height : Double = 28.0

///|
fn click_test_session() -> ClickTestSession {
  {
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      goal_column: None,
      reveal: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    },
  }
}

///|
fn click_test_context(
  session : ClickTestSession,
  event~ : @core.AppEvent,
  now_ms~ : Double,
) -> @core.ViewEventContext {
  {
    frame: click_test_frame(),
    child_frames: [],
    event,
    focused: true,
    state: session.state,
    text_control: session.control,
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms,
  }
}

///|
/// Fold one handler result back into the session, the way the runtime commits
/// `result.state` and `result.text_control`.
fn ClickTestSession::apply(
  self : ClickTestSession,
  result : @core.ViewEventResult[Unit],
) -> ClickTestSession {
  let next = match result.state {
    Some(state) => { ..self, state, }
    None => self
  }
  match result.text_control {
    Some(control) => { ..next, control, }
    None => next
  }
}

///|
fn ClickTestSession::send_area(
  self : ClickTestSession,
  phase~ : @core.PointerPhase,
  x~ : Double,
  y~ : Double,
  now_ms~ : Double,
  value~ : String = click_test_value(),
) -> (@core.ViewEventResult[Unit], ClickTestSession) {
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    click_test_context(
      self,
      event=@core.AppEvent::Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~),
      ),
      now_ms~,
    ),
    value~,
    on_input=None,
    on_submit=None,
    font=click_test_font(),
    line_height=click_test_line_height,
  )
  (result, self.apply(result))
}

///|
fn ClickTestSession::send_key(
  self : ClickTestSession,
  key~ : String,
  value~ : String = click_test_value(),
) -> (@core.ViewEventResult[Unit], ClickTestSession) {
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    click_test_context(
      self,
      event=@core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(key~, pressed=true),
      ),
      now_ms=0.0,
    ),
    value~,
    on_input=None,
    on_submit=None,
    font=click_test_font(),
    line_height=click_test_line_height,
  )
  (result, self.apply(result))
}

///|
fn ClickTestSession::send_field(
  self : ClickTestSession,
  phase~ : @core.PointerPhase,
  x~ : Double,
  now_ms~ : Double,
) -> (@core.ViewEventResult[Unit], ClickTestSession) {
  let result : @core.ViewEventResult[Unit] = handle_text_field_event(
    click_test_context(
      self,
      event=@core.AppEvent::Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y=10.0), phase~),
      ),
      now_ms~,
    ),
    value="hello world",
    font=click_test_font(),
    on_input=None,
    on_submit=None,
    search_bar=false,
    on_clear=None,
  )
  (result, self.apply(result))
}

///|
fn click_test_selected(session : ClickTestSession, text~ : String) -> String {
  match session.control.selection {
    Some(range) => @core.selected_text(text, Some(range))
    None => ""
  }
}

///|
test "second click selects the word under the pointer" {
  let session0 = click_test_session()
  let (_, session1) = session0.send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=0.0,
  )
  // Line 1 of the value starts at char 8; a click near its left edge lands
  // on the first glyph of "three".
  assert_eq(session1.control.caret, 8)
  assert_true(session1.control.selection is None)
  let (second, session2) = session1.send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=120.0,
  )
  assert_true(second.changed)
  inspect(
    click_test_selected(session2, text=click_test_value()),
    content="three",
  )
  match session2.control.selection {
    Some(range) => assert_eq((range.start, range.end), (8, 13))
    None => fail("double click must select a word")
  }
}

///|
test "third click selects the whole hard line" {
  let (_, session1) = click_test_session().send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=0.0,
  )
  let (_, session2) = session1.send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=100.0,
  )
  let (_, session3) = session2.send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=200.0,
  )
  // Both words of the source line, not just the wrapped visual row.
  inspect(
    click_test_selected(session3, text=click_test_value()),
    content="three four",
  )
}

///|
test "clicks outside the window count as a fresh press" {
  let (_, session1) = click_test_session().send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=0.0,
  )
  let (_, session2) = session1.send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=900.0,
  )
  assert_true(session2.control.selection is None)
}

///|
test "a move on the down point never extends the selection" {
  let (_, session1) = click_test_session().send_area(
    phase=Down,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=0.0,
  )
  assert_true(session1.control.text_selection_anchor is Some(_))
  assert_true(session1.control.text_selection_origin is Some(_))
  let (stationary, session2) = session1.send_area(
    phase=Move,
    x=6.0,
    y=28.0 + 14.0,
    now_ms=16.0,
  )
  assert_false(stationary.changed)
  assert_true(session2.control.selection is None)
  let (dragged, session3) = session2.send_area(
    phase=Move,
    x=120.0,
    y=28.0 + 14.0,
    now_ms=32.0,
  )
  assert_true(dragged.changed)
  guard session3.control.selection is Some(range) else {
    fail("a dragged pointer must extend the selection")
  }
  assert_eq(range.start, 8)
  assert_true(range.end > 8)
  let (_, session4) = session3.send_area(
    phase=Up,
    x=120.0,
    y=28.0 + 14.0,
    now_ms=48.0,
  )
  assert_true(session4.control.text_selection_anchor is None)
  assert_true(session4.control.text_selection_origin is None)
}

///|
test "vertical caret moves seed and keep a goal column" {
  // Line 0 is long, line 1 is one character, line 2 is long again. Without a
  // remembered column the caret walks down to the left edge of line 2; with
  // one it keeps aiming at the column the click chose.
  let value = "one two three\nx\nfour five six seven"
  let (_, session1) = click_test_session().send_area(
    phase=Down,
    x=48.0,
    y=14.0,
    now_ms=0.0,
    value~,
  )
  let column = session1.control.caret
  assert_true(column > 3)
  let (_, session2) = session1.send_key(key="ArrowDown", value~)
  guard session2.control.goal_column is Some(seeded) else {
    fail("a vertical move must record the column it is aiming at")
  }
  // Line 1 is the single "x", so the caret can only sit at either edge of it.
  assert_true(session2.control.caret >= 14 && session2.control.caret <= 15)
  let (_, session3) = session2.send_key(key="ArrowDown", value~)
  guard session3.control.goal_column is Some(kept) else {
    fail("the goal column must survive a second vertical move")
  }
  assert_eq(seeded, kept)
  // Line 2 starts at char 16; landing past its third character is only
  // possible by aiming at the remembered column instead of the caret's own x.
  assert_true(session3.control.caret > 19)
}

///|
test "double click in a single-line field selects the word" {
  let (_, session1) = click_test_session().send_field(
    phase=Down,
    x=6.0,
    now_ms=0.0,
  )
  let (_, session2) = session1.send_field(phase=Down, x=6.0, now_ms=120.0)
  inspect(click_test_selected(session2, text="hello world"), content="hello")
}

///|
test "a moved caret publishes the rect an ancestor must reveal" {
  // The first press lands where the caret already sits, so nothing moved
  // and no scroller may be told to follow.
  let (_, session1) = click_test_session().send_area(
    phase=Down,
    x=6.0,
    y=14.0,
    now_ms=0.0,
  )
  assert_true(session1.control.reveal is None)
  let (_, session2) = session1.send_area(
    phase=Down,
    x=48.0,
    y=14.0,
    now_ms=400.0,
  )
  guard session2.control.reveal is Some(rect) else {
    fail("a caret change must publish the caret rect for a scroll ancestor")
  }
  let frame = click_test_frame()
  assert_true(rect.origin.x >= frame.origin.x)
  assert_true(rect.size.height > 0.0)
  // The caret sits on the first row, so it cannot fall below that slot.
  assert_true(rect.origin.y < frame.origin.y + click_test_line_height)
  // A single-line field owns no viewport: the reveal is its only way for an
  // enclosing scroll view to follow a selection the app never wired up.
  let (_, field1) = click_test_session().send_field(
    phase=Down,
    x=6.0,
    now_ms=0.0,
  )
  assert_true(field1.control.reveal is None)
  let (_, field2) = field1.send_field(phase=Down, x=6.0, now_ms=120.0)
  assert_true(field2.control.reveal is Some(_))
}
