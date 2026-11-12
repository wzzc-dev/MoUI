///|
fn transient_scroll_test_session() -> MarkdownDocumentSession {
  let parts : Array[String] = []
  for index in 0..<60 {
    parts.push(
      "Paragraph \{index} with enough text to take a line in the viewport.",
    )
  }
  MarkdownDocumentSession::new(parts.join("\n\n"))
}

///|
fn transient_scroll_test_ctx(
  event~ : @core.AppEvent,
  now_ms~ : Double = 0.0,
  state~ : @core.ViewStateContext? = None,
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=420.0, height=300.0),
    child_frames: [],
    event,
    focused: true,
    state: match state {
      Some(state) => state
      None =>
        {
          focused: true,
          hovered: false,
          pressed: false,
          selected: false,
          checked: false,
          expanded: false,
          disabled: false,
          slots: @core.ViewStateSlots::empty(),
        }
    },
    text_control: {
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
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms,
  }
}

///|
fn transient_scroll_wheel_result(
  ctx : @core.ViewEventContext,
  session : MarkdownDocumentSession,
  on_scroll_settled : ((Double) -> Double)?,
) -> @core.ViewEventResult[Double] {
  markdown_session_editor_event_transient(
    ctx,
    session~,
    selection={ caret: 0, selection: None, },
    on_transaction=_ => 0.0,
    font=@core.FontSpec::new(),
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    on_selection_change=None,
    on_prefix_click=None,
    on_command_click=None,
    accepts_tab_input=true,
    seed_glide=MarkdownScrollGlide::settled(0.0),
    scroll_request=None,
    on_scroll_settled~,
    visible_viewport_height=300.0,
    visible_overscan=100.0,
  )
}

///|
test "transient wheel writes the element slot without activating or messaging" {
  let session = transient_scroll_test_session()
  let event = @core.Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=40.0, y=40.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=-36.0),
    ),
  )
  let result = transient_scroll_wheel_result(
    transient_scroll_test_ctx(event~),
    session,
    None,
  )
  assert_true(result.changed)
  assert_false(result.activated)
  assert_true(result.messages.is_empty())
  let state = result.state.unwrap()
  let stored = state.read_slot(markdown_session_scroll_state_slot())
  assert_true(stored.glide.to_y > 0.0)
  assert_true(stored.settle_pending)
}

///|
test "transient scroll reports the settled offset exactly once" {
  let session = transient_scroll_test_session()
  let wheel = @core.Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=40.0, y=40.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=-48.0),
    ),
  )
  let first = transient_scroll_wheel_result(
    transient_scroll_test_ctx(event=wheel),
    session,
    Some(y => y),
  )
  let scrolled = first.state.unwrap()
  let tick = @core.FrameTick(@core.Frame::new(time_ms=1000.0, delta_ms=16.0))
  let settled = transient_scroll_wheel_result(
    transient_scroll_test_ctx(event=tick, now_ms=1000.0, state=Some(scrolled)),
    session,
    Some(y => y),
  )
  assert_eq(settled.messages.length(), 1)
  assert_false(settled.activated)
  assert_true(settled.messages[0] > 0.0)
  let after = settled.state.unwrap()
  assert_false(
    after.read_slot(markdown_session_scroll_state_slot()).settle_pending,
  )
  let again = transient_scroll_wheel_result(
    transient_scroll_test_ctx(event=tick, now_ms=1100.0, state=Some(after)),
    session,
    Some(y => y),
  )
  assert_true(again.messages.is_empty())
}

///|
test "scroll request applies once per id and newer ids win" {
  let initial : MarkdownSessionScrollState = {
    glide: MarkdownScrollGlide::settled(0.0),
    applied_request_id: -2,
    settle_pending: false,
    settle_notified: true,
    last_motion_ms: 0.0,
  }
  let requested = markdown_session_effective_scroll_state(
    initial,
    MarkdownScrollGlide::settled(0.0),
    Some(
      @core.ScrollRequest::new(id=3, offset=@core.Point::new(x=0.0, y=210.0)),
    ),
    max_scroll=1000.0,
  )
  assert_eq(requested.glide.to_y, 210.0)
  assert_eq(requested.applied_request_id, 3)
  let repeated = markdown_session_effective_scroll_state(
    requested,
    MarkdownScrollGlide::settled(0.0),
    Some(
      @core.ScrollRequest::new(id=3, offset=@core.Point::new(x=0.0, y=999.0)),
    ),
    max_scroll=1000.0,
  )
  assert_eq(repeated.glide.to_y, 210.0)
  let newer = markdown_session_effective_scroll_state(
    repeated,
    MarkdownScrollGlide::settled(0.0),
    Some(@core.ScrollRequest::new(id=4, offset=@core.Point::new(x=0.0, y=40.0))),
    max_scroll=1000.0,
  )
  assert_eq(newer.glide.to_y, 40.0)
}

///|
test "pinning freezes a moving glide at the shown offset" {
  let state : MarkdownSessionScrollState = {
    glide: MarkdownScrollGlide::new(
      from_y=0.0,
      to_y=500.0,
      start_ms=0.0,
      tau_ms=90.0,
    ),
    applied_request_id: -1,
    settle_pending: true,
    settle_notified: false,
    last_motion_ms: 0.0,
  }
  let pinned = markdown_session_pin_scroll(state, 30.0, 600.0)
  assert_eq(pinned.glide.from_y, pinned.glide.to_y)
  assert_false(pinned.settle_pending)
  assert_true(pinned.glide.to_y > 0.0)
}
