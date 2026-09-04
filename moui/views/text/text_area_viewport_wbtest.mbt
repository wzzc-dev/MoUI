///|
fn viewport_test_state(
  offset_y? : Double = 0.0,
) -> @core.ViewStateContext {
  let base : @core.ViewStateContext = {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
  base.with_slot(text_area_scroll_slot(), { offset_y : offset_y })
}

///|
fn viewport_test_text_control(
  caret~ : Int,
) -> @core.TextControlStateContext {
  {
    caret,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn viewport_test_event_context(
  event~ : @core.AppEvent,
  state~ : @core.ViewStateContext,
  text_control~ : @core.TextControlStateContext,
  frame~ : @core.Rect,
) -> @core.ViewEventContext {
  {
    frame,
    child_frames: [],
    event,
    focused: true,
    state,
    text_control,
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
/// 20 short lines wrapped over one paragraph row each; the frame gives
/// a 220×88 text viewport so only ~3 line slots of the 20×28 content
/// are visible at a time.
fn viewport_test_value() -> String {
  let lines : Array[String] = []
  for i = 0; i < 20; i = i + 1 {
    lines.push("line \{i}")
  }
  lines.join("\n")
}

///|
fn viewport_test_frame() -> @core.Rect {
  @core.Rect::new(x=0.0, y=0.0, width=240.0, height=104.0)
}

///|
fn viewport_test_font() -> @core.FontSpec {
  @core.FontSpec::new(size=14.0)
}

///|
fn viewport_test_offset(state : @core.ViewStateContext) -> Double {
  state.read_slot(text_area_scroll_slot()).offset_y
}

///|
test "wheel scrolls the text area viewport and persists the offset" {
  let event = @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=100.0, y=50.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=-56.0),
    ),
  )
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    viewport_test_event_context(
      event~,
      state=viewport_test_state(),
      text_control=viewport_test_text_control(caret=0),
      frame=viewport_test_frame(),
    ),
    value=viewport_test_value(),
    on_input=None,
    on_submit=None,
    font=viewport_test_font(),
    line_height=28.0,
  )
  assert_true(result.changed)
  match result.state {
    None => fail("wheel result must carry the new scroll state")
    Some(state) => assert_eq(viewport_test_offset(state), 56.0)
  }
}

///|
test "wheel past the top edge is a no-op instead of negative jitter" {
  let event = @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=100.0, y=50.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=100.0),
    ),
  )
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    viewport_test_event_context(
      event~,
      state=viewport_test_state(),
      text_control=viewport_test_text_control(caret=0),
      frame=viewport_test_frame(),
    ),
    value=viewport_test_value(),
    on_input=None,
    on_submit=None,
    font=viewport_test_font(),
    line_height=28.0,
  )
  assert_true(!result.changed)
  assert_true(result.state is None)
}

///|
test "wheel past the bottom edge clamps to content minus viewport" {
  let event = @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=100.0, y=50.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=-1000.0),
    ),
  )
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    viewport_test_event_context(
      event~,
      state=viewport_test_state(),
      text_control=viewport_test_text_control(caret=0),
      frame=viewport_test_frame(),
    ),
    value=viewport_test_value(),
    on_input=None,
    on_submit=None,
    font=viewport_test_font(),
    line_height=28.0,
  )
  match result.state {
    None => fail("wheel result must carry the new scroll state")
    Some(state) =>
      // 20 lines × 28.0 content over an 88.0 viewport leaves 472.0.
      assert_eq(viewport_test_offset(state), 472.0)
  }
}

///|
test "typing past the viewport reveals the caret line at the bottom" {
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    viewport_test_event_context(
      event=@core.AppEvent::TextInput(
        @core.TextInputEvent::InsertText("x"),
      ),
      state=viewport_test_state(),
      text_control=viewport_test_text_control(caret=119),
      frame=viewport_test_frame(),
    ),
    value=viewport_test_value(),
    on_input=None,
    on_submit=None,
    font=viewport_test_font(),
    line_height=28.0,
  )
  match result.text_control {
    None => fail("inserting text must move the caret")
    Some(control) => assert_true(control.caret > 119)
  }
  match result.state {
    None => fail("caret past the viewport must reveal with a scroll step")
    Some(state) =>
      // The caret lands in the row covering the old text end, so the
      // minimal reveal is bottom-alignment of that row, not a jump to
      // the absolute bottom of the content.
      assert_eq(viewport_test_offset(state), 388.0)
  }
  assert_true(result.dirty == @core.ViewDirtyHint::ViewLayoutDirty)
}

