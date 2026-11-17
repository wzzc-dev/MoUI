///|
/// Issue #24 regression coverage for the Linux client-side-decoration titlebar.
///
/// These are pure hit-test/paint-geometry tests: they prove the painted button
/// slots and the clickable regions are the same rectangle, and that the band no
/// longer silently drops input. A Wayland compositor round-trip still needs a
/// matching-host smoke (recorded as a limitation, not claimed here).

///|
fn linux_titlebar_test_decorations() -> @linux.LinuxClientDecorationState {
  @linux.LinuxClientDecorationState::new(active=true)
}

///|
test "titlebar buttons are clickable across their whole slot" {
  let width = 400.0
  let close = @linux.linux_titlebar_button_slot_rect(width, 0)
  let maximize = @linux.linux_titlebar_button_slot_rect(width, 1)
  let minimize = @linux.linux_titlebar_button_slot_rect(width, 2)
  // Slots sit right-to-left with an 8pt gap between them and never overlap.
  assert_true(close.origin.x > maximize.origin.x)
  assert_true(maximize.origin.x > minimize.origin.x)
  assert_true(
    minimize.origin.x + minimize.size.width + 8.0 <= maximize.origin.x,
  )
  assert_true(maximize.origin.x + maximize.size.width + 8.0 <= close.origin.x)
  assert_true(close.origin.x + close.size.width <= width)

  // Any point inside a slot resolves to that button, not just the painted dot.
  let slot_center = @core.Point::new(
    x=close.origin.x + close.size.width / 2.0,
    y=16.0,
  )
  assert_eq(
    @linux.linux_titlebar_button_at(width, slot_center),
    Some(@linux.LinuxTitlebarButton::Close),
  )
  let slot_edge = @core.Point::new(x=close.origin.x + 1.0, y=2.0)
  assert_eq(
    @linux.linux_titlebar_button_at(width, slot_edge),
    Some(@linux.LinuxTitlebarButton::Close),
  )
}

///|
test "titlebar presses issue button actions, body drags, content passes" {
  let decorations = linux_titlebar_test_decorations()
  let width = 400.0
  let close = @linux.linux_titlebar_button_slot_rect(width, 0)
  let close_point = @core.Point::new(
    x=close.origin.x + close.size.width / 2.0,
    y=16.0,
  )

  // Press on the close slot: remembered, not yet acted on.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      close_point,
      @core.PointerPhase::Down,
      0,
      None,
    ),
    @linux.LinuxTitlebarAction::Press(@linux.LinuxTitlebarButton::Close),
  )
  // Release on the same slot completes the click.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      close_point,
      @core.PointerPhase::Up,
      0,
      Some(@linux.LinuxTitlebarButton::Close),
    ),
    @linux.LinuxTitlebarAction::Activate(@linux.LinuxTitlebarButton::Close),
  )
  // Releasing elsewhere in the band cancels instead of activating.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      @core.Point::new(x=20.0, y=16.0),
      @core.PointerPhase::Up,
      0,
      Some(@linux.LinuxTitlebarButton::Close),
    ),
    @linux.LinuxTitlebarAction::Consume,
  )

  // The titlebar body is a native window drag target.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      @core.Point::new(x=20.0, y=16.0),
      @core.PointerPhase::Down,
      0,
      None,
    ),
    @linux.LinuxTitlebarAction::Drag,
  )

  // Pointer moves over the band are swallowed so content under the chrome does
  // not keep a stale hover.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      @core.Point::new(x=20.0, y=16.0),
      @core.PointerPhase::Move,
      0,
      None,
    ),
    @linux.LinuxTitlebarAction::Consume,
  )

  // Below the band the event belongs to the app.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      @core.Point::new(x=20.0, y=40.0),
      @core.PointerPhase::Down,
      0,
      None,
    ),
    @linux.LinuxTitlebarAction::Pass,
  )

  // An inactive CSD state passes everything, including the band.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      @linux.LinuxClientDecorationState::new(active=false),
      width,
      close_point,
      @core.PointerPhase::Down,
      0,
      None,
    ),
    @linux.LinuxTitlebarAction::Pass,
  )

  // Secondary clicks on the band are consumed but never drag the window.
  assert_eq(
    @linux.linux_titlebar_pointer_action(
      decorations,
      width,
      @core.Point::new(x=20.0, y=16.0),
      @core.PointerPhase::Down,
      2,
      None,
    ),
    @linux.LinuxTitlebarAction::Consume,
  )
}
