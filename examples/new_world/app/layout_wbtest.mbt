///|
/// `Layout` must reproduce the previous constants exactly, and scale
/// proportionally when given a different total width (plan P5.1).

///|
test "the default layout matches the previous hardcoded constants" {
  let layout = Layout::default()
  assert_eq(layout.rail_width, 310.0)
  assert_eq(layout.stage_width, 520.0)
  assert_eq(layout.controls_width, 330.0)
  // 310 + 520 + 330 + two 20px gutters.
  assert_eq(layout.content_width(), 1200.0)
}

///|
test "for_width keeps the proportions and fills the target" {
  let wide = Layout::for_width(1600.0)
  // Floating point: 1600 reconstructed through three multiplications and a sum
  // lands within 1e-9, not exactly. Compare with a tolerance — the invariant is
  // "fills the target", not "bit-identical".
  assert_true((wide.content_width() - 1600.0).abs() < 1.0e-9)
  // Ratios preserved: stage is the largest, rail and controls differ by 20/520.
  assert_true(wide.rail_width < wide.stage_width)
  assert_true(wide.controls_width < wide.stage_width)
  assert_true(wide.rail_width < wide.controls_width)
  // A narrow panel shrinks every column but keeps them positive.
  let narrow = Layout::for_width(600.0)
  assert_true((narrow.content_width() - 600.0).abs() < 1.0e-9)
  assert_true(narrow.stage_width > 0.0)
  assert_true(narrow.rail_width > 0.0)
}

///|
test "for_width falls back to the default on a degenerate width" {
  // A zero or negative target is a caller bug; returning the default is safer
  // than dividing by zero and producing NaN widths.
  assert_eq(Layout::for_width(0.0).content_width(), 1200.0)
  assert_eq(Layout::for_width(-10.0).content_width(), 1200.0)
}

///|
test "the legacy constants still describe the default layout" {
  // Existing call sites read these directly; they must agree with Layout::default.
  let layout = Layout::default()
  assert_eq(rail_width, layout.rail_width)
  assert_eq(stage_width, layout.stage_width)
  assert_eq(controls_width, layout.controls_width)
  assert_eq(content_width, layout.content_width())
}
