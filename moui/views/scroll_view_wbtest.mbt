///|
fn scroll_test_rect(width~ : Double, height~ : Double) -> @core.View[Unit] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="ScrollTestRect"),
    revision=() => "scroll-test-rect:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
  )
}

///|
fn scroll_test_layout_context(
  child_size~ : @core.Size,
) -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::tight(
      @core.Size::new(width=100.0, height=100.0),
    ),
    child_sizes: [child_size],
    child_flex_weights: [0.0],
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
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
    scratch: "",
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
test "scroll wheel starts from clamped visual offset after auto-scroll overshoots" {
  let state = @core.ScrollState::new(offset=@core.Point::new(x=0.0, y=999.0))
  let view = scroll_view(
    scroll_test_rect(width=100.0, height=500.0),
    state=Some(state),
    width=100.0,
    height=100.0,
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
  let result = view.event({
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames: layout.child_frames,
    event: @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=40.0),
      ),
    ),
    focused: false,
    state: scroll_test_state_context(),
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  })
  assert_true(result.captured)
  assert_true(state.offset() == @core.Point::new(x=0.0, y=360.0))
}

///|
test "scroll wheel at a clamped edge does not dirty or capture" {
  let state = @core.ScrollState::new(offset=@core.Point::new(x=0.0, y=400.0))
  let view = scroll_view(
    scroll_test_rect(width=100.0, height=500.0),
    state=Some(state),
    width=100.0,
    height=100.0,
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let result = view.event({
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames: layout.child_frames,
    event: @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-40.0),
      ),
    ),
    focused: false,
    state: scroll_test_state_context(),
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  })
  assert_false(result.changed)
  assert_false(result.captured)
  assert_true(result.dirty is @core.ViewDirtyHint::ViewClean)
  assert_true(state.offset() == @core.Point::new(x=0.0, y=400.0))
}

///|
test "scroll indicator is opt-in and draggable" {
  let state = @core.ScrollState::new()
  let view = scroll_view(
    scroll_test_rect(width=100.0, height=500.0),
    state=Some(state),
    width=100.0,
    height=100.0,
    shows_indicator=true,
  )
  let layout = view.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let paint = view.paint({
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
  let result = view.event({
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames: layout.child_frames,
    event: @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=98.0, y=80.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
    focused: false,
    state: scroll_test_state_context(),
    text_control: scroll_test_text_control_context(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  })
  assert_true(result.captured)
  assert_true(state.offset().y > 0.0)
  let hidden = scroll_view(
    scroll_test_rect(width=100.0, height=500.0),
    state=Some(@core.ScrollState::new()),
    width=100.0,
    height=100.0,
  )
  let hidden_layout = hidden.layout(
    scroll_test_layout_context(
      child_size=@core.Size::new(width=100.0, height=500.0),
    ),
  )
  let hidden_paint = hidden.paint({
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    child_frames: hidden_layout.child_frames,
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
test "lazy grid forwards its scroll indicator policy" {
  let root : @core.View[Unit] = lazy_grid(
    [0, 1, 2, 3, 4],
    item => "item-\{item}",
    _item => scroll_test_rect(width=100.0, height=100.0),
    columns=1,
    item_height=100.0,
    viewport_width=100.0,
    viewport_height=100.0,
    shows_indicator=true,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_true(
    runtime
    .draw_commands()
    .any(command => command is @core.DrawCommand::FillRoundedRectBrush(_)),
  )
}

///|
test "lazy grid rebuilds its virtual window after scrolling" {
  let state = @core.ScrollState::new()
  let root : @core.View[Unit] = lazy_grid(
    ["row-0", "row-1", "row-2", "row-3", "row-4"],
    item => item,
    item => text(item, width=100.0, height=100.0),
    state~,
    columns=1,
    item_height=100.0,
    viewport_width=100.0,
    viewport_height=100.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_false(scroll_test_has_text(runtime.draw_commands(), "row-4"))
  state.scroll_to(x=0.0, y=300.0)
  assert_true(scroll_test_has_text(runtime.draw_commands(), "row-4"))
}

///|
test "lazy list rebuilds its virtual window after scrolling" {
  let state = @core.ScrollState::new()
  let root : @core.View[Unit] = lazy_list(
    ["row-0", "row-1", "row-2", "row-3", "row-4"],
    item => item,
    item => text(item, width=100.0, height=100.0),
    state~,
    item_height=100.0,
    viewport_height=100.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_false(scroll_test_has_text(runtime.draw_commands(), "row-4"))
  state.scroll_to(x=0.0, y=300.0)
  assert_true(scroll_test_has_text(runtime.draw_commands(), "row-4"))
}

///|
test "virtual list rebuilds its virtual window after scrolling" {
  let state = @core.ScrollState::new()
  let root : @core.View[Unit] = virtual_list(
    ["row-0", "row-1", "row-2", "row-3", "row-4"],
    item => item,
    item => text(item, width=100.0, height=100.0),
    state~,
    item_height=100.0,
    viewport_height=100.0,
    overscan=0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_false(scroll_test_has_text(runtime.draw_commands(), "row-4"))
  state.scroll_to(x=0.0, y=300.0)
  assert_true(scroll_test_has_text(runtime.draw_commands(), "row-4"))
}

///|
fn scroll_test_has_text(
  commands : Array[@core.DrawCommand],
  value : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text, .. }) && text == value
  })
}
