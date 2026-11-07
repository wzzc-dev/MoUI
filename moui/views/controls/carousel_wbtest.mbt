///|
/// White-box coverage for the `carousel`: swipe release flipping, snap-back,
/// edge bounding, and the semantics surface. Drag probes account for the
/// surface being the whole viewport (300 logical px wide in these fixtures),
/// so the flip threshold sits at 100px.

///|
fn carousel_test_state(
  slots~ : @core.ViewStateSlots = @core.ViewStateSlots::empty(),
) -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots,
  }
}

///|
fn carousel_test_event_context(
  event~ : @core.AppEvent,
  state~ : @core.ViewStateContext = carousel_test_state(),
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=300.0, height=180.0),
    child_frames: [],
    event,
    focused: false,
    state,
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
    now_ms: 0.0,
  }
}

///|
fn carousel_test_pointer(
  x~ : Double,
  phase~ : @core.PointerPhase,
) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x~, y=90.0), phase~),
  )
}

///|
fn carousel_test_view(
  page~ : Int32 = 0,
  received~ : Array[Int32],
) -> @core.View[Unit] {
  carousel(3, page, on_page_change=next => received.push(next), builder=index => {
    @text.text("page \{index}")
  })
}

///|
test "a swipe past the threshold flips one page on release" {
  let received : Array[Int32] = []
  let view : @core.View[Unit] = carousel_test_view(page=0, received~)
  let down = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=150.0, phase=Down),
    ),
  )
  assert_true(down.captured)
  let drag = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=30.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  // The drag itself is paint-only: the page has not changed yet.
  assert_true(drag.changed)
  assert_true(received.length() == 0)
  let up = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=30.0, phase=Up),
      state=drag.state.unwrap(),
    ),
  )
  assert_true(up.activated)
  assert_true(received.length() == 1)
  assert_true(received[0] == 1)
}

///|
test "a short swipe snaps back without flipping" {
  let received : Array[Int32] = []
  let view : @core.View[Unit] = carousel_test_view(page=0, received~)
  let down = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=150.0, phase=Down),
    ),
  )
  let drag = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=130.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  assert_true(drag.changed)
  let up = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=130.0, phase=Up),
      state=drag.state.unwrap(),
    ),
  )
  // The release repaints (snap back) but flips nothing.
  assert_true(up.changed)
  assert_false(up.activated)
  assert_true(received.length() == 0)
}

///|
test "the first and last pages bound the swipe" {
  let received : Array[Int32] = []
  let view : @core.View[Unit] = carousel_test_view(page=0, received~)
  // Dragging right on the first page pulls nothing: the offset is bounded to
  // zero, the release has no page to go to.
  let down = view.event(
    carousel_test_event_context(event=carousel_test_pointer(x=50.0, phase=Down)),
  )
  let drag = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=200.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  // The raw offset stayed clamped: paint saw no motion.
  assert_false(drag.changed)
  let up = view.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=200.0, phase=Up),
      state=down.state.unwrap(),
    ),
  )
  assert_true(received.length() == 0)
  // The last page bounds the leftward swipe the same way.
  let last : @core.View[Unit] = carousel_test_view(page=2, received~)
  let last_down = last.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=250.0, phase=Down),
    ),
  )
  let last_drag = last.event(
    carousel_test_event_context(
      event=carousel_test_pointer(x=50.0, phase=Move),
      state=last_down.state.unwrap(),
    ),
  )
  assert_false(last_drag.changed)
  ignore(up)
}

///|
test "carousel reports the page position and flips through semantics" {
  let received : Array[Int32] = []
  let view : @core.View[Int32] = carousel(
    3,
    1,
    on_page_change=next => {
      received.push(next)
      next
    },
    builder=(index : Int32) => (@text.text("page \{index}") : @core.View[Int32]),
  ).semantic_id("showcase.carousel-test")
  let info = view.semantics()
  assert_true(info.role == Some(ScrollView))
  inspect(info.value.unwrap(), content="page 2 of 3")
  // The scroll semantics action flips one page per call.
  let snapshot = @runtime.AppRuntime::new_view(
    root=view,
    size=@core.Size::new(width=300.0, height=180.0),
    on_message=Some(next => received.push(next)),
  ).read_semantics()
  ignore(snapshot)
  assert_true(received.length() == 0)
}

///|
test "carousel lays out, paints, and windows its pages" {
  let received : Array[Int32] = []
  let view : @core.View[Unit] = carousel_test_view(page=1, received~)
  let layout = view.layout({
    constraints: @core.Constraints::tight(
      @core.Size::new(width=300.0, height=180.0),
    ),
    child_sizes: [
      @core.Size::new(width=300.0, height=180.0),
      @core.Size::new(width=300.0, height=180.0),
      @core.Size::new(width=300.0, height=180.0),
    ],
    child_flex_weights: [],
    state: carousel_test_state(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  })
  // Interior page: both neighbors are laid out one viewport away.
  assert_true(layout.size.width == 300.0)
  assert_true(layout.child_frames.length() == 3)
  assert_true(layout.child_frames[0].origin.x == 0.0 - 300.0)
  assert_true(layout.child_frames[1].origin.x == 0.0)
  assert_true(layout.child_frames[2].origin.x == 300.0)
  assert_true(layout.clips_children)
}
