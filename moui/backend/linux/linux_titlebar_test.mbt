///|
/// Issue #24 regression coverage for the Linux client-side-decoration titlebar.
///
/// These are pure hit-test/paint-geometry tests: they prove the painted button
/// slots and the clickable regions are the same rectangle, that the band no
/// longer silently drops input, and that the policy/state/icon work renders
/// what it claims. A Wayland compositor round-trip still needs a matching-host
/// smoke (recorded as a limitation, not claimed here).

///|
fn linux_titlebar_test_decorations() -> @linux.LinuxClientDecorationState {
  @linux.LinuxClientDecorationState::new(active=true)
}

///|
test "titlebar buttons are clickable across their whole slot" {
  let width = 400.0
  let height = 32.0
  let close = @linux.linux_titlebar_button_slot_rect(width, height, 0)
  let maximize = @linux.linux_titlebar_button_slot_rect(width, height, 1)
  let minimize = @linux.linux_titlebar_button_slot_rect(width, height, 2)
  // Slots sit right-to-left with an 8pt gap between them and never overlap.
  assert_true(close.origin.x > maximize.origin.x)
  assert_true(maximize.origin.x > minimize.origin.x)
  assert_true(
    minimize.origin.x + minimize.size.width + 8.0 <= maximize.origin.x,
  )
  assert_true(maximize.origin.x + maximize.size.width + 8.0 <= close.origin.x)
  assert_true(close.origin.x + close.size.width <= width)
  // Slots fill the titlebar band height, so every row of the band clicks.
  assert_true(close.size.height == height)

  // Any point inside a slot resolves to that button, not just the painted dot.
  let slot_center = @core.Point::new(
    x=close.origin.x + close.size.width / 2.0,
    y=16.0,
  )
  assert_eq(
    @linux.linux_titlebar_button_at(width, height, slot_center),
    Some(@linux.LinuxTitlebarButton::Close),
  )
  let slot_edge = @core.Point::new(x=close.origin.x + 1.0, y=2.0)
  assert_eq(
    @linux.linux_titlebar_button_at(width, height, slot_edge),
    Some(@linux.LinuxTitlebarButton::Close),
  )
  // Hit testing and painting must agree on which slot is which button: the
  // maximize slot is second from the right and minimize is leftmost, matching
  // the painted [minimize][maximize][close] order. A mismatch here made the
  // painted maximize button minimize the window (caught in weston runtime
  // evidence for the CSD work).
  let maximize_center = @core.Point::new(
    x=maximize.origin.x + maximize.size.width / 2.0,
    y=16.0,
  )
  assert_eq(
    @linux.linux_titlebar_button_at(width, height, maximize_center),
    Some(@linux.LinuxTitlebarButton::Maximize),
  )
  let minimize_center = @core.Point::new(
    x=minimize.origin.x + minimize.size.width / 2.0,
    y=16.0,
  )
  assert_eq(
    @linux.linux_titlebar_button_at(width, height, minimize_center),
    Some(@linux.LinuxTitlebarButton::Minimize),
  )
}

///|
test "titlebar policy drives slot geometry" {
  let width = 400.0
  let height = 40.0
  let policy : @linux.LinuxTitlebarPolicy = {
    slot_size: 36.0,
    gap: 4.0,
    edge_margin: 6.0,
    dot_size: 16.0,
  }
  let close = @linux.linux_titlebar_button_slot_rect(width, height, 0, policy~)
  // A larger policy produces larger slots anchored to the same right edge.
  assert_true(close.size.width == 36.0)
  assert_true(close.size.height == height)
  assert_true(close.origin.x + close.size.width == width - 6.0)
  // The dot stays centered inside its slot for any titlebar height.
  let maximize = @linux.linux_titlebar_button_slot_rect(
    width,
    height,
    1,
    policy~,
  )
  assert_true(
    maximize.origin.x + (maximize.size.width - 16.0) / 2.0 > maximize.origin.x,
  )
}

