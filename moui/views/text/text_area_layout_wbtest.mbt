///|
fn draw_text_rect(command : @core.DrawCommand) -> @core.Rect? {
  match command {
    @core.DrawCommand::DrawText(run) => Some(run.frame)
    _ => None
  }
}

///|
fn text_area_test_paragraph(
  text : String,
  width : Double,
) -> @core.TextParagraphLayoutResult {
  let frame = @core.Rect::new(x=0.0, y=0.0, width~, height=120.0)
  @core.TextSystem::fallback().layout_paragraph(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=14.0),
      max_width=text_area_text_frame(frame).size.width,
    ),
  )
}

///|
test "paragraph lines tile the whole text contiguously" {
  let text = "one two three four five six seven eight nine ten"
  let paragraph = text_area_test_paragraph(text, 120.0)
  assert_true(paragraph.lines.length() > 1)
  let chars = text.to_array()
  let mut cursor = 0
  for line in paragraph.lines {
    assert_eq(line.line_index, cursor)
    cursor = cursor + 1
    assert_true(line.text_range.start <= line.text_range.end)
  }
  assert_eq(paragraph.lines[0].text_range.start, 0)
  assert_eq(
    paragraph.lines[paragraph.lines.length() - 1].text_range.end,
    chars.length(),
  )
  let mut line_index = 0
  while line_index + 1 < paragraph.lines.length() {
    assert_eq(
      paragraph.lines[line_index].text_range.end,
      paragraph.lines[line_index + 1].text_range.start,
    )
    line_index = line_index + 1
  }
}

///|
test "caret rect x comes from paragraph caret geometry" {
  let paragraph = text_area_test_paragraph("one two three four five", 120.0)
  let frame = @core.Rect::new(x=0.0, y=0.0, width=120.0, height=120.0)
  let text_frame = text_area_text_frame(frame)
  let font = @core.FontSpec::new(size=14.0)
  let text_system = @core.TextSystem::fallback()
  let line_height = 28.0
  let second_line = paragraph.lines[1]
  let offset = second_line.text_range.start
  let caret = text_area_display_caret_rect(
    paragraph, text_system, text_frame, font, offset, line_height,
  )
  assert_eq(
    caret.origin.x,
    text_frame.origin.x +
    (paragraph.caret_rect_at(offset).origin.x - second_line.origin.x),
  )
  let glyph_h = text_area_glyph_row_height(text_system, " ", font)
  assert_eq(
    caret.origin.y,
    text_area_line_slot_y(text_frame, 1, line_height, glyph_h),
  )
  assert_eq(
    text_area_line_index_for_paragraph_offset(
      paragraph,
      paragraph.text.to_array().length(),
    ),
    paragraph.lines.length() - 1,
  )
}

///|
test "selection highlight shares the painted line rows" {
  let text = "one two three four five"
  let paragraph = text_area_test_paragraph(text, 120.0)
  let frame = @core.Rect::new(x=0.0, y=0.0, width=120.0, height=120.0)
  let text_frame = text_area_text_frame(frame)
  let font = @core.FontSpec::new(size=14.0)
  let text_system = @core.TextSystem::fallback()
  let line_height = 28.0
  let selection = @core.TextRange::new(
    start=paragraph.lines[0].text_range.start,
    end=paragraph.lines[1].text_range.end,
  )
  let rects = text_area_selection_slot_rects(
    paragraph, text_system, font, selection, text_frame, line_height,
  )
  assert_eq(rects.length(), 2)
  let chars = text.to_array()
  let black : @core.Color = { r: 0.0, g: 0.0, b: 0.0, a: 1.0 }
  for line_index, rect in rects {
    let line_text = String::from_array(
      chars[paragraph.lines[line_index].text_range.start:paragraph.lines[line_index].text_range.end],
    )
    let commands : Array[@core.DrawCommand] = []
    text_area_draw_line_text(
      commands,
      text_system,
      line_text,
      font,
      black,
      text_frame,
      line_index,
      line_height,
      text_frame.origin.x,
      text_frame.size.width,
    )
    let painted = match draw_text_rect(commands[0]) {
      Some(painted_rect) => painted_rect
      None => fail("expected DrawText command")
    }
    // Same row: identical vertical slot. Same line: identical left edge.
    assert_eq(rect.origin.y, painted.origin.y)
    assert_eq(rect.origin.x, painted.origin.x)
    assert_true(rect.size.height > 0.0)
  }
}

///|
test "hit testing round-trips caret positions" {
  let text = "one two three"
  let paragraph = text_area_test_paragraph(text, 120.0)
  for offset in 0..<=text.to_array().length() {
    let caret = paragraph.caret_rect_at(offset)
    let hit = paragraph.hit_test(
      @core.Point::new(
        x=caret.origin.x,
        y=caret.origin.y + caret.size.height / 2.0,
      ),
    )
    assert_eq(hit.offset, offset)
  }
}

///|
test "wrapping and carets stay on grapheme boundaries" {
  let text = "你好世界测试文本 a👩‍💻b 👩‍💻xyz"
  let paragraph = text_area_test_paragraph(text, 120.0)
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  for line in paragraph.lines {
    assert_true(boundaries.is_boundary(line.text_range.start))
    assert_true(boundaries.is_boundary(line.text_range.end))
  }
  assert_true(paragraph.lines.length() > 1)
  // A caret inside the ZWJ emoji sequence snaps to a grapheme boundary
  // and reports the same x as paragraph geometry.
  let frame = @core.Rect::new(x=0.0, y=0.0, width=120.0, height=120.0)
  let text_frame = text_area_text_frame(frame)
  let font = @core.FontSpec::new(size=14.0)
  let text_system = @core.TextSystem::fallback()
  // 你好世界测试文本(8) + space(8) + a(9) + ZWJ emoji chars(10..12)
  let inner = 11
  assert_true(!boundaries.is_boundary(inner))
  let snapped = boundaries.nearest_boundary(inner)
  assert_true(boundaries.is_boundary(snapped))
  let caret = text_area_display_caret_rect(
    paragraph, text_system, text_frame, font, inner, 28.0,
  )
  let line_index = text_area_line_index_for_paragraph_offset(paragraph, inner)
  let line = paragraph.lines[line_index]
  assert_eq(
    caret.origin.x,
    text_frame.origin.x +
    (paragraph.caret_rect_at(inner).origin.x - line.origin.x),
  )
  let glyph_h = text_area_glyph_row_height(text_system, " ", font)
  assert_eq(
    caret.origin.y,
    text_area_line_slot_y(text_frame, line_index, 28.0, glyph_h),
  )
  assert_true(caret.origin.x >= text_frame.origin.x)
}
