///|
fn scroll_test_rect(width~ : Double, height~ : Double) -> @core.View[Unit] {
  @core.View::from_node(ScrollTestRect::{ width, height })
}

///|
priv struct ScrollTestRect {
  width : Double
  height : Double
}

///|
impl @core.ViewNode for ScrollTestRect with fn identity(_self) {
  @core.ViewIdentity::new(kind="ScrollTestRect")
}

///|
impl @core.ViewNode for ScrollTestRect with fn declaration(self) {
  @common.view_layout_declaration(
    @common.view_record_key("ScrollTestRect", [
      ("width", @core.DeclarationKey::double(self.width)),
      ("height", @core.DeclarationKey::double(self.height)),
    ]),
  )
}

///|
impl @core.ViewNode for ScrollTestRect with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
fn scroll_test_state_context() -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
}

///|
fn scroll_test_text_control_context() -> @core.TextControlStateContext {
  {
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn scroll_test_layout_context(
  child_size~ : @core.Size,
  state? : @core.ViewStateContext = scroll_test_state_context(),
) -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::tight(
      @core.Size::new(width=100.0, height=100.0),
    ),
    child_sizes: [child_size],
    child_flex_weights: [0.0],
    state,
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn scroll_test_event_context(
  event~ : @core.AppEvent,
  child_frames~ : Array[@core.Rect],
  state? : @core.ViewStateContext = scroll_test_state_context(),
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames,
    event,
    focused: false,
    state,
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn scroll_test_pointer(
  x~ : Double,
  y~ : Double,
  phase~ : @core.PointerPhase,
  wheel_y? : Double = 0.0,
) -> @core.AppEvent {
  @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x~, y~),
      phase~,
      wheel_delta=@core.Point::new(x=0.0, y=wheel_y),
    ),
  )
}

///|
test "controlled scroll emits the absolute clamped offset" {
  let child : @core.View[@core.Point] = scroll_test_rect(
    width=100.0,
    height=500.0,
  ).map(_ => @core.Point::new(x=0.0, y=0.0))
  let view = scroll_container(
    child~,
    offset=@core.Point::new(x=0.0, y=999.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
    on_scroll=Some(next => next),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  assert_true(
    layout.child_frames[0] ==
    @core.Rect::new(x=0.0, y=-400.0, width=100.0, height=500.0),
  )
  let result = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(
        x=50.0,
        y=50.0,
        phase=@core.PointerPhase::Move,
        wheel_y=40.0,
      ),
      child_frames=layout.child_frames,
    ),
  )
  assert_true(result.captured)
  assert_true(result.messages == [@core.Point::new(x=0.0, y=360.0)])
}

///|
test "scroll wheel at a clamped edge stays clean" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    offset=@core.Point::new(x=0.0, y=400.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
    on_scroll=Some(_ => ()),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let result = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(
        x=50.0,
        y=50.0,
        phase=@core.PointerPhase::Move,
        wheel_y=-40.0,
      ),
      child_frames=layout.child_frames,
    ),
  )
  assert_false(result.changed)
  assert_false(result.captured)
  assert_true(result.dirty is @core.ViewDirtyHint::ViewClean)
  assert_true(result.messages.is_empty())
}

///|
test "uncontrolled scroll stores wheel offset in the element slot" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let result = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(
        x=50.0,
        y=50.0,
        phase=@core.PointerPhase::Move,
        wheel_y=-40.0,
      ),
      child_frames=layout.child_frames,
    ),
  )
  let state = result.state.unwrap()
  assert_true(state.read_slot(scroll_runtime_state_slot()).offset.y == 40.0)
  assert_true(result.messages.is_empty())
}

///|
test "scroll request ids are applied once per mounted slot" {
  let child = scroll_test_rect(width=100.0, height=500.0)
  let request = @core.ScrollRequest::new(
    id=4,
    offset=@core.Point::new(x=0.0, y=80.0),
  )
  let requested : @core.View[Unit] = scroll_container(
    child~,
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
    request~,
  )
  let initial = scroll_test_state_context()
  let requested_layout = requested.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
      state=initial,
    ),
  )
  assert_true(requested_layout.child_frames[0].origin.y == -80.0)
  let scrolled = requested.event(
    scroll_test_event_context(
      event=scroll_test_pointer(
        x=50.0,
        y=50.0,
        phase=@core.PointerPhase::Move,
        wheel_y=-20.0,
      ),
      child_frames=requested_layout.child_frames,
      state=initial,
    ),
  ).state.unwrap()
  assert_true(scrolled.read_slot(scroll_runtime_state_slot()).offset.y == 100.0)
  let repeated_layout = requested.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
      state=scrolled,
    ),
  )
  assert_true(repeated_layout.child_frames[0].origin.y == -100.0)
  let replaced : @core.View[Unit] = scroll_container(
    child~,
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
    request=@core.ScrollRequest::new(
      id=5,
      offset=@core.Point::new(x=0.0, y=140.0),
    ),
  )
  let replaced_layout = replaced.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
      state=scrolled,
    ),
  )
  assert_true(replaced_layout.child_frames[0].origin.y == -140.0)
}

///|
test "scroll indicator is opt-in and draggable" {
  let visible : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
    shows_indicator=true,
  )
  let layout = visible.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let paint = visible.paint({
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames: layout.child_frames,
    focused: false,
    state: scroll_test_state_context(),
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  })
  assert_true(paint.overlay_commands.length() == 1)
  let result = visible.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=98.0, y=80.0, phase=@core.PointerPhase::Down),
      child_frames=layout.child_frames,
    ),
  )
  assert_true(result.captured)
  assert_true(
    result.state.unwrap().read_slot(scroll_runtime_state_slot()).offset.y > 0.0,
  )
  let hidden : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let hidden_paint = hidden.paint({
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames: layout.child_frames,
    focused: false,
    state: scroll_test_state_context(),
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  })
  assert_true(hidden_paint.overlay_commands.is_empty())
}

///|
test "scroll drag state and offset stay element-owned" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let initial = scroll_test_state_context()
  let down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=50.0, phase=@core.PointerPhase::Down),
      child_frames=layout.child_frames,
      state=initial,
    ),
  )
  let after_down = down.state.unwrap_or(initial)
  let moved = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=20.0, phase=@core.PointerPhase::Move),
      child_frames=layout.child_frames,
      state=after_down,
    ),
  )
  let after_move = moved.state.unwrap_or(after_down)
  assert_true(
    after_move.read_slot(scroll_runtime_state_slot()).offset.y == 30.0,
  )
  let released = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=20.0, phase=@core.PointerPhase::Up),
      child_frames=layout.child_frames,
      state=after_move,
    ),
  ).state.unwrap_or(after_move)
  assert_false(released.read_slot(scroll_drag_state_slot()).active)
}
