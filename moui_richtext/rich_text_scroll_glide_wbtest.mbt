///|
/// The scroll glide is a pure function of the animation clock: these tests
/// pin its shape (endpoints, monotonicity, whole-pixel snapping, settling)
/// and then prove the editor view samples it at *paint* time, which is what
/// removes the timer tick grid from the scroll path.

///|
test "scroll glide evaluates as a function of the clock" {
  let glide = MarkdownScrollGlide::new(from_y=0.0, to_y=100.0, start_ms=1000.0)
  // Before the start (and at it) the glide sits at its from position.
  assert_eq(glide.offset_at(900.0), 0.0)
  assert_eq(glide.offset_at(1000.0), 0.0)
  // Mid-flight: strictly between the endpoints, whole pixels, animating.
  let mid = glide.offset_at(1040.0)
  assert_true(mid > 0.0)
  assert_true(mid < 100.0)
  assert_eq(mid, mid.floor())
  assert_true(glide.is_animating(1040.0))
  // Monotonic across the flight, sampled on a 120Hz grid.
  let mut previous = 0.0
  let mut clock = 1000.0
  while glide.is_animating(clock) && clock < 5000.0 {
    clock = clock + 8.333
    let next = glide.offset_at(clock)
    assert_true(next >= previous)
    previous = next
  }
  // It settles exactly on the target and stops reporting animation, which is
  // what lets the host's redraw loop stop.
  assert_eq(glide.offset_at(5000.0), 100.0)
  assert_false(glide.is_animating(5000.0))
}

///|
test "settled scroll glide is a constant" {
  let glide = MarkdownScrollGlide::settled(42.0)
  assert_eq(glide.offset_at(0.0), 42.0)
  assert_eq(glide.offset_at(99999.0), 42.0)
  assert_false(glide.is_animating(0.0))
  assert_false(glide.is_animating(99999.0))
}

///|
test "scroll glide never overshoots its target" {
  let glide = MarkdownScrollGlide::new(from_y=500.0, to_y=100.0, start_ms=0.0)
  let mut clock = 0.0
  while clock < 2000.0 {
    let y = glide.offset_at(clock)
    assert_true(y <= 500.0)
    assert_true(y >= 100.0)
    clock = clock + 7.0
  }
  assert_eq(glide.offset_at(2000.0), 100.0)
  assert_false(glide.is_animating(2000.0))
}

///|
fn glide_test_source() -> String {
  let paragraphs : Array[String] = []
  for index in 0..<40 {
    paragraphs.push(
      "Paragraph \{index} carries enough words to wrap across a line or two in the editor column.",
    )
  }
  paragraphs.join("\n\n")
}

///|
/// A comparable signature of everything the editor painted: text plus its
/// frame position. Two signatures differing means the painted scroll offset
/// changed; identical signatures mean the frame is pixel-identical.
fn glide_test_paint_signature(runtime : @runtime.AppRuntime) -> String {
  let parts : Array[String] = []
  for command in runtime.draw_commands() {
    match command {
      DrawText(run) =>
        parts.push(
          run.text +
          "@" +
          run.frame.origin.x.to_string() +
          "," +
          run.frame.origin.y.to_string(),
        )
      _ => ()
    }
  }
  parts.join("|")
}

///|
fn glide_test_runtime(glide : MarkdownScrollGlide) -> @runtime.AppRuntime {
  let session = MarkdownDocumentSession::new(glide_test_source())
  let selection : MarkdownEditorSelection = { caret: 0, selection: None, }
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(init=(), update=(_model, _next) => (), view=_ => {
      controlled_markdown_session_editor(
        session~,
        selection~,
        on_transaction=_ => (),
        placeholder="",
        size=@core.Size::new(width=360.0, height=400.0),
        font=@core.FontSpec::new(),
        foreground=@core.Color::black(),
        placeholder_color=@core.Color::black(),
        background=@core.Brush::solid(@core.Color::white()),
        cursor_color=@core.Color::black(),
        scroll_glide=glide,
        visible_viewport_height=400.0,
        visible_overscan=0.0,
      )
    }),
    size=@core.Size::new(width=360.0, height=400.0),
  )
  runtime.set_text_system(@core.TextSystem::fallback())
  runtime
}

///|
/// The painted offset follows the animation clock: the same view paints a
/// different window at t=16ms and t=80ms without any model change, and once
/// the glide settles the frame becomes pixel-identical (the host's redraw
/// loop has nothing left to do).
test "session editor samples the scroll glide at paint time" {
  let runtime = glide_test_runtime(
    MarkdownScrollGlide::new(from_y=0.0, to_y=300.0, start_ms=0.0),
  )
  ignore(glide_test_paint_signature(runtime))
  runtime.advance_time(16.0)
  let early = glide_test_paint_signature(runtime)
  runtime.advance_time(80.0)
  let mid = glide_test_paint_signature(runtime)
  // The clock advanced, so the painted window moved — no message, no model
  // change, purely paint-time sampling.
  assert_true(early != mid)
  // Settled: further clock advances paint the same frame.
  runtime.advance_time(4000.0)
  let settled = glide_test_paint_signature(runtime)
  runtime.advance_time(8000.0)
  let later = glide_test_paint_signature(runtime)
  assert_true(settled != early)
  assert_eq(settled, later)
}

