///|
test "single-line text pointer hit testing returns the nearest caret" {
  let frame = @core.Rect::new(x=0.0, y=0.0, width=240.0, height=40.0)
  let font = @core.FontSpec::new(size=14.0)
  let text = "abcd"
  let text_frame = single_line_text_frame(frame, false, true)
  let layout = @core.TextSystem::fallback().measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=text_frame.size.width),
  )
  let x = text_frame.origin.x + layout.caret_positions[2] + 0.1
  assert_eq(
    single_line_text_caret_at_position(
      text,
      frame,
      font,
      @core.TextSystem::fallback(),
      false,
      @core.Point::new(x~, y=20.0),
    ),
    2,
  )
}

///|
test "single-line text pointer hit testing stays on grapheme boundaries" {
  let frame = @core.Rect::new(x=0.0, y=0.0, width=240.0, height=40.0)
  let font = @core.FontSpec::new(size=14.0)
  let text = "a👩‍💻b"
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  let text_frame = single_line_text_frame(frame, false, true)
  let layout = @core.TextSystem::fallback().measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=text_frame.size.width),
  )
  let x = text_frame.origin.x +
    (
      layout.caret_positions[boundaries[1]] +
      layout.caret_positions[boundaries[2]]
    ) /
    2.0
  let caret = single_line_text_caret_at_position(
    text,
    frame,
    font,
    @core.TextSystem::fallback(),
    false,
    @core.Point::new(x~, y=20.0),
  )
  assert_true(caret == boundaries[1] || caret == boundaries[2])
  assert_true(@core.TextGraphemeBoundaries::new(text~).is_boundary(caret))
}
