///|
/// Single-line caret geometry must come from the measured line box, not a
/// hard-coded inset. The renderer centers that measured box in the field
/// frame, so the caret uses the same height and center for Latin and CJK.
test "single-line caret matches the measured line box and center" {
  let frame = @core.Rect::new(x=10.0, y=4.0, width=220.0, height=32.0)
  let font = @core.FontSpec::new(size=13.0)
  let text_system = @core.TextSystem::fallback()
  let text_frame = single_line_text_frame(frame, false, true)
  for text in ["Hello", "你好", "안녕하세요", "😀"] {
    let control : @core.TextControlStateContext = {
      caret: text.to_array().length(),
      selection: None,
      text_selection_anchor: None,
      goal_column: None,
      reveal: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    }
    let state = text_input_state_for_single_line(
      text~,
      frame~,
      font~,
      control~,
      text_system~,
      search_bar=false,
      direction=@core.LayoutDirection::LeftToRight,
    )
    let layout = text_system.measure_text(
      @core.TextLayoutInput::new(
        text~,
        font~,
        max_width=text_frame.size.width,
        direction=@core.LayoutDirection::LeftToRight,
      ),
    )
    assert_true(layout.size.height > 0.0)
    assert_eq(state.caret_rect.size.height, layout.size.height)
    assert_eq(
      state.caret_rect.origin.y,
      text_frame.origin.y + (text_frame.size.height - layout.size.height) / 2.0,
    )
  }
}

///|
test "single-line selection overlay uses the same line box as the caret" {
  let layout : @core.TextLayoutResult = {
    size: @core.Size::new(width=40.0, height=18.0),
    baseline: 14.0,
    caret_positions: [0.0, 8.0, 16.0],
  }
  let text_frame = @core.Rect::new(x=10.0, y=4.0, width=120.0, height=24.0)
  let commands : Array[@core.DrawCommand] = []
  append_text_field_selection_commands(
    commands,
    "ab",
    text_frame,
    layout,
    Some(@core.TextRange::new(start=0, end=2)),
    @style.default_theme(),
  )
  match commands[0] {
    FillRect(rect, _) => {
      assert_eq(rect.size.height, 18.0)
      assert_eq(rect.origin.y, 7.0)
    }
    _ => fail("expected selection fill")
  }
}
