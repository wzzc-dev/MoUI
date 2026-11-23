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
  start : Int32
  end : Int32
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
  line : Int32
  start : Int32
  end : Int32
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
  row_index : Int32,
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
  row_index~ : Int32,
  column_index~ : Int32,
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
  line_count : Int32
}

///|
/// Offset of the run's visible text inside its raw construct text. Inline
/// markers sit before/after the visible span (`**bold**`, `` `code` ``), so
/// mapping a visible char back to the cell source needs this prefix instead
/// of assuming the visible span starts at `source_range.start`.
fn rich_text_table_run_source_shift(
  run : RichTextRun,
  visible_chars : Array[Char],
) -> Int32 {
  if visible_chars.length() == 0 {
    return 0
  }
  let raw_chars = run.text.to_array()
  if raw_chars.length() == visible_chars.length() {
    return 0
  }
  let mut shift = 0
  while shift + visible_chars.length() <= raw_chars.length() {
    let mut same = true
    let mut index = 0
    while index < visible_chars.length() {
      if raw_chars[shift + index] != visible_chars[index] {
        same = false
        break
      }
      index = index + 1
    }
    if same {
      return shift
    }
    shift = shift + 1
  }
  0
}

///|
/// Next grapheme boundary after `index`, with a code-point fallback so a
/// broken boundary table can never stall the wrapping loop.
fn rich_text_table_next_cluster(visible : String, index : Int32) -> Int32 {
  let length = visible.to_array().length()
  let boundary = @core.text_next_grapheme_caret_boundary(visible, index)
  if boundary > index && boundary <= length {
    boundary
  } else if boundary > length {
    length
  } else {
    index + 1
  }
}

///|
/// Layout a styled cell: walk the runs' visible text in order, wrapping at
/// the cell's inner width, and record each placed segment with its x offset
/// and the cell-relative char range of its VISIBLE characters (markers
/// occupy source chars but no width). Every visual line gets a line record,
/// including the first and last, so row heights and caret/hit y-bands match
/// exactly what was drawn.
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
  // State of the visual line currently being filled. A line is only pushed
  // when it is complete, so `line` indexes and line heights stay in sync.
  let line_chars : Array[Char] = []
  let mut line_start = 0
  let mut line_end = 0
  let mut line_width = 0.0
  let mut line_open = false
  for run in cell.runs {
    let run_font = run.font.unwrap_or(font)
    let visible = rich_text_run_visual_text(run)
    let visible_chars = visible.to_array()
    // The run's source range within the cell (markers included); when absent
    // the visible text cannot be located, so it maps onto the running cursor
    // position only.
    let source_start = match run.source_range {
      Some(range) => range.start
      None => cursor
    }
    let source_shift = match run.source_range {
      Some(_) => rich_text_table_run_source_shift(run, visible_chars)
      None => 0
    }
    let mut index = 0
    while index < visible_chars.length() {
      // Soft-wrapped lines do not begin with the space that did not fit;
      // skipping it keeps the new line flush with the cell's text edge.
      if x <= 0.0 &&
        !line_open &&
        (visible_chars[index] == ' ' || visible_chars[index] == '\t') {
        index = rich_text_table_next_cluster(visible, index)
        continue
      }
      let remaining_width = max_double(0.0, cell_inner_width - x)
      // Extend the chunk one grapheme cluster at a time while it fits, then
      // draw the whole chunk as one segment so shaping/kerning inside a run
      // survives the wrap.
      let mut end = index
      let mut chunk_width = 0.0
      let mut placed = false
      while end < visible_chars.length() {
        let cluster_end = rich_text_table_next_cluster(visible, end)
        let candidate_width = rich_text_width(
          String::from_array(visible_chars[index:cluster_end]),
          run_font,
          text_system,
        )
        if candidate_width > remaining_width {
          break
        }
        end = cluster_end
        chunk_width = candidate_width
        placed = true
      }
      if !placed {
        if x > 0.0 {
          // Nothing from this run fits on the current line: close it and
          // retry the run at the start of the next line.
          if line_open {
            lines.push({
              start: line_start,
              end: line_end,
              width: line_width,
              text: String::from_array(line_chars),
            })
            line_chars.clear()
            line_width = 0.0
            line_open = false
          }
          x = 0.0
          continue
        }
        // An unbreakable single cluster at a line start: place it anyway and
        // let the painter's cell clip hide the overflow.
        end = rich_text_table_next_cluster(visible, index)
        chunk_width = rich_text_width(
          String::from_array(visible_chars[index:end]),
          run_font,
          text_system,
        )
      }
      let chunk_text = String::from_array(visible_chars[index:end])
      let segment_start = source_start + source_shift + index
      let segment_end = source_start + source_shift + end
      segments.push({
        run,
        line: lines.length(),
        start: segment_start,
        end: segment_end,
        x,
        width: chunk_width,
        text: chunk_text,
      })
      if !line_open {
        line_open = true
        line_start = segment_start
      }
      line_end = segment_end
      line_width = x + chunk_width
      for ch in chunk_text {
        line_chars.push(ch)
      }
      x = x + chunk_width
      index = end
      if index < visible_chars.length() {
        // The run continues, so this line is full by construction.
        lines.push({
          start: line_start,
          end: line_end,
          width: line_width,
          text: String::from_array(line_chars),
        })
        line_chars.clear()
        line_width = 0.0
        line_open = false
        x = 0.0
      }
    }
    cursor = match run.source_range {
      Some(range) => range.end
      None => cursor + visible_chars.length()
    }
  }
  if line_open {
    lines.push({
      start: line_start,
      end: line_end,
      width: line_width,
      text: String::from_array(line_chars),
    })
  }
  // Every cell needs at least one line band, even when its runs contain no
  // visible text. Line source ranges are then made contiguous over the cell
  // source so stray offsets (markers, gaps between runs) always resolve to a
  // line instead of falling through to the last line.
  if lines.is_empty() {
    lines.push({ start: 0, end: chars.length(), width: 0.0, text: "", })
  } else {
    let first = lines[0]
    lines[0] = {
      start: 0,
      end: first.end,
      width: first.width,
      text: first.text,
    }
    let mut line_index = 0
    while line_index + 1 < lines.length() {
      let current = lines[line_index]
      let next = lines[line_index + 1]
      lines[line_index] = {
        start: current.start,
        end: next.start,
        width: current.width,
        text: current.text,
      }
      line_index = line_index + 1
    }
    let last_index = lines.length() - 1
    let last = lines[last_index]
    lines[last_index] = {
      start: last.start,
      end: chars.length(),
      width: last.width,
      text: last.text,
    }
  }
  { layout: { lines, segments, font, }, line_count: lines.length(), }
}
