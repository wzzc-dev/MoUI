///|
fn table_layout_test_font() -> @core.FontSpec {
  @core.FontSpec::new(size=10.0)
}

///|
fn table_layout_test_system() -> @core.TextSystem {
  @core.TextSystem::fallback()
}

///|
fn table_layout_test_cell(
  text : String,
  runs : Array[RichTextRun],
) -> RichTextTableCell {
  {
    text,
    runs,
    header: false,
    align: Some(TextStart),
    source_range: Some({ start: 0, end: text.to_array().length(), }),
  }
}

///|
test "styled table cell wraps long runs at the cell inner width" {
  let cell = table_layout_test_cell("abcdefghij`code`", [
    RichTextRun::new(
      text="abcdefghij",
      source_range=Some({ start: 0, end: 10, }),
    ),
    RichTextRun::new(
      text="`code`",
      visual_text=Some("code"),
      source_range=Some({ start: 10, end: 16, }),
    ),
  ])
  let result = rich_text_table_cell_segments_layout(
    cell,
    table_layout_test_font(),
    cell_inner_width=33.0,
    text_system=table_layout_test_system(),
  )
  // "abcdef" fills the first line exactly (6 × 5.5), "ghij" wraps to the
  // second, and the inline-code run continues on it before wrapping to the
  // third line. The old layout put the entire long first run on one line.
  assert_eq(result.line_count, 3)
  assert_eq(result.layout.lines.length(), 3)
  assert_eq(result.layout.segments.length(), 4)
  assert_eq(result.layout.segments[0].text, "abcdef")
  assert_eq(result.layout.segments[1].text, "ghij")
  assert_eq(result.layout.segments[2].text, "co")
  assert_eq(result.layout.segments[3].text, "de")
  assert_eq(result.layout.segments[0].line, 0)
  assert_eq(result.layout.segments[1].line, 1)
  assert_eq(result.layout.segments[2].line, 1)
  assert_eq(result.layout.segments[3].line, 2)
  for segment in result.layout.segments {
    assert_true(segment.x >= 0.0)
    assert_true(segment.x + segment.width <= 33.0 + 1.0e-6)
  }
  assert_eq(result.layout.lines[0].start, 0)
  assert_eq(result.layout.lines[0].end, 6)
  assert_eq(result.layout.lines[1].start, 6)
  assert_eq(result.layout.lines[1].end, 13)
  assert_eq(result.layout.lines[2].start, 13)
  assert_eq(result.layout.lines[2].end, 16)
  assert_eq(result.layout.lines[0].text, "abcdef")
  assert_eq(result.layout.lines[1].text, "ghijco")
  assert_eq(result.layout.lines[2].text, "de")
}

///|
test "styled table cell places an unbreakable glyph once instead of looping" {
  let cell = table_layout_test_cell("中", [
    RichTextRun::new(text="中", source_range=Some({ start: 0, end: 1, })),
  ])
  let result = rich_text_table_cell_segments_layout(
    cell,
    table_layout_test_font(),
    cell_inner_width=5.0,
    text_system=table_layout_test_system(),
  )
  // The glyph is wider than the cell; it still gets one segment on the first
  // line (the painter clips it), and layout makes progress rather than
  // wrapping forever.
  assert_eq(result.line_count, 1)
  assert_eq(result.layout.segments.length(), 1)
  assert_eq(result.layout.segments[0].text, "中")
  assert_eq(result.layout.segments[0].line, 0)
  assert_true(result.layout.segments[0].x == 0.0)
  assert_true(result.layout.segments[0].width > 5.0)
}

///|
test "table row height grows with every wrapped styled line" {
  let cell = table_layout_test_cell("abcdefghij`code`", [
    RichTextRun::new(
      text="abcdefghij",
      source_range=Some({ start: 0, end: 10, }),
    ),
    RichTextRun::new(
      text="`code`",
      visual_text=Some("code"),
      source_range=Some({ start: 10, end: 16, }),
    ),
  ])
  let table : RichTextTable = {
    rows: [[cell]],
    row_height: 19.0,
    cell_padding: @core.Insets::symmetric(horizontal=8.0, vertical=5.0),
    border: @core.Color::black(),
    header_background: None,
  }
  let block = RichTextBlock::new(runs=[], table=Some(table))
  let layout = rich_text_table_layout(
    table,
    block,
    table_layout_test_font(),
    frame_width=49.0,
    text_system=table_layout_test_system(),
  )
  assert_eq(layout.column_width, 49.0)
  assert_eq(layout.cell_inner_width, 33.0)
  assert_eq(layout.line_step, 9.0)
  assert_eq(layout.rows.length(), 1)
  // Three visual lines = base row height plus two extra line steps.
  assert_eq(layout.rows[0].height, 37.0)
  assert_eq(layout.rows[0].cells[0].lines.length(), 3)
}
