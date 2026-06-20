///|
/// `spacer(weight=1.0)` based centering (and `View::flexible`/`View::expanded`)
/// was a layout no-op until the flex engine learned to grow weighted children.
/// These tests pin the framework behavior the website's centering relies on.
test "website homepage content is centered within the viewport" {
  let viewport_width = 1180.0
  let runtime = test_program_runtime(width=viewport_width, height=760.0)
  let commands = runtime.draw_commands()
  // The top bar brand and each full-width section header sit between two
  // weighted spacers, so their left and right viewport margins must match.
  let centered_labels = ["Why use MoUI with MoonBit?", "Built with MoUI"]
  for label in centered_labels {
    guard text_frame(commands, label) is Some(frame) else {
      fail("expected centered section header: \{label}")
    }
    let left_margin = frame.origin.x
    let right_margin = viewport_width - (frame.origin.x + frame.size.width)
    assert_true(left_margin > 0.0)
    assert_true(right_margin > 0.0)
    // Margins should be equal (the spacers split the slack evenly).
    let drift = if left_margin > right_margin {
      left_margin - right_margin
    } else {
      right_margin - left_margin
    }
    assert_true(drift < 1.0)
  }
  // The hero copy is centered by the same weighted-spacer shell.
  guard text_frame(commands, "MoonBit GUI Framework") is Some(hero) else {
    fail("expected hero statement")
  }
  let hero_left = hero.origin.x
  let hero_right = viewport_width - (hero.origin.x + hero.size.width)
  assert_true(hero_left > 0.0)
  assert_true(
    (if hero_left > hero_right {
      hero_left - hero_right
    } else {
      hero_right - hero_left
    }) <
    1.0,
  )
}

///|
/// Before the fix the brand mark rendered flush at x=0; it must now be inset
/// by the shared horizontal margin.
test "website top bar brand is not flush against the left edge" {
  let runtime = test_program_runtime(width=1180.0, height=760.0)
  let commands = runtime.draw_commands()
  guard text_frame(commands, "MoUI") is Some(brand) else {
    fail("expected brand text")
  }
  assert_true(brand.origin.x >= 40.0)
}