///|
test "typing with a visible caret leaves the scroll state alone" {
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    viewport_test_event_context(
      event=@core.AppEvent::TextInput(
        @core.TextInputEvent::InsertText("x"),
      ),
      state=viewport_test_state(),
      text_control=viewport_test_text_control(caret=3),
      frame=viewport_test_frame(),
    ),
    value=viewport_test_value(),
    on_input=None,
    on_submit=None,
    font=viewport_test_font(),
    line_height=28.0,
  )
  assert_true(result.changed)
  assert_true(result.state is None)
}

///|
test "clicks hit the scrolled line, not the unscrolled one" {
  let frame = viewport_test_frame()
  let text_frame = text_area_text_frame(frame)
  let font = viewport_test_font()
  let value = viewport_test_value()
  let paragraph = text_area_paragraph(
    @core.TextSystem::fallback(),
    value,
    font,
    text_frame,
  )
  assert_eq(paragraph.lines.length(), 20)
  let target = paragraph.lines[19]
  // Scroll to the bottom, then click the slot of the drawn last row:
  // row 19 paints at content slot y 19×28, so in the scrolled
  // viewport it sits at slot y 546−472 = 74 inside the text frame.
  let offset = 472.0
  let click_y = text_frame.origin.y + (19.0 * 28.0 + 14.0 - offset)
  let event = @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=text_frame.origin.x + 5.0, y=click_y),
      phase=@core.PointerPhase::Down,
    ),
  )
  let result : @core.ViewEventResult[Unit] = handle_text_area_event(
    viewport_test_event_context(
      event~,
      state=viewport_test_state(offset_y=offset),
      text_control=viewport_test_text_control(caret=0),
      frame~,
    ),
    value~,
    on_input=None,
    on_submit=None,
    font~,
    line_height=28.0,
  )
  match result.text_control {
    None => fail("click inside the frame must place the caret")
    Some(control) =>
      assert_true(
        control.caret >= target.text_range.start &&
          control.caret <= target.text_range.end,
      )
  }
}

///|
test "stale offset beyond shrunken content clamps instead of blank space" {
  // 3 lines of content under a 88.0 viewport cannot scroll at all.
  assert_eq(
    text_area_clamped_scroll_offset(
      1000.0,
      line_count=3,
      line_height=28.0,
      viewport_height=88.0,
    ),
    0.0,
  )
}

///|
test "visible line window covers partial edge rows" {
  assert_eq(
    text_area_visible_line_window(
      offset=56.0,
      viewport_height=88.0,
      line_count=20,
      line_height=28.0,
    ),
    (2, 6),
  )
  assert_eq(
    text_area_visible_line_window(
      offset=472.0,
      viewport_height=88.0,
      line_count=20,
      line_height=28.0,
    ),
    (16, 20),
  )
}

///|
test "caret reveal only moves as far as needed" {
  // Caret line fully below the window: bottom-align.
  assert_eq(
    text_area_offset_for_caret_reveal(
      current=0.0,
      caret_line=10,
      line_count=20,
      line_height=28.0,
      viewport_height=88.0,
    ),
    220.0,
  )
  // Caret line above the window: top-align.
  assert_eq(
    text_area_offset_for_caret_reveal(
      current=472.0,
      caret_line=2,
      line_count=20,
      line_height=28.0,
      viewport_height=88.0,
    ),
    56.0,
  )
  // Caret already inside: unchanged.
  assert_eq(
    text_area_offset_for_caret_reveal(
      current=100.0,
      caret_line=4,
      line_count=20,
      line_height=28.0,
      viewport_height=88.0,
    ),
    100.0,
  )
}
