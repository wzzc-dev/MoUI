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
/// One styled segment of a cell line: a run's visible text placed on a
/// line at an x offset. `start`/`end` are offsets into the CELL's raw
/// `text` covering the segment's visible characters (markers excluded),
/// `source_start`/`source_end` the run's full construct range including
/// markers — caret/hit map through the former, reveal logic keys the
/// latter.
priv struct RichTextTableCellSegment {
  run : RichTextRun
  line : Int
  start : Int
  end : Int
  x : Double
  width : Double
  text : String
}

///|
priv struct RichTextTableCellLayout {
  lines : Array[RichTextTableCellLine]
  segments : Array[RichTextTableCellSegment]
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
fn RichTextTableLayout::row_top(
  self : RichTextTableLayout,
  row_index : Int,
) -> Double {
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
  {
    ..rich_text_block_font(block, base_font),
    weight: if header {
      700
    } else {
      400
    },
  }
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
      // Styled cells lay out per-run segments (markers hidden); plain cells
      // keep the historical single-font paragraph layout.
      if cell.runs.length() > 0 {
        let styled = rich_text_table_cell_segments_layout(
          cell,
          font,
          cell_inner_width~,
          text_system~,
        )
        line_count = @core.max_int(line_count, styled.line_count)
        cells.push(styled.layout)
      } else {
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
        cells.push({ lines, segments: [], font, })
      }
    }
    rows.push({
      cells,
      height: table.row_height + (line_count - 1).to_double() * line_step,
    })
  }
  { rows, column_width, cell_inner_width, line_step, }
}

///|
priv struct RichTextTableCellSegmentsLayout {
  layout : RichTextTableCellLayout
  line_count : Int
}

///|
/// Layout a styled cell: walk the runs' visible text in order, wrapping at
/// the cell's inner width, and record each placed segment with its x offset
/// and the cell-relative char range of its VISIBLE characters (markers
/// occupy source chars but no width). Lines are derived for caret/hit's
/// y-band math: each line covers the source span of whatever it holds.
fn rich_text_table_cell_segments_layout(
  cell : RichTextTableCell,
  font : @core.FontSpec,
  cell_inner_width~ : Double,
  text_system~ : @core.TextSystem,
) -> RichTextTableCellSegmentsLayout {
  let segments : Array[RichTextTableCellSegment] = []
  let lines : Array[RichTextTableCellLine] = []
  let chars = cell.text.to_array()
  let mut x = 0.0
  let mut cursor = 0
  for run in cell.runs {
    let run_font = run.font.unwrap_or(font)
    let visible = rich_text_run_visual_text(run)
    let visible_chars = visible.to_array()
    // The run's source range within the cell (markers included); when absent
    // the visible text cannot be located and the run still paints at the
    // cursor (offsets only advance by its visible length).
    let range = match run.source_range {
      Some(range) => range
      None => { start: cursor, end: cursor, }
    }
    let mut index = 0
    while index < visible_chars.length() {
      let remaining_width = max_double(0.0, cell_inner_width - x)
      let piece = String::from_array(visible_chars[index:])
      let width = rich_text_width(piece, run_font, text_system)
      if width <= remaining_width || x <= 0.0 {
        // Fits (or the segment alone overflows the cell: place it anyway).
        let end = @core.min_int(
          index + visible_chars.length(),
          visible_chars.length(),
        )
        let segment_text = if index == 0 {
          visible
        } else {
          String::from_array(visible_chars[index:])
        }
        segments.push({
          run,
          line: lines.length(),
          start: range.start + index,
          end: range.start + end,
          x,
          width,
          text: segment_text,
        })
        x = x + width
        index = visible_chars.length()
        cursor = range.end
      } else {
        // Wrap: start a new line at the next cluster boundary that fits.
        // Cells are usually short; measuring cluster-wise keeps it simple.
        let mut taken = index
        let mut taken_width = 0.0
        while taken < visible_chars.length() {
          let probe_width = rich_text_width(
            String::from_array(visible_chars[index:taken + 1]),
            run_font,
            text_system,
          )
          if taken_width + probe_width > remaining_width && taken > index {
            break
          }
          taken_width = taken_width + probe_width
          taken = taken + 1
        }
        let line_text = String::from_array(visible_chars[index:taken])
        let line_width = rich_text_width(line_text, run_font, text_system)
        segments.push({
          run,
          line: lines.length(),
          start: range.start + index,
          end: range.start + taken,
          x,
          width: line_width,
          text: line_text,
        })
        lines.push({
          start: range.start + index,
          end: range.end,
          width: cell_inner_width,
          text: line_text,
        })
        x = 0.0
        index = taken
        cursor = range.end
      }
    }
  }
  // One trailing line record so empty cells and the last line have a band.
  if lines.is_empty() {
    lines.push({ start: 0, end: chars.length(), width: 0.0, text: "", })
  } else {
    let last = lines[lines.length() - 1]
    let next_start = last.end
    if next_start < chars.length() {
      lines.push({
        start: next_start,
        end: chars.length(),
        width: 0.0,
        text: "",
      })
    }
  }
  { layout: { lines, segments, font, }, line_count: lines.length(), }
}
