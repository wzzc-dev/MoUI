///|
fn scroll_test_rect(width~ : Double, height~ : Double) -> @core.View[Unit] {
  @core.View::from_node(ScrollTestRect::{ width, height, })
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
    goal_column: None,
    reveal: None,
    text_selection_origin: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn scroll_test_layout_context(
  child_size~ : @core.Size,
  state~ : @core.ViewStateContext = scroll_test_state_context(),
  direction~ : @core.LayoutDirection = LeftToRight,
) -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::tight(
      @core.Size::new(width=100.0, height=100.0),
    ),
    child_sizes: [child_size],
    child_flex_weights: [0.0],
    state,
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_layout_direction(direction),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn scroll_test_event_context(
  event~ : @core.AppEvent,
  child_frames~ : Array[@core.Rect],
  state~ : @core.ViewStateContext = scroll_test_state_context(),
  now_ms~ : Double = 0.0,
  direction~ : @core.LayoutDirection = LeftToRight,
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames,
    event,
    focused: false,
    state,
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_layout_direction(direction),
    style: @core.ViewStyle::empty(),
    now_ms,
  }
}

///|
fn scroll_test_paint_context(
  child_frames~ : Array[@core.Rect],
  state~ : @core.ViewStateContext = scroll_test_state_context(),
  now_ms~ : Double = 0.0,
) -> @core.ViewPaintContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames,
    focused: false,
    state,
    text_control: scroll_test_text_control_context(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms,
  }
}

///|
/// The paint pass clips first and only adds a band transform when the surface
/// is offset from the authoritative geometry, so the two-element shape below
/// *is* the "is the band painted, and by how much" question.
fn scroll_test_painted_shift(paint : @core.ViewPaintPlan) -> @core.Point? {
  match paint.commands {
    [PushClip(_), PushTransform(transform)] =>
      Some(@core.Point::new(x=transform.tx, y=transform.ty))
    _ => None
  }
}

///|
fn scroll_test_close(left~ : Double, right~ : Double) -> Bool {
  (left - right).abs() < 0.001
}

///|
fn scroll_test_shift_y(paint : @core.ViewPaintPlan) -> Double {
  scroll_test_painted_shift(paint).unwrap().y
}

///|
fn scroll_test_pointer(
  x~ : Double,
  y~ : Double,
  phase~ : @core.PointerPhase,
  wheel_x~ : Double = 0.0,
  wheel_y~ : Double = 0.0,
) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x~, y~),
      phase~,
      wheel_delta=@core.Point::new(x=wheel_x, y=wheel_y),
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
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_y=40.0),
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
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_y=-40.0),
      child_frames=layout.child_frames,
    ),
  )
  assert_false(result.changed)
  assert_false(result.captured)
  assert_true(result.dirty is ViewClean)
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
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_y=-40.0),
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
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_y=-20.0),
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
      event=scroll_test_pointer(x=98.0, y=80.0, phase=Down),
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
fn scroll_test_band_point(x~ : Double = 0.0, y~ : Double) -> @core.Point {
  @core.Point::new(x~, y~)
}

///|
test "scroll drag past a clamp edge holds a bounded paint band" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let after_down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=80.0, phase=Down),
      child_frames=layout.child_frames,
      now_ms=100.0,
    ),
  ).state.unwrap()
  let pulled = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=480.0, phase=Move),
      child_frames=layout.child_frames,
      state=after_down,
      now_ms=120.0,
    ),
  )
  assert_true(pulled.changed)
  assert_true(pulled.captured)
  assert_true(pulled.dirty is ViewPaintDirty)
  let after_pull = pulled.state.unwrap()
  // A 400px pull past the head clamp is *not* geometry: layout, hit-testing and
  // `on_scroll` all still see the clamped offset, so a windowed child never has
  // to cover content that was never laid out.
  assert_true(
    after_pull.read_slot(scroll_runtime_state_slot()).offset ==
    scroll_test_band_point(y=0.0),
  )
  assert_true(after_pull.read_slot(scroll_drag_state_slot()).raw_offset.y < 0.0)
  // Only the painted surface moves, and only by the damped band:
  // `400 * 25 / (400 + 25)` against a 100px viewport (extent 25px).
  let paint = view.paint(
    scroll_test_paint_context(
      child_frames=layout.child_frames,
      state=after_pull,
      now_ms=120.0,
    ),
  )
  assert_true(
    scroll_test_close(left=scroll_test_shift_y(paint), right=23.529411764705884),
  )
  // A held band needs no frames; only a released one does.
  assert_false(paint.animating)
}

