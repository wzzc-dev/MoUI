///|
/// Shared table cell layout (ADR 0001 companion to the soft-wrap layer).
///
/// Table cells historically drew one unwrapped `DrawText` per cell, so text
/// longer than the column was simply clipped at the cell edge. This layout
/// wraps every cell's text at the cell's inner width, derives per-row heights
/// from the tallest wrapped cell, and exposes the per-line char ranges that
/// paint, hit-testing, caret rects, and selection all consume — keeping the
/// drawn table and its interaction geometry in sync.

///|
/// One visual line of a table cell. `start`/`end` are char offsets into
/// `RichTextTableCell.text`; `width` is the laid-out line width.
priv struct RichTextTableCellLine {
  start : Int
  end : Int
  width : Double
  text : String
}

///|
priv struct RichTextTableCellLayout {
  lines : Array[RichTextTableCellLine]
  font : @core.FontSpec
}

///|
priv struct RichTextTableRowLayout {
  cells : Array[RichTextTableCellLayout]
  height : Double
}

///|
priv struct RichTextTableLayout {
  rows : Array[RichTextTableRowLayout]
  column_width : Double
  cell_inner_width : Double
  line_step : Double
}

///|
/// Height of every row above `row_index`, so a row's top y can be derived
/// without assuming the historical uniform `table.row_height`.
fn RichTextTableLayout::row_top(self : RichTextTableLayout, row_index : Int) -> Double {
  let mut y = 0.0
  for index, row in self.rows {
    if index >= row_index {
      break
    }
    y = y + row.height
  }
  y
}

///|
fn RichTextTableLayout::total_height(self : RichTextTableLayout) -> Double {
  let mut y = 0.0
  for row in self.rows {
    y = y + row.height
  }
  y
}

///|
fn rich_text_table_cell_font(
  table : RichTextTable,
  block : RichTextBlock,
  base_font : @core.FontSpec,
  row_index~ : Int,
  column_index~ : Int,
) -> @core.FontSpec {
  let header = match table.rows.get(row_index) {
    Some(row) =>
      match row.get(column_index) {
        Some(cell) => cell.header
        None => false
      }
    None => false
  }
  { ..rich_text_block_font(block, base_font), weight: if header { 700 } else { 400 } }
}

///|
fn rich_text_table_layout(
  table : RichTextTable,
  block : RichTextBlock,
  base_font : @core.FontSpec,
  frame_width~ : Double,
  text_system~ : @core.TextSystem,
) -> RichTextTableLayout {
  let column_count = rich_text_table_column_count(table)
  let column_width = if column_count > 0 {
    max_double(0.0, frame_width / column_count.to_double())
  } else {
    0.0
  }
  let cell_inner_width = max_double(
    1.0,
    column_width - table.cell_padding.left - table.cell_padding.right,
  )
  let line_step = max_double(
    1.0,
    table.row_height - table.cell_padding.top - table.cell_padding.bottom,
  )
  let rows : Array[RichTextTableRowLayout] = []
  for row_index, row in table.rows {
    let cells : Array[RichTextTableCellLayout] = []
    let mut line_count = 1
    for column_index, cell in row {
      let font = rich_text_table_cell_font(
        table,
        block,
        base_font,
        row_index~,
        column_index~,
      )
      let chars = cell.text.to_array()
      let layout = text_system.layout_paragraph(
        @core.TextLayoutInput::new(
          text=cell.text,
          font~,
          max_width=cell_inner_width,
        ),
      )
      let lines : Array[RichTextTableCellLine] = []
      for line in layout.lines {
        let start = @core.clamp_int(line.text_range.start, 0, chars.length())
        let end = @core.clamp_int(line.text_range.end, start, chars.length())
        let text = String::from_array(chars[start:end])
        lines.push({
          start,
          end,
          width: rich_text_width(text, font, text_system),
          text,
        })
        line_count = @core.max_int(line_count, lines.length())
      }
      cells.push({ lines, font })
    }
    rows.push({
      cells,
      height: table.row_height + (line_count - 1).to_double() * line_step,
    })
  }
  { rows, column_width, cell_inner_width, line_step }
}
