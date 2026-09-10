///|
/// A text system measuring twice as wide as the fallback. Pointer gestures
/// must hit-test every phase with the *same* system the view was given:
/// if one phase silently falls back, the same click point maps to a
/// different source offset and a plain click fabricates a phantom
/// selection between the two answers.
fn session_editor_doubled_text_system() -> @core.TextSystem {
  let base = @core.TextSystem::fallback()
  @core.TextSystem::new(id="session-editor-doubled-test-text-system", measure=input => {
    let result = base.measure_text(input)
    {
      ..result,
      size: @core.Size::new(
        width=result.size.width * 2.0,
        height=result.size.height,
      ),
      caret_positions: result.caret_positions.map(x => x * 2.0),
    }
  })
}

///|
fn session_editor_text_control(
  caret~ : Int,
  anchor? : Int? = None,
  origin? : @core.Point? = None,
) -> @core.TextControlStateContext {
  {
    caret,
    selection: None,
    text_selection_anchor: anchor,
    text_selection_origin: origin,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn session_editor_ctx(
  event~ : @core.AppEvent,
  text_control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=400.0, height=300.0),
    child_frames: [],
    event,
    focused: true,
    state: {
      focused: true,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_control,
    text_system,
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn session_editor_pointer_event(
  ctx~ : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  font~ : @core.FontSpec,
  event~ : @core.PointerEvent,
  visible_scroll_y? : Double = 0.0,
) -> @core.ViewEventResult[(Int, @core.TextRange?)] {
  markdown_session_pointer_event(
    ctx,
    session~,
    selection~,
    font~,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    on_selection_change=Some((caret, selection) => (caret, selection)),
    on_prefix_click=None,
    on_command_click=None,
    event~,
    visible_scroll_y~,
    on_scroll=None,
    visible_viewport_height=300.0,
    visible_overscan=320.0,
  )
}

///|
/// Drive a Down at `point` and return the click's caret and control.
fn session_editor_click_down(
  session~ : MarkdownDocumentSession,
  font~ : @core.FontSpec,
  text_system~ : @core.TextSystem,
  point~ : @core.Point,
  selection~ : MarkdownEditorSelection,
) -> (Int, @core.TextControlStateContext) raise {
  let down_event = @core.PointerEvent::new(
    position=point,
    phase=@core.PointerPhase::Down,
  )
  let down = session_editor_pointer_event(
    ctx=session_editor_ctx(
      event=@core.AppEvent::Pointer(down_event),
      text_control=session_editor_text_control(caret=selection.caret),
      text_system~,
    ),
    session~,
    selection~,
    font~,
    event=down_event,
  )
  guard down.messages.length() == 1 else {
    fail("expected one selection message from the click")
  }
  guard down.messages[0] is (caret, None) else {
    fail("expected a collapsed click selection")
  }
  guard down.text_control is Some(control) else {
    fail("expected click text control")
  }
  assert_true(control.caret == caret)
  assert_true(control.text_selection_anchor == Some(caret))
  assert_true(control.text_selection_origin == Some(point))
  (caret, control)
}

///|
/// A Move at exactly the click's point must never extend the selection,
/// no matter what the layout (scroll position, marker reveal) did in
/// between: the pointer did not travel, so the gesture has not dragged.
fn session_editor_assert_stationary_move_is_noop(
  session~ : MarkdownDocumentSession,
  font~ : @core.FontSpec,
  text_system~ : @core.TextSystem,
  point~ : @core.Point,
  caret~ : Int,
  control~ : @core.TextControlStateContext,
  scroll_y~ : Double,
) -> Unit raise {
  let move_event = @core.PointerEvent::new(
    position=point,
    phase=@core.PointerPhase::Move,
  )
  let move_result = session_editor_pointer_event(
    ctx=session_editor_ctx(
      event=@core.AppEvent::Pointer(move_event),
      text_control=control,
      text_system~,
    ),
    session~,
    selection={ caret, selection: None },
    font~,
    event=move_event,
    visible_scroll_y=scroll_y,
  )
  assert_true(move_result.messages.is_empty())
  guard move_result.text_control is Some(move_control) else {
    fail("expected move text control")
  }
  assert_true(move_control.caret == caret)
  assert_true(move_control.selection is None)
}

///|
/// Regression: the Move handler must build its hit-test window with the
/// event's text system, not the fallback default (a silent fallback would
/// map the same point through a different layout). The click's companion
/// Move must additionally stay a no-op through the gesture origin guard.
test "markdown session click move keeps the event text system" {
  let source = "MoUI 是一个多平台 MoonBit GUI 框架，用于构建声明式 UI 应用，共享平台无关的应用逻辑。原生宿主核心拥有窗口、事件、服务和生命周期，再通过平台渲染器提供方包接入具体的渲染器。"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=16.0)
  let text_system = session_editor_doubled_text_system()
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  // A point on the second visual line, where the two text systems wrap the
  // paragraph at different source offsets.
  let point = @core.Point::new(x=140.0, y=40.0)
  let (caret, control) = session_editor_click_down(
    session~,
    font~,
    text_system~,
    point~,
    selection~,
  )
  assert_true(caret > 0)
  session_editor_assert_stationary_move_is_noop(
    session~,
    font~,
    text_system~,
    point~,
    caret~,
    control~,
    scroll_y=0.0,
  )
}

///|
/// Regression: Typora-style reveal is selection-driven. Clicking inside a
/// marked span expands its hidden markers and shifts the span under the
/// pointer; the click's companion Move must not re-derive the caret from
/// the screen point, or the click fabricates a selection out of the shift.
test "markdown session click inside a marker span does not fabricate a selection" {
  let source = "前文文字 **加粗重点** 后文文字，补足一些内容让段落稳定成一行显示。"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  // Caret far from the bold span: its markers stay hidden on the first map.
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let point = @core.Point::new(x=110.0, y=20.0)
  let (caret, control) = session_editor_click_down(
    session~,
    font~,
    text_system~,
    point~,
    selection~,
  )
  session_editor_assert_stationary_move_is_noop(
    session~,
    font~,
    text_system~,
    point~,
    caret~,
    control~,
    scroll_y=0.0,
  )
}

///|
/// Regression: the click's own caret placement can scroll the view
/// (typewriter centering). A Move at the same screen point then sits over
/// different text; it is the click's event stream, not a drag, and must
/// not extend the selection.
test "markdown session click move after a scroll jump does not fabricate a selection" {
  let lines : Array[String] = []
  for index in 0..<40 {
    lines.push(
      "第\{index}段文字，用来提供足够的滚动空间，让点击后的打字机居中真正移动布局。",
    )
  }
  let session = MarkdownDocumentSession::new(lines.join("\n\n"))
  let font = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let point = @core.Point::new(x=140.0, y=40.0)
  let (caret, control) = session_editor_click_down(
    session~,
    font~,
    text_system~,
    point~,
    selection~,
  )
  // Same point, but the view scrolled 120px between down and move.
  session_editor_assert_stationary_move_is_noop(
    session~,
    font~,
    text_system~,
    point~,
    caret~,
    control~,
    scroll_y=120.0,
  )
}

///|
/// A Move that actually travels must still extend the selection: the
/// guard only suppresses the click's own zero-distance events.
test "markdown session drag move still extends the selection" {
  let source = "MoUI 是一个多平台 MoonBit GUI 框架，用于构建声明式 UI 应用，共享平台无关的应用逻辑。原生宿主核心拥有窗口、事件、服务和生命周期。"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let point = @core.Point::new(x=110.0, y=20.0)
  let (caret, control) = session_editor_click_down(
    session~,
    font~,
    text_system~,
    point~,
    selection~,
  )
  let moved = @core.Point::new(x=170.0, y=20.0)
  let move_event = @core.PointerEvent::new(
    position=moved,
    phase=@core.PointerPhase::Move,
  )
  let move_result = session_editor_pointer_event(
    ctx=session_editor_ctx(
      event=@core.AppEvent::Pointer(move_event),
      text_control=control,
      text_system~,
    ),
    session~,
    selection={ caret, selection: None },
    font~,
    event=move_event,
  )
  assert_true(move_result.messages.length() == 1)
  guard move_result.messages[0] is (head, range) else {
    fail("expected a drag selection message")
  }
  guard range is Some(selection_range) else {
    fail("expected a range while dragging")
  }
  assert_true(selection_range.start == caret)
  assert_true(head != caret)
}