///|
test "a horizontal pull on a vertical-only scroller pulls no band" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let after_down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=80.0, phase=Down),
      child_frames=layout.child_frames,
      now_ms=100.0,
    ),
  ).state.unwrap()
  let pulled = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=450.0, y=80.0, phase=Move),
      child_frames=layout.child_frames,
      state=after_down,
      now_ms=120.0,
    ),
  )
  // 400px of travel along an axis the content never overflowed moves nothing, so
  // there is no repaint and no `on_scroll` message.
  assert_false(pulled.changed)
  assert_true(pulled.dirty is ViewClean)
  let after_pull = pulled.state.unwrap()
  // The drag still started, which is what cancels a child control under the
  // pointer: the gate removes the surface motion, not the gesture.
  assert_true(after_pull.read_slot(scroll_drag_state_slot()).dragging)
  assert_true(
    after_pull.read_slot(scroll_drag_state_slot()).raw_offset ==
    scroll_test_band_point(y=0.0),
  )
  let paint = view.paint(
    scroll_test_paint_context(
      child_frames=layout.child_frames,
      state=after_pull,
      now_ms=120.0,
    ),
  )
  assert_true(scroll_test_painted_shift(paint) is None)
}

///|
test "a horizontal pull past a horizontal clamp edge holds a band" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=500.0, height=100.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=500.0, height=100.0),
    ),
  )
  let after_down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Down),
      child_frames=layout.child_frames,
      now_ms=100.0,
    ),
  ).state.unwrap()
  let after_pull = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=450.0, y=50.0, phase=Move),
      child_frames=layout.child_frames,
      state=after_down,
      now_ms=120.0,
    ),
  ).state.unwrap()
  assert_true(
    after_pull.read_slot(scroll_drag_state_slot()).raw_offset ==
    scroll_test_band_point(x=0.0 - 400.0, y=0.0),
  )
  let paint = view.paint(
    scroll_test_paint_context(
      child_frames=layout.child_frames,
      state=after_pull,
      now_ms=120.0,
    ),
  )
  let shift = scroll_test_painted_shift(paint).unwrap()
  assert_true(scroll_test_close(left=shift.x, right=23.529411764705884))
  assert_true(shift.y == 0.0)
}

///|
test "a released band settles over frames and then stops" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let after_down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=80.0, phase=Down),
      child_frames=layout.child_frames,
      now_ms=100.0,
    ),
  ).state.unwrap()
  let after_pull = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=480.0, phase=Move),
      child_frames=layout.child_frames,
      state=after_down,
      now_ms=120.0,
    ),
  ).state.unwrap()
  let released = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=480.0, phase=Up),
      child_frames=layout.child_frames,
      state=after_pull,
      now_ms=400.0,
    ),
  )
  assert_true(released.changed)
  assert_true(released.dirty is ViewPaintDirty)
  let after_release = released.state.unwrap()
  assert_false(after_release.read_slot(scroll_drag_state_slot()).active)
  let motion = after_release.read_slot(scroll_motion_state_slot())
  assert_true(motion.anchor == scroll_test_band_point(y=0.0))
  assert_true(motion.start_time_ms == 400.0)
  assert_true(motion.duration.x == 0.0)
  // The rebound window scales with how much of the band was pulled: 94.1% of
  // the 25px extent earns 94.1% of the 160ms window.
  assert_true(
    scroll_test_close(left=motion.duration.y, right=150.58823529411765),
  )
  let band = 23.529411764705884
  // The frame that reacts to the release still shows the full pull. Snapping
  // here would be a visible jump at the moment the finger leaves the glass.
  let at_release = view.paint(
    scroll_test_paint_context(
      child_frames=layout.child_frames,
      state=after_release,
      now_ms=400.0,
    ),
  )
  assert_true(
    scroll_test_close(left=scroll_test_shift_y(at_release), right=band),
  )
  assert_true(at_release.animating)
  // Ease-out: halfway through the window a quarter of the band is left.
  let midway = view.paint(
    scroll_test_paint_context(
      child_frames=layout.child_frames,
      state=after_release,
      now_ms=400.0 + 150.58823529411765 / 2.0,
    ),
  )
  assert_true(
    scroll_test_close(left=scroll_test_shift_y(midway), right=band / 4.0),
  )
  assert_true(midway.animating)
  let settled = view.paint(
    scroll_test_paint_context(
      child_frames=layout.child_frames,
      state=after_release,
      now_ms=551.0,
    ),
  )
  assert_true(scroll_test_painted_shift(settled) is None)
  assert_false(settled.animating)
  assert_true(settled.post_commands == [PopClip])
}

