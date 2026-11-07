///|
/// White-box coverage for the `refresh_indicator`: the arm/trigger/release
/// state machine, the snap-back, the refreshing spinner latch, and the
/// semantics activation path. Pull probes use the surface's own coordinates
/// (300x400 in these fixtures) with the default 64px trigger.

///|
fn refresh_test_state() -> @core.ViewStateContext {
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
fn refresh_test_event_context(
  event~ : @core.AppEvent,
  state~ : @core.ViewStateContext = refresh_test_state(),
  now_ms~ : Double = 0.0,
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=300.0, height=400.0),
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
    now_ms,
  }
}

///|
fn refresh_test_pointer(
  x~ : Double,
  y~ : Double,
  phase~ : @core.PointerPhase,
) -> @core.AppEvent {
  Pointer(@core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~))
}

///|
fn refresh_test_view(refreshing~ : Bool = false) -> @core.View[Bool] {
  refresh_indicator(
    refreshing~,
    on_refresh=true,
    child=(@text.text("content") : @core.View[Bool]),
  )
}

///|
fn refresh_test_action_context() -> @core.ViewSemanticsActionContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=300.0, height=400.0),
    child_frames: [],
    focused: false,
    state: refresh_test_state(),
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
  }
}

///|
test "an armed release emits on_refresh exactly once" {
  let view : @core.View[Bool] = refresh_test_view()
  let down = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=200.0, phase=Down),
    ),
  )
  assert_true(down.captured)
  // A 300px raw pull damps to ~72.7px, past the 64px trigger.
  let drag = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=500.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  assert_true(drag.changed)
  let up = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=500.0, phase=Up),
      state=drag.state.unwrap(),
    ),
  )
  assert_true(up.activated)
  assert_true(up.messages.length() == 1)
}

///|
test "a short pull snaps back without refreshing" {
  let view : @core.View[Bool] = refresh_test_view()
  let down = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=200.0, phase=Down),
    ),
  )
  // A 40px raw pull damps to ~28px, under the trigger.
  let drag = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=240.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  assert_true(drag.changed)
  let up = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=240.0, phase=Up),
      state=drag.state.unwrap(),
    ),
  )
  assert_true(up.changed)
  assert_false(up.activated)
  assert_true(up.messages.length() == 0)
}

///|
test "an upward travel pulls nothing and the surface ignores capture while refreshing" {
  let view : @core.View[Bool] = refresh_test_view()
  // An upward drag never arms: the offset stays at zero and the move is
  // not even reported as changed.
  let down = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=200.0, phase=Down),
    ),
  )
  let drag = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=100.0, phase=Move),
      state=down.state.unwrap(),
    ),
  )
  assert_false(drag.changed)
  let up = view.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=100.0, phase=Up),
      state=down.state.unwrap(),
    ),
  )
  ignore(up)
  // While refreshing the surface takes no new pull.
  let refreshing : @core.View[Bool] = refresh_test_view(refreshing=true)
  let refreshing_down = refreshing.event(
    refresh_test_event_context(
      event=refresh_test_pointer(x=150.0, y=200.0, phase=Down),
    ),
  )
  assert_false(refreshing_down.captured)
}

///|
test "the spinner latches frames while refreshing and the arc grows with the pull" {
  // Refreshing: the paint plan reports animating (the host keeps ticking the
  // rotation) and the indicator arc is on the command list.
  let refreshing : @core.View[Bool] = refresh_test_view(refreshing=true)
  let paint = refreshing.paint({
    frame: @core.Rect::new(x=0.0, y=0.0, width=300.0, height=400.0),
    child_frames: [@core.Rect::new(x=0.0, y=0.0, width=300.0, height=400.0)],
    focused: false,
    state: refresh_test_state(),
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
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms: 500.0,
  })
  assert_true(paint.animating)
  let mut arc_commands = 0
  for command in paint.commands {
    match command {
      DrawPath(_) => arc_commands = arc_commands + 1
      _ => ()
    }
  }
  assert_true(arc_commands == 1)
  // Idle with no pull: no indicator, no latch.
  let idle : @core.View[Bool] = refresh_test_view()
  let idle_paint = idle.paint({
    frame: @core.Rect::new(x=0.0, y=0.0, width=300.0, height=400.0),
    child_frames: [@core.Rect::new(x=0.0, y=0.0, width=300.0, height=400.0)],
    focused: false,
    state: refresh_test_state(),
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
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms: 0.0,
  })
  assert_false(idle_paint.animating)
  for command in idle_paint.commands {
    match command {
      DrawPath(_) => fail("idle surface must not draw the indicator arc")
      _ => ()
    }
  }
}

///|
test "semantics activation triggers the refresh and rejects while refreshing" {
  let view : @core.View[Bool] = refresh_test_view()
  let result = view.dispatch_semantics_action(
    refresh_test_action_context(),
    Activate,
  )
  assert_true(result.accepted)
  assert_true(result.messages.length() == 1)
  let refreshing : @core.View[Bool] = refresh_test_view(refreshing=true)
  let rejected = refreshing.dispatch_semantics_action(
    refresh_test_action_context(),
    Activate,
  )
  assert_false(rejected.accepted)
}

///|
test "the pull offset damps and never passes one and a half triggers" {
  // The saturating curve: a 1000px raw pull damps below 1.5 * 64 = 96.
  let offset = refresh_pull_offset(1000.0, trigger=64.0)
  assert_true(offset < 96.0 && offset > 64.0)
  // Zero raw travel pulls nothing.
  inspect(refresh_pull_offset(0.0, trigger=64.0), content="0")
  // Negative (upward) raw travel pulls nothing.
  inspect(refresh_pull_offset(0.0 - 50.0, trigger=64.0), content="0")
}

///|
test "refresh indicator lays out clipped with one child frame" {
  let view : @core.View[Bool] = refresh_test_view()
  let layout = view.layout({
    constraints: @core.Constraints::tight(
      @core.Size::new(width=300.0, height=400.0),
    ),
    child_sizes: [@core.Size::new(width=300.0, height=400.0)],
    child_flex_weights: [0.0],
    state: refresh_test_state(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  })
  assert_true(layout.size.width == 300.0)
  assert_true(layout.child_frames.length() == 1)
  assert_true(layout.clips_children)
}
