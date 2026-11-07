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
      direction=LeftToRight,
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
    direction=LeftToRight,
  )
  assert_true(caret == boundaries[1] || caret == boundaries[2])
  assert_true(@core.TextGraphemeBoundaries::new(text~).is_boundary(caret))
}

///|
/// RTL step 2: with a RightToLeft base direction the measured caret
/// positions mirror, so a pointer near the RIGHT edge maps to the first
/// logical caret and a pointer near the LEFT edge maps to the end — the
/// hit-test reads the mirrored positions without its own direction logic.
test "single-line caret mapping reads mirrored positions in RTL" {
  let text = "ab"
  let frame = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=36.0)
  let font = @core.FontSpec::new(size=14.0)
  // The helper measures against the inset text frame; mirror the same
  // geometry here so the probes land exactly on the mirrored carets.
  let text_frame = frame.inset(
    @core.Insets::symmetric(horizontal=10.0, vertical=4.0),
  )
  let layout = @core.TextSystem::fallback().measure_text(
    @core.TextLayoutInput::new(
      text~,
      font~,
      max_width=text_frame.size.width,
      direction=RightToLeft,
    ),
  )
  // The provider mirrored the positions: caret 0 at the right edge.
  assert_true(layout.caret_positions[0] == layout.size.width)
  assert_true(
    layout.caret_positions[layout.caret_positions.length() - 1] == 0.0,
  )
  // A pointer just left of the mirrored first caret (the right edge of the
  // text) hits the first logical caret.
  let right_hit = single_line_text_caret_at_position(
    text,
    frame,
    font,
    @core.TextSystem::fallback(),
    false,
    @core.Point::new(x=text_frame.origin.x + layout.size.width - 2.0, y=20.0),
    direction=RightToLeft,
  )
  assert_true(right_hit == 0)
  // A pointer just right of the mirrored end caret (the left edge of the
  // text) hits the end caret.
  let left_hit = single_line_text_caret_at_position(
    text,
    frame,
    font,
    @core.TextSystem::fallback(),
    false,
    @core.Point::new(x=text_frame.origin.x + 2.0, y=20.0),
    direction=RightToLeft,
  )
  assert_true(left_hit == text.to_array().length())
}

///|
/// The static text path forwards the environment's layout direction into the
/// paragraph measurement, so an RTL environment measures RTL-ordered carets.
test "static text measurement consumes the environment direction" {
  let seen : Array[@core.LayoutDirection] = []
  let system = @core.TextSystem::new(id="rtl-env-probe", measure=input => {
    seen.push(input.direction)
    @core.TextSystem::fallback().measure_text(input)
  })
  // A direct node layout: the context carries the RTL environment exactly as
  // the runtime's element walk would after an `.environment(...)` modifier.
  let view : @core.View[Unit] = text("مرحبا")
  ignore(
    view.layout({
      constraints: @core.Constraints::loose(
        @core.Size::new(width=300.0, height=100.0),
      ),
      child_sizes: [],
      child_flex_weights: [],
      state: {
        focused: false,
        hovered: false,
        pressed: false,
        selected: false,
        checked: false,
        expanded: false,
        disabled: false,
        slots: @core.ViewStateSlots::empty(),
      },
      text_system: system,
      environment: @core.Environment::neutral().with_layout_direction(
        RightToLeft,
      ),
      style: @core.ViewStyle::empty(),
    }),
  )
  assert_true(seen.length() > 0)
  for direction in seen {
    assert_true(direction == RightToLeft)
  }
}
