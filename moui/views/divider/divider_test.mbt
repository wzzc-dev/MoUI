// Unit tests for ambient divider color resolution in moui/views/divider.
//
// A divider without an explicit color/theme pins nothing at declaration time:
// the hairline resolves against `ctx.environment.theme.palette.outline_variant`
// at paint time, matching the button/text ambient contract. Explicit colors and
// explicit themes stay pinned deterministically.

///|
fn divider_test_state() -> @core.ViewStateContext {
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
fn divider_test_text_control() -> @core.TextControlStateContext {
  {
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    goal_column: None,
    text_selection_origin: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn divider_paint_context(
  frame~ : @core.Rect,
  theme~ : @core.Theme,
) -> @core.ViewPaintContext {
  {
    frame,
    child_frames: [],
    focused: false,
    state: divider_test_state(),
    text_control: divider_test_text_control(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_theme(theme),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
/// Minimal dark/light themes built from the core resolver (the divider
/// package does not depend on the style package).
fn divider_dark_theme() -> @core.Theme {
  @core.resolve_minimal_theme(@core.ThemeSpec::minimal_dark(), Dark)
}

///|
fn divider_light_theme() -> @core.Theme {
  @core.resolve_minimal_theme(@core.ThemeSpec::minimal_light(), Light)
}

///|
test "ambient divider paints the environment theme's outline_variant" {
  let dark = divider_dark_theme()
  let view : @core.View[Unit] = @divider.divider()
  let frame = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=1.0)
  let plan = view.paint(divider_paint_context(frame~, theme=dark))
  assert_true(
    plan.commands ==
    [@core.DrawCommand::FillRect(frame, dark.palette.outline_variant)],
  )
}

///|
test "ambient divider follows a light environment without rebuild" {
  let light = divider_light_theme()
  let view : @core.View[Unit] = @divider.divider()
  let frame = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=1.0)
  let plan = view.paint(divider_paint_context(frame~, theme=light))
  assert_true(
    plan.commands ==
    [@core.DrawCommand::FillRect(frame, light.palette.outline_variant)],
  )
}

///|
test "explicit divider color stays pinned" {
  let dark = divider_dark_theme()
  let pinned_color = @core.Color::rgba(r=0.2, g=0.4, b=0.8)
  let view : @core.View[Unit] = @divider.divider(color=pinned_color)
  let frame = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=1.0)
  let plan = view.paint(divider_paint_context(frame~, theme=dark))
  assert_true(
    plan.commands == [@core.DrawCommand::FillRect(frame, pinned_color)],
  )
}

///|
test "explicit divider theme stays pinned" {
  let dark = divider_dark_theme()
  let view : @core.View[Unit] = @divider.divider(theme=dark)
  let frame = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=1.0)
  let plan = view.paint(
    divider_paint_context(frame~, theme=divider_light_theme()),
  )
  // The declaration-time theme wins even when the environment differs.
  assert_true(
    plan.commands ==
    [@core.DrawCommand::FillRect(frame, dark.palette.outline_variant)],
  )
}
