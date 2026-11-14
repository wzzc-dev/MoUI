///|
pub using @style {type ButtonVariant}

///|
fn button_test_rest_state() -> @core.ViewStateContext {
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
fn button_test_paint_context(
  state : @core.ViewStateContext,
  now_ms : Double,
  environment? : @core.Environment,
) -> @core.ViewPaintContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=40.0),
    child_frames: [],
    focused: false,
    state,
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
      goal_column: None,
      reveal: None,
    },
    environment: environment.unwrap_or(@core.Environment::neutral()),
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms,
  }
}

///|
test "button exposes role label and identity" {
  let btn : @core.View[Unit] = @button.button("Submit", on_click=())
  let info = btn.semantics()
  assert_true(info.role == Some(Button))
  assert_eq(info.label, Some("Submit"))
  assert_eq(btn.identity().kind, "Button")
}

///|
test "button variants all produce valid views" {
  for
    variant in [
      ButtonVariant::Primary,
      Ghost,
      Outline,
      Subtle,
      SubtleBrand,
      Tonal,
    ] {
    let btn : @core.View[Unit] = @button.button("Action", on_click=(), variant~)
    assert_true(btn.semantics().role == Some(Button))
    assert_eq(btn.identity().kind, "Button")
  }
}

///|
test "button latches a clock-zero transition for the first real tick" {
  let state = @common.pressable_state_with_transition(
    button_test_rest_state(),
    @core.PressableState::Normal,
    @core.PressableState::Pressed,
    0.0,
    control="button",
  )
  let btn : @core.View[Unit] = @button.button("Submit", on_click=())
  // A transition recorded before the host clock starts must stay animating:
  // returning a static terminal sample here would cache away the first tick.
  assert_true(btn.paint(button_test_paint_context(state, 0.0)).animating)
  assert_true(btn.paint(button_test_paint_context(state, 16.0)).animating)
  assert_false(btn.paint(button_test_paint_context(state, 1000.0)).animating)
}

///|
/// Build a layout context whose environment carries `theme`, so a control
/// resolves the same ambient tokens a running app would.
fn button_test_layout_context(
  theme : @core.Theme,
  constraints~ : @core.Constraints,
) -> @core.ViewLayoutContext {
  {
    constraints,
    child_sizes: [],
    child_flex_weights: [],
    state: button_test_rest_state(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_theme(theme),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn button_test_desktop_theme() -> @core.Theme {
  @core.resolve_desktop_theme(@core.ThemeSpec::desktop_light(), @core.Light)
}

///|
test "button height follows the layout scale and hugs its width" {
  let constraints = @core.Constraints::loose(
    @core.Size::new(width=400.0, height=400.0),
  )
  let btn : @core.View[Unit] = @button.button("Save", on_click=())
  let minimal_size = btn.layout(
    button_test_layout_context(@core.Theme::neutral(), constraints~),
  )
  assert_eq(minimal_size.size.height, 40.0)
  let desktop_size = btn.layout(
    button_test_layout_context(button_test_desktop_theme(), constraints~),
  )
  assert_eq(desktop_size.size.height, 32.0)
  // Hug: the default no longer carries a 100 px minimum width.
  assert_true(desktop_size.size.width < 100.0)
}

///|
test "explicit button height still wins over the preset metric" {
  let constraints = @core.Constraints::loose(
    @core.Size::new(width=400.0, height=400.0),
  )
  let btn : @core.View[Unit] = @button.button("Save", on_click=(), height=48.0)
  let size = btn.layout(
    button_test_layout_context(button_test_desktop_theme(), constraints~),
  )
  assert_eq(size.size.height, 48.0)
}

///|
fn button_test_first_background_color(
  plan : @core.ViewPaintPlan,
) -> @core.Color {
  match plan.commands[0] {
    @core.FillRoundedRectBrush(_, brush) => brush.fallback_color()
    _ => abort("expected FillRoundedRectBrush")
  }
}

///|
test "button hover transition blends between resting and hovered" {
  let btn : @core.View[Unit] = @button.button("Submit", on_click=())
  // Use the spec (not a pinned theme) so `with_reduced_motion` rebuilds the
  // same Desktop preset instead of falling back to Minimal.
  let environment = @core.Environment::neutral().with_theme_spec(
    @core.ThemeSpec::desktop_light(),
  )
  let resting = button_test_rest_state()
  let hovered = { ..resting, hovered: true, }
  let mid_state = @common.pressable_state_with_transition(
    resting,
    @core.PressableState::Normal,
    @core.PressableState::Hovered,
    0.0,
    control="button",
  )
  let resting_color = button_test_first_background_color(
    btn.paint(button_test_paint_context(resting, 0.0, environment~)),
  )
  let hovered_color = button_test_first_background_color(
    btn.paint(button_test_paint_context(hovered, 0.0, environment~)),
  )
  let mid_color = button_test_first_background_color(
    btn.paint(button_test_paint_context(mid_state, 60.0, environment~)),
  )
  assert_true(mid_color != resting_color)
  assert_true(mid_color != hovered_color)
  // Reduced motion snaps to the terminal color immediately.
  let base_context = button_test_paint_context(mid_state, 60.0, environment~)
  let reduced_context = {
    ..base_context,
    environment: base_context.environment.with_reduced_motion(true),
  }
  let reduced_color = button_test_first_background_color(
    btn.paint(reduced_context),
  )
  assert_true(reduced_color == hovered_color)
}