///|
test "grabbing a settling band continues from where it looks" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let child_frames = [@core.Rect::new(x=0.0, y=0.0, width=100.0, height=500.0)]
  let settling = scroll_test_state_context().with_slot(
    scroll_motion_state_slot(),
    {
      anchor: scroll_test_band_point(y=0.0),
      start_time_ms: 400.0,
      duration: @core.Point::new(x=0.0, y=150.58823529411765),
      band: scroll_test_band_point(y=0.0 - 23.529411764705884),
    },
  )
  let before = view.paint(
    scroll_test_paint_context(child_frames~, state=settling, now_ms=420.0),
  )
  assert_true(before.animating)
  let grabbed = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Down),
      child_frames~,
      state=settling,
      now_ms=420.0,
    ),
  )
  assert_true(grabbed.changed)
  assert_true(grabbed.dirty is ViewPaintDirty)
  let after = grabbed.state.unwrap()
  assert_false(after.read_slot(scroll_drag_state_slot()).dragging)
  // The band is inverted back through the pull damping, so the drag resumes
  // from the pre-clamp offset that produces the *same* painted shift instead of
  // snapping the surface to the clamp under the finger.
  let after_grab = view.paint(
    scroll_test_paint_context(child_frames~, state=after, now_ms=420.0),
  )
  assert_true(
    scroll_test_close(
      left=scroll_test_shift_y(after_grab),
      right=scroll_test_shift_y(before),
    ),
  )
  let raw = after.read_slot(scroll_drag_state_slot()).raw_offset
  assert_true(raw.y < 0.0 && raw.y > -400.0)
}

///|
test "a frozen clock gets a plain release, not a band that cannot decay" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let child_frames = [@core.Rect::new(x=0.0, y=0.0, width=100.0, height=500.0)]
  let after_down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=80.0, phase=Down),
      child_frames~,
    ),
  ).state.unwrap()
  let after_pull = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=480.0, phase=Move),
      child_frames~,
      state=after_down,
    ),
  ).state.unwrap()
  // A held band does not depend on the clock, so it is painted as usual.
  assert_true(
    scroll_test_close(
      left=scroll_test_shift_y(
        view.paint(scroll_test_paint_context(child_frames~, state=after_pull)),
      ),
      right=23.529411764705884,
    ),
  )
  let released = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=480.0, phase=Up),
      child_frames~,
      state=after_pull,
    ),
  )
  assert_false(released.changed)
  assert_true(released.dirty is ViewClean)
  let after_release = released.state.unwrap()
  assert_true(
    after_release.read_slot(scroll_motion_state_slot()).band ==
    scroll_test_band_point(y=0.0),
  )
  let paint = view.paint(
    scroll_test_paint_context(child_frames~, state=after_release),
  )
  assert_true(scroll_test_painted_shift(paint) is None)
  assert_false(paint.animating)
}

