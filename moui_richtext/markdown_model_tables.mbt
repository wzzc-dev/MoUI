///|
priv struct MarkdownTableParseResult {
  block : MarkdownBlock
  end_index : Int
}

///|
fn markdown_table_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownTableParseResult? {
  if index + 1 >= lines.length() ||
    !markdown_table_separator_line(lines[index + 1]) {
    return None
  }
  let segment_lines : Array[String] = [lines[index], lines[index + 1]]
  let mut next = index + 2
  while next < lines.length() && markdown_table_body_line(lines[next]) {
    segment_lines.push(lines[next])
    next = next + 1
  }
  Some({
    block: markdown_table_block(
      markdown_table_text_from_source_lines(segment_lines),
      markdown_table_alignments_for_separator(lines[index + 1]),
    ),
    end_index: next - 1,
  })
}

///|
fn markdown_table_separator_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if !trimmed.contains("|") {
    return false
  }
  let cells = markdown_split_table_cells(trimmed)
  if cells.length() == 0 {
    return false
  }
  for cell in cells {
    if !markdown_table_separator_cell(cell.trim().to_owned()) {
      return false
    }
  }
  true
}

///|
fn markdown_table_separator_cell(cell : String) -> Bool {
  let chars = cell.to_array()
  let mut dash_count = 0
  for ch in chars {
    if ch == '-' {
      dash_count = dash_count + 1
    } else if ch != ':' && ch != ' ' && ch != '\t' {
      return false
    }
  }
  dash_count >= 3
}

///|
fn markdown_table_body_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed != "" && trimmed.contains("|")
}

///|
pub fn markdown_split_table_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = line.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '|' {
    start = start + 1
  }
  if end > start &&
    chars[end - 1] == '|' &&
    markdown_editor_table_pipe_is_separator(chars, end - 1) {
    end = end - 1
  }
  let current : Array[Char] = []
  let mut index = start
  while index < end {
    if chars[index] == '|' &&
      markdown_editor_table_pipe_is_separator(chars, index) {
      cells.push(String::from_array(current))
      current.clear()
    } else {
      current.push(chars[index])
    }
    index = index + 1
  }
  cells.push(String::from_array(current))
  cells
}

///|
fn markdown_table_block(
  text : String,
  table_alignments : Array[@core.TextAlign?],
) -> MarkdownBlock {
  {
    kind: MarkdownBlockKind::Table,
    text,
    inlines: [],
    table_alignments,
    code_language: None,
  }
}

///|
fn markdown_table_text(
  header : Array[@md.TableCell],
  rows : Array[Array[@md.TableCell]],
) -> String {
  let lines : Array[String] = []
  lines.push(markdown_table_row_text(header))
  for row in rows {
    lines.push(markdown_table_row_text(row))
  }
  markdown_join_lines(lines)
}

///|
fn markdown_table_text_from_source_lines(lines : Array[String]) -> String {
  let rows : Array[String] = []
  for index in 0..<lines.length() {
    if index == 1 {
      continue
    }
    let cells : Array[String] = []
    for cell in markdown_split_table_cells(lines[index]) {
      cells.push(cell.trim().to_owned())
    }
    rows.push(cells.join("  |  "))
  }
  markdown_join_lines(rows)
}

///|
fn markdown_table_row_text(row : Array[@md.TableCell]) -> String {
  let cells : Array[String] = []
  for cell in row {
    cells.push(markdown_inline_text(cell.children).trim().to_owned())
  }
  cells.join("  |  ")
}

///|
fn markdown_table_preview(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> RichTextTable? {
  match block.kind {
    Table => {
      let lines = markdown_split_lines(block.text)
      if lines.length() == 0 {
        return None
      }
      let rows : Array[Array[RichTextTableCell]] = []
      let aligns = block.table_alignments
      let mut line_offset = 0
      for index in 0..<lines.length() {
        let cells : Array[RichTextTableCell] = []
        let source_line = lines[index]
        for cell in markdown_table_cell_ranges_for_line(source_line) {
          cells.push({
            text: cell.text,
            header: index == 0,
            align: markdown_table_alignment_at(aligns, cells.length()),
            source_range: Some({
              start: line_offset + cell.start,
              end: line_offset + cell.end,
            }),
          })
        }
        rows.push(cells)
        line_offset = line_offset + source_line.to_array().length() + 1
      }
      Some({
        rows,
        row_height: base.size * 1.9,
        cell_padding: @core.Insets::symmetric(horizontal=8.0, vertical=5.0),
        border: @core.Color::black().multiply_alpha(0.16),
        header_background: Some(
          @core.Brush::solid(@core.Color::rgba(r=0.08, g=0.12, b=0.16, a=0.06)),
        ),
      })
    }
    _ => None
  }
}

///|
priv struct MarkdownTableCellPreviewRange {
  text : String
  start : Int
  end : Int
}

///|
fn markdown_table_cell_ranges_for_line(
  line : String,
) -> Array[MarkdownTableCellPreviewRange] {
  let cells : Array[MarkdownTableCellPreviewRange] = []
  let chars = line.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '|' {
    start = start + 1
  }
  if end > start &&
    chars[end - 1] == '|' &&
    markdown_editor_table_pipe_is_separator(chars, end - 1) {
    end = end - 1
  }
  let mut segment_start = start
  let mut index = start
  while index <= end {
    if index == end ||
      (
        chars[index] == '|' &&
        markdown_editor_table_pipe_is_separator(chars, index)
      ) {
      let range = markdown_table_trimmed_range(chars, segment_start, index)
      cells.push({
        text: String::from_array(chars[range.start:range.end]),
        start: range.start,
        end: range.end,
      })
      segment_start = index + 1
    }
    index = index + 1
  }
  cells
}

///|
fn markdown_table_alignments_for_separator(
  line : String,
) -> Array[@core.TextAlign?] {
  let aligns : Array[@core.TextAlign?] = []
  for cell in markdown_split_table_cells(line) {
    aligns.push(markdown_table_alignment_for_separator_cell(cell))
  }
  aligns
}

///|
fn markdown_table_alignment_for_separator_cell(
  cell : String,
) -> @core.TextAlign? {
  let trimmed = cell.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() == 0 {
    return None
  }
  let leading = chars[0] == ':'
  let trailing = chars[chars.length() - 1] == ':'
  if leading && trailing {
    Some(@core.TextAlign::TextCenter)
  } else if trailing {
    Some(@core.TextAlign::TextEnd)
  } else {
    None
  }
}

///|
fn markdown_table_alignment_at(
  aligns : Array[@core.TextAlign?],
  index : Int,
) -> @core.TextAlign? {
  if index >= 0 && index < aligns.length() {
    aligns[index]
  } else {
    None
  }
}

///|
fn markdown_table_trimmed_range(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> RichTextSourceRange {
  let mut content_start = start
  let mut content_end = end
  while content_start < content_end &&
        (chars[content_start] == ' ' || chars[content_start] == '\t') {
    content_start = content_start + 1
  }
  while content_end > content_start &&
        (chars[content_end - 1] == ' ' || chars[content_end - 1] == '\t') {
    content_end = content_end - 1
  }
  { start: content_start, end: content_end }
}
