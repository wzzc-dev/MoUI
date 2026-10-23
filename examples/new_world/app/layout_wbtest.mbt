///|
/// `Layout` and `Screen`: the two-column shell's proportions, the stage's
/// reading cap, and the viewport fallbacks.

///|
test "the default layout is the two-column shell" {
  let layout = Layout::default()
  assert_eq(layout.rail_width, 300.0)
  assert_eq(layout.stage_max, 760.0)
  // 300 + 760 + one 20px gutter.
  assert_eq(layout.content_width(), 1080.0)
}

///|
test "for_width keeps the proportions and fills the target" {
  let wide = Layout::for_width(1600.0)
  // Floating point: 1600 reconstructed through three multiplications and a
  // sum lands within 1e-9, not exactly. Compare with a tolerance — the
  // invariant is "fills the target", not "bit-identical".
  assert_true((wide.content_width() - 1600.0).abs() < 1.0e-9)
  // Ratios preserved: the stage is the largest column.
  assert_true(wide.rail_width < wide.stage_max)
  // A narrow panel shrinks every column but keeps them positive.
  let narrow = Layout::for_width(600.0)
  assert_true((narrow.content_width() - 600.0).abs() < 1.0e-9)
  assert_true(narrow.stage_max > 0.0)
  assert_true(narrow.rail_width > 0.0)
}

///|
test "for_width falls back to the default on a degenerate width" {
  // A zero or negative target is a caller bug; returning the default is safer
  // than dividing by zero and producing NaN widths.
  assert_eq(Layout::for_width(0.0).content_width(), 1080.0)
  assert_eq(Layout::for_width(-10.0).content_width(), 1080.0)
}

///|
test "the breakpoints pick wide, medium, and compact by width alone" {
  let wide = Screen::for_viewport(1600.0, 900.0)
  assert_eq(wide.mode, Wide)
  // The wide block keeps its designed column widths when there is room to
  // spare, so a 2,500px monitor does not stretch a dialogue line.
  assert_eq(wide.rail, 300.0)
  assert_eq(wide.stage, 760.0)

  let medium = Screen::for_viewport(900.0, 700.0)
  assert_eq(medium.mode, Medium)
  // Medium has no permanent rail: the stage takes the width, and the rail is
  // a toggleable column.
  assert_true(medium.stage > medium.rail)
  assert_eq(medium.rail, 300.0)

  let phone = Screen::for_viewport(390.0, 844.0)
  assert_eq(phone.mode, Compact)
  // A portrait phone gets the full width for the stage: a 300px rail next to
  // a 40px conversation would be unusable.
  assert_eq(phone.rail, 0.0)
  assert_eq(phone.stage, 390.0 - 24.0)
  assert_true(phone.tight_controls)
}

///|
test "a degenerate viewport falls back instead of producing NaN" {
  // Hosts report 0×0 before the first real resize.
  let zero = Screen::for_viewport(0.0, 0.0)
  assert_eq(zero.mode, Wide)
  assert_true(zero.stage > 0.0)
  // A literal NaN (0.0/0.0) keeps the test dependency-free; the point is that
  // the screen sanitizes it rather than propagating it into layout.
  let nan_value = 0.0 / 0.0
  let nan = Screen::for_viewport(nan_value, nan_value)
  assert_true(!nan.stage.is_nan())
  assert_true(!nan.rail.is_nan())
  assert_true(!nan.drawer_width.is_nan())
}

///|
test "the stage never outgrows its reading measure" {
  // A 2,500px monitor gets the designed 760px stage, centered, not a
  // newspaper column.
  let huge = Screen::for_viewport(2500.0, 1400.0)
  assert_eq(huge.mode, Wide)
  assert_eq(huge.stage, 760.0)
  assert_eq(huge.rail, 300.0)
}
