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
    environment: @core.Environment::neutral(),
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
