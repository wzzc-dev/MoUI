///|
/// Caret positions must come from real per-glyph advances. The even-split
/// fallback divided the span width evenly across characters, so on any
/// proportional face the caret drifted from the drawn glyphs (caret after
/// `H` in `Hello` claimed one fifth of the whole word). This synthetic face
/// gives `A` advance 10 and space advance 5, so the even split would report
/// [0, 8.3, 16.7, 25] instead of [0, 10, 15, 25].
test "text carets follow per-glyph advances, not an even split" {
  let target = @moui_sun_renderer.SunPresentTarget::new(
    description="caret-accuracy",
    present=_ => true,
  )
  let renderer = @moui_sun_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    Name("SunCaretProbe"),
    sun_test_ttf_for_codes([65, 0x20]),
  )
  let result = text_system.measure_text(
    @core.TextLayoutInput::new(
      text="A A",
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([Name("SunCaretProbe")]),
        size=10.0,
      ),
      max_width=100.0,
    ),
  )
  inspect(result.caret_positions.length(), content="4")
  assert_true(result.caret_positions[0] == 0.0)
  assert_true(result.caret_positions[1] == 10.0)
  assert_true(result.caret_positions[2] == 15.0)
  assert_true(result.caret_positions[3] == 25.0)
}