///|
/// Browsers scroll on the device-pixel grid, not the logical one: at 2x a
/// whole logical pixel is two physical pixels and reads as coarse stepping.
/// `offset_at(scale=2)` must therefore land on multiples of half a logical
/// pixel, and strictly finer than the default whole-logical snap.
test "scroll glide snaps to the device pixel grid when scaled" {
  let glide = MarkdownScrollGlide::new(from_y=0.0, to_y=100.0, start_ms=0.0)
  let mut clock = 0.0
  let mut saw_fractional = false
  while clock < 600.0 {
    let device = glide.offset_at(clock, scale=2.0)
    // Every device-snapped value is a multiple of 0.5 logical pixels.
    assert_eq(device, (device * 2.0).round() / 2.0)
    // The exact position is finer still (not a whole or half pixel).
    let exact = glide.exact_offset_at(clock)
    if exact * 2.0 != (exact * 2.0).round() {
      saw_fractional = true
      // The snap never moves the position by more than half a device pixel.
      assert_true((device - exact).abs() <= 0.5000001)
    }
    clock = clock + 5.0
  }
  // Confirms the scale actually buys resolution the default snap lacks.
  assert_true(saw_fractional)
  // Both endpoints are hit exactly regardless of scale.
  assert_eq(glide.offset_at(0.0, scale=2.0), 0.0)
  assert_eq(glide.offset_at(9000.0, scale=2.0), 100.0)
}

///|
/// The state machine stays in exact logical units: re-keying must read the
/// un-quantized offset so feeding it back as the next `from_y` cannot drift
/// or shift by half a device pixel per event.
test "exact offset drives re-keying without rounding error" {
  let glide = MarkdownScrollGlide::new(from_y=0.0, to_y=99.0, start_ms=0.0)
  let exact_mid = glide.exact_offset_at(45.0)
  // exact is strictly between the endpoints (mid-flight).
  assert_true(exact_mid > 0.0)
  assert_true(exact_mid < 99.0)
  // A glide re-keyed from the exact position continues it exactly.
  let rekeyed = MarkdownScrollGlide::new(
    from_y=exact_mid,
    to_y=200.0,
    start_ms=45.0,
  )
  assert_eq(rekeyed.exact_offset_at(45.0), exact_mid)
}

///|
/// Geometry measurement is published by paint and consumed by the owning app
/// on its next view rebuild. The hand-off must be one-shot: consuming it twice
/// would apply the same height delta twice and produce the reported rebound on
/// the next wheel event.
test "geometry compensation is published and consumed exactly once" {
  // Drain any value left by an earlier runtime paint in this process.
  ignore(markdown_scroll_take_geometry_compensation())
  markdown_scroll_publish_geometry_compensation(24.0)
  markdown_scroll_publish_geometry_compensation(-4.0)
  assert_eq(markdown_scroll_take_geometry_compensation(), 20.0)
  assert_eq(markdown_scroll_take_geometry_compensation(), 0.0)
}

///|
/// A measured block above the anchor shifts both glide endpoints together.
/// Rebuilding the view with the consumed compensation must therefore preserve
/// the exact in-flight position and cannot re-key from the stale target.
test "geometry compensation preserves an in-flight glide across rebuild" {
  let glide = MarkdownScrollGlide::new(
    from_y=120.0,
    to_y=420.0,
    start_ms=1000.0,
    tau_ms=90.0,
  )
  let shown = glide.exact_offset_at(1040.0)
  let compensated = glide.with_anchor_compensation(36.0, 1000.0, now_ms=1040.0)
  assert_eq(compensated.exact_offset_at(1040.0), shown + 36.0)
  assert_true(compensated.to_y > compensated.from_y)
  assert_true(compensated.is_animating(1040.0))
  // The next wheel re-key starts from the compensated position, rather than
  // the old target, so it cannot jump backwards at the event boundary.
  let next = MarkdownScrollGlide::new(
    from_y=compensated.exact_offset_at(1040.0),
    to_y=compensated.to_y + 48.0,
    start_ms=1040.0,
  )
  assert_eq(next.exact_offset_at(1040.0), shown + 36.0)
}

///|
/// When a range clamp clips only one endpoint, preserving the old start time
/// is not enough: the clipped curve would evaluate to a different position at
/// the compensation instant. Re-keying from the compensated displayed point
/// keeps that frame continuous.
test "geometry compensation preserves the displayed point at a range edge" {
  let glide = MarkdownScrollGlide::new(
    from_y=100.0,
    to_y=900.0,
    start_ms=0.0,
    tau_ms=90.0,
  )
  let shown = glide.exact_offset_at(40.0)
  let compensated = glide.with_anchor_compensation(-150.0, 1000.0, now_ms=40.0)
  assert_eq(compensated.exact_offset_at(40.0), shown - 150.0)

  let bottom = MarkdownScrollGlide::new(
    from_y=700.0,
    to_y=1000.0,
    start_ms=0.0,
    tau_ms=90.0,
  )
  let bottom_compensated = bottom.with_anchor_compensation(
    50.0,
    800.0,
    now_ms=40.0,
  )
  assert_eq(bottom_compensated.exact_offset_at(40.0), 800.0)
}

///|
test "geometry range shrink never creates an input-free reverse glide" {
  let glide = MarkdownScrollGlide::new(
    from_y=0.0,
    to_y=1000.0,
    start_ms=0.0,
    tau_ms=90.0,
  )
  let shown = glide.exact_offset_at(80.0)
  // The new max clips the old forward target below the currently shown point.
  let compensated = glide.with_anchor_compensation(
    0.0,
    shown - 20.0,
    now_ms=80.0,
  )
  assert_eq(compensated.from_y, shown - 20.0)
  assert_eq(compensated.to_y, shown - 20.0)
  assert_eq(compensated.exact_offset_at(80.0), shown - 20.0)
  assert_false(compensated.is_animating(80.0))
}

///|
test "geometry compensation is snapped together on scaled displays" {
  let glide = MarkdownScrollGlide::settled(10.24)
  let combined = glide.offset_at_with_compensation(0.0, 0.24, scale=2.0)
  // 10.48 rounds to the nearest half logical pixel as one value.
  assert_eq(combined, 10.5)
}
