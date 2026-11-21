///|
/// The first commit of CJK text must measure full-width carets immediately:
/// the lazy CJK face registers in the measure path, so the commit frame's
/// caret lands after the committed text instead of at the placeholder
/// estimate (9.6 pt/char) while the draw path already renders full glyphs.
test "measure registers the CJK face before computing carets" {
  let target = SunPresentTarget::new(description="cjk-caret", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=400.0, height=120.0),
      scale_factor=2.0,
    ),
    target,
  )
  let font = @core.FontSpec::new(size=14.0)
  let result = renderer
    .text_system()
    .measure_text(
      @core.TextLayoutInput::new(text="你好", font~, max_width=300.0),
    )
  let carets = result.caret_positions
  assert_true(carets.length() == 3)
  assert_true(carets[0] == 0.0)
  // Full-width CJK advances: one glyph per character at the font size.
  assert_true(carets[1] == 14.0)
  assert_true(carets[2] == 28.0)
}