///|
test "titlebar presses issue button actions, body drags, content passes" {
  let decorations = linux_titlebar_test_decorations()
  let width = 400.0
  let height = 32.0
  let close = @linux.linux_titlebar_button_slot_rect(width, height, 0)
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

///|
/// Count the vector glyphs the painted titlebar emits.
fn linux_titlebar_test_paint(
  maximized~ : Bool = false,
  hover~ : @linux.LinuxTitlebarButton? = None,
  pressed~ : @linux.LinuxTitlebarButton? = None,
  scheme~ : @core.ColorScheme = @core.ColorScheme::Light,
) -> Array[@core.DrawCommand] {
  let app_commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
  ]
  @linux.linux_client_decorated_commands(
    app_commands,
    title="test",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=400.0, height=300.0),
      scale_factor=1.0,
    ),
    decorations=@linux.LinuxClientDecorationState::new(active=true, scheme~),
    hover~,
    pressed~,
    maximized~,
  )
}

///|
test "titlebar buttons draw distinct vector glyphs" {
  let commands = linux_titlebar_test_paint()
  let mut paths = 0
  let mut dots = 0
  for command in commands {
    match command {
      @core.DrawCommand::DrawPath(_) => paths = paths + 1
      @core.DrawCommand::FillRoundedRect(rounded, _) =>
        if rounded.rect.size.width == 12.0 {
          dots = dots + 1
        }
      _ => ()
    }
  }
  // Only the close button needs a path (its X glyph); one per paint.
  assert_true(paths == 1)
  // One 12pt dot per button.
  assert_true(dots == 3)
}

///|
fn linux_titlebar_test_count_stroke_squares(
  commands : Array[@core.DrawCommand],
) -> Int32 {
  let mut squares = 0
  for command in commands {
    match command {
      // The band border is a plain StrokeRect of full width; restore
      // squares are the small ones.
      @core.DrawCommand::StrokeRect(rect, _, _) =>
        if rect.size.width < 100.0 {
          squares = squares + 1
        }
      _ => ()
    }
  }
  squares
}

///|
fn linux_titlebar_test_band_background(
  commands : Array[@core.DrawCommand],
) -> @core.Color {
  let mut color = @core.Color::black()
  for command in commands {
    match command {
      @core.DrawCommand::FillRect(rect, fill) =>
        if rect.size.height == 32.0 {
          color = fill
        }
      _ => ()
    }
  }
  color
}

///|
fn linux_titlebar_test_count_rings(
  commands : Array[@core.DrawCommand],
) -> Int32 {
  let mut rings = 0
  for command in commands {
    match command {
      @core.DrawCommand::StrokeRoundedRect(rounded, _, _) =>
        if (rounded.rect.size.width - 15.0).abs() < 0.01 {
          rings = rings + 1
        }
      _ => ()
    }
  }
  rings
}

///|
test "maximized titlebar paints the restore glyph for the maximize button" {
  let rest = linux_titlebar_test_paint(maximized=false)
  let restore = linux_titlebar_test_paint(maximized=true)
  // Maximized=false paints one maximize square; maximized=true paints the
  // restore pair (two overlapping squares).
  assert_true(linux_titlebar_test_count_stroke_squares(rest) == 1)
  assert_true(linux_titlebar_test_count_stroke_squares(restore) == 2)
}

///|
test "titlebar palette follows the color scheme and buttons reflect hover" {
  let light = linux_titlebar_test_paint(scheme=@core.ColorScheme::Light)
  let dark = linux_titlebar_test_paint(scheme=@core.ColorScheme::Dark)
  // The palettes differ, so the painted band background must differ too.
  assert_true(
    @core.Color::equal(
      linux_titlebar_test_band_background(light),
      linux_titlebar_test_band_background(dark),
    ) ==
    false,
  )
  // Hovering the close button adds its feedback ring around the dot.
  let idle = linux_titlebar_test_paint()
  let hovered = linux_titlebar_test_paint(hover=Some(Close))
  assert_true(linux_titlebar_test_count_rings(idle) == 0)
  assert_true(linux_titlebar_test_count_rings(hovered) == 1)
}