///|
test "a wheel step takes over from a rebound and stays hard-clamped" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  let child_frames = [@core.Rect::new(x=0.0, y=0.0, width=100.0, height=500.0)]
  let settling = scroll_test_state_context()
    .with_slot(scroll_motion_state_slot(), {
      anchor: scroll_test_band_point(y=0.0),
      start_time_ms: 400.0,
      duration: @core.Point::new(x=0.0, y=150.0),
      band: scroll_test_band_point(y=0.0 - 20.0),
    })
    .with_slot(scroll_runtime_state_slot(), {
      offset: scroll_test_band_point(y=0.0),
      applied_request_id: -1,
    })
  let result = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_y=-40.0),
      child_frames~,
      state=settling,
      now_ms=420.0,
    ),
  )
  assert_true(result.dirty is ViewLayoutDirty)
  let after_wheel = result.state.unwrap()
  assert_true(
    after_wheel.read_slot(scroll_motion_state_slot()).band ==
    scroll_test_band_point(y=0.0),
  )
  assert_true(
    after_wheel.read_slot(scroll_runtime_state_slot()).offset ==
    scroll_test_band_point(y=40.0),
  )
  let paint = view.paint(
    scroll_test_paint_context(child_frames~, state=after_wheel, now_ms=420.0),
  )
  assert_true(scroll_test_painted_shift(paint) is None)
  assert_false(paint.animating)
}

///|
test "a wheel step at a clamped edge only drops the settling band" {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
  )
  // Already at the tail clamp, with a band in flight anchored there.
  let settling = scroll_test_state_context()
    .with_slot(scroll_runtime_state_slot(), {
      offset: scroll_test_band_point(y=400.0),
      applied_request_id: -1,
    })
    .with_slot(scroll_motion_state_slot(), {
      anchor: scroll_test_band_point(y=400.0),
      start_time_ms: 400.0,
      duration: @core.Point::new(x=0.0, y=150.0),
      band: scroll_test_band_point(y=0.0 - 20.0),
    })
  let result = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_y=-40.0),
      child_frames=[@core.Rect::new(x=0.0, y=-400.0, width=100.0, height=500.0)],
      state=settling,
      now_ms=420.0,
    ),
  )
  // The offset cannot move further, but the band has to go, so the frame is a
  // repaint rather than a no-op.
  assert_true(result.changed)
  assert_true(result.dirty is ViewPaintDirty)
  assert_true(result.messages.is_empty())
  assert_true(
    result.state.unwrap().read_slot(scroll_motion_state_slot()).band ==
    scroll_test_band_point(y=0.0),
  )
}

///|
test "scrollbar thumb and hit region derive from one track" {
  let frame = @core.Rect::new(x=20.0, y=10.0, width=100.0, height=200.0)
  let child_size = @core.Size::new(width=100.0, height=500.0)
  let thumb = scroll_indicator_thumb(
    frame,
    child_size,
    scroll_test_band_point(y=0.0),
  ).unwrap()
  // 20 + 100 - 4 (edge inset) - 3 (thumb width)
  assert_true(thumb.origin.x == 113.0)
  assert_true(thumb.size.width == 3.0)
  assert_true(thumb.origin.y == 14.0)
  assert_true(scroll_test_close(left=thumb.size.height, right=76.8))
  let at_tail = scroll_indicator_thumb(
    frame,
    child_size,
    scroll_test_band_point(y=999.0),
  ).unwrap()
  // The thumb spans the track: its bottom lands on the track end, which is the
  // frame bottom minus the same edge inset the track starts from.
  assert_true(
    scroll_test_close(left=at_tail.origin.y + at_tail.size.height, right=206.0),
  )
  // The grab region still reaches 9px left of the track, reproducing the
  // previous hardcoded 16px hit box without restating the thumb geometry.
  assert_true(
    scroll_indicator_track_x(frame) - scroll_indicator_hit_inset() == 104.0,
  )
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=100.0, height=500.0),
    viewport=Some(@core.Size::new(width=100.0, height=100.0)),
    shows_indicator=true,
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let on_bar = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=84.0, y=50.0, phase=Down),
      child_frames=layout.child_frames,
    ),
  )
  assert_true(on_bar.state.unwrap().read_slot(scroll_indicator_drag_slot()))
  let left_of_bar = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=83.0, y=50.0, phase=Down),
      child_frames=layout.child_frames,
    ),
  )
  assert_false(
    left_of_bar.state.unwrap().read_slot(scroll_indicator_drag_slot()),
  )
  assert_true(
    left_of_bar.state.unwrap().read_slot(scroll_drag_state_slot()).active,
  )
}

///|
test "scroll drag and motion codecs reject a corrupt sample" {
  let drag = ScrollDragState::{
    active: true,
    dragging: true,
    origin: scroll_test_band_point(x=1.5, y=0.0 - 2.25),
    last_position: scroll_test_band_point(x=3.0, y=4.5),
    raw_offset: scroll_test_band_point(x=0.0 - 6.125, y=7.0),
  }
  let motion = ScrollMotionState::{
    anchor: scroll_test_band_point(y=400.0),
    start_time_ms: 1234.5,
    duration: @core.Point::new(x=0.0, y=150.58823529411765),
    band: scroll_test_band_point(y=0.0 - 23.529411764705884),
  }
  let drag_bytes = @core.ViewStateValue::encode_view_state(drag)
  let motion_bytes = @core.ViewStateValue::encode_view_state(motion)
  assert_true(drag_bytes.length() == 50)
  assert_true(motion_bytes.length() == 56)
  let drag_again = @core.ViewStateValue::decode_view_state(drag, drag_bytes).unwrap()
  assert_true(drag_again.active && drag_again.dragging)
  assert_true(drag_again.origin == scroll_test_band_point(x=1.5, y=0.0 - 2.25))
  assert_true(drag_again.last_position == scroll_test_band_point(x=3.0, y=4.5))
  assert_true(
    drag_again.raw_offset == scroll_test_band_point(x=0.0 - 6.125, y=7.0),
  )
  let motion_again = @core.ViewStateValue::decode_view_state(
    motion, motion_bytes,
  ).unwrap()
  assert_true(motion_again.anchor == scroll_test_band_point(y=400.0))
  assert_true(motion_again.start_time_ms == 1234.5)
  assert_true(
    motion_again.duration == @core.Point::new(x=0.0, y=150.58823529411765),
  )
  assert_true(
    motion_again.band == scroll_test_band_point(y=0.0 - 23.529411764705884),
  )
  // A truncated or foreign sample is rejected rather than decoded into a
  // plausible-looking drag: falling back to the initial value (no drag in
  // progress) is the only safe reading of bytes this control did not write.
  assert_true(
    @core.ViewStateValue::decode_view_state(drag, drag_bytes[0:49].to_owned())
    is None,
  )
  assert_true(
    @core.ViewStateValue::decode_view_state(drag, motion_bytes) is None,
  )
  assert_true(
    @core.ViewStateValue::decode_view_state(motion, drag_bytes) is None,
  )
  let corrupt = Buffer(size_hint=50)
  corrupt.write_byte(1)
  corrupt.write_byte(2)
  corrupt.write_double_be(1.5)
  corrupt.write_double_be(0.0 - 2.25)
  corrupt.write_double_be(3.0)
  corrupt.write_double_be(4.5)
  corrupt.write_double_be(0.0 - 6.125)
  corrupt.write_double_be(7.0)
  assert_true(
    @core.ViewStateValue::decode_view_state(drag, corrupt.to_bytes()) is None,
  )
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
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Down),
      child_frames=layout.child_frames,
      state=initial,
    ),
  )
  let after_down = down.state.unwrap_or(initial)
  let moved = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=20.0, phase=Move),
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
      event=scroll_test_pointer(x=50.0, y=20.0, phase=Up),
      child_frames=layout.child_frames,
      state=after_move,
    ),
  ).state.unwrap_or(after_move)
  assert_false(released.read_slot(scroll_drag_state_slot()).active)
}
