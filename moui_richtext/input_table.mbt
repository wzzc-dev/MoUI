///|
fn markdown_editor_table_cell_at_text_offset(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Bool {
  let anchor = match markdown_editor_active_selection(selection) {
    Some(range) => range.normalized().start
    None => caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      anchor < block.source_range.start ||
      anchor > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    if markdown_editor_table_cell_index_at(cells, anchor) is Some(_) {
      return true
    }
  }
  false
}

///|
fn markdown_editor_hard_break_continuation_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let indent_text = String::from_array(chars[:indent])
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    let nested = String::from_array(chars[indent + 2:])
    indent_text + "> " + markdown_editor_hard_break_continuation_prefix(nested)
  } else if chars.length() >= indent + 6 &&
    chars[indent] == '-' &&
    chars[indent + 1] == ' ' &&
    chars[indent + 2] == '[' &&
    (
      chars[indent + 3] == ' ' ||
      chars[indent + 3] == 'x' ||
      chars[indent + 3] == 'X'
    ) &&
    chars[indent + 4] == ']' &&
    chars[indent + 5] == ' ' {
    indent_text + markdown_editor_spaces(6)
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    indent_text + markdown_editor_spaces(2)
  } else {
    let ordered_end = markdown_editor_ordered_marker_length(chars)
    if ordered_end > indent {
      indent_text + markdown_editor_spaces(ordered_end - indent)
    } else {
      indent_text
    }
  }
}

///|
fn markdown_editor_spaces(count : Int) -> String {
  let chars : Array[Char] = []
  let mut index = 0
  while index < count {
    chars.push(' ')
    index = index + 1
  }
  String::from_array(chars)
}

///|
fn markdown_editor_complete_table_header_on_enter(
  chars : Array[Char],
  range : MarkdownSourceRange,
  line : String,
  caret : Int,
) -> RichTextInputTransform? {
  if caret != range.end || !markdown_editor_table_header_candidate(line) {
    return None
  }
  // 如果 header 行之后已经紧跟 separator 行（即表格已成型），则不再
  // 重复插入 separator，交给 markdown_editor_insert_table_row_on_enter 处理。
  if range.end < chars.length() && chars[range.end] == '\n' {
    let mut next_end = range.end + 1
    while next_end < chars.length() && chars[next_end] != '\n' {
      next_end = next_end + 1
    }
    let next_line = String::from_array(chars[range.end + 1:next_end])
    if markdown_editor_table_separator_line(next_line) {
      return None
    }
  }
  let column_count = markdown_editor_split_table_cells(line).length()
  if column_count <= 1 {
    return None
  }
  let separator = markdown_editor_table_separator_for_columns(column_count)
  let row = markdown_editor_empty_table_row(column_count)
  let insert = "\n" + separator + "\n" + row
  let text = String::from_array(chars[:caret]) +
    insert +
    String::from_array(chars[caret:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=caret +
        markdown_editor_text_length(insert) -
        markdown_editor_text_length(row) +
        2,
    ),
  )
}

///|
fn markdown_editor_table_header_candidate(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if !trimmed.contains("|") || markdown_editor_table_separator_line(trimmed) {
    return false
  }
  let cells = markdown_editor_split_table_cells(trimmed)
  if cells.length() <= 1 {
    return false
  }
  let chars = trimmed.to_array()
  let explicit_pipe_table = chars.length() > 1 &&
    chars[0] == '|' &&
    chars[chars.length() - 1] == '|'
  for cell in cells {
    if !explicit_pipe_table && cell.trim().to_owned() == "" {
      return false
    }
  }
  true
}

///|
fn markdown_editor_table_separator_for_columns(column_count : Int) -> String {
  let cells : Array[String] = []
  for _ in 0..<column_count {
    cells.push("---")
  }
  "| " + cells.join(" | ") + " |"
}

///|
fn markdown_editor_table_cell_text_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  match
    markdown_editor_table_cell_matrix_paste(source, caret, selection, input) {
    Some(transform) => return Some(transform)
    None => ()
  }
  if input == "\t" ||
    input == "\n" ||
    markdown_editor_active_selection(selection) is Some(_) ||
    (!input.contains("\n") && !input.contains("|")) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(_) => {
        let insert = markdown_editor_table_cell_safe_input(input)
        if insert == input {
          return None
        }
        return Some(
          markdown_editor_transform_result(
            text=String::from_array(chars[:caret]) +
              insert +
              String::from_array(chars[caret:]),
            caret=caret + markdown_editor_text_length(insert),
          ),
        )
      }
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_table_cell_matrix_paste(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if input == "\t" || markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let paste = match markdown_editor_table_matrix_paste(input) {
    Some(paste) => paste
    None => return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return Some(
          markdown_editor_apply_table_paste_grid(
            source,
            block,
            cells[index],
            paste.grid,
            paste.alignments,
            caret,
          ),
        )
      None => return None
    }
  }
  None
}

///|
priv struct MarkdownEditorTableMatrixPaste {
  grid : Array[Array[String]]
  alignments : Array[@core.TextAlign?]
}

///|
fn markdown_editor_table_matrix_paste(
  input : String,
) -> MarkdownEditorTableMatrixPaste? {
  if input.contains("\t") {
    let grid = markdown_editor_table_paste_grid(input)
    if grid.length() == 0 ||
      markdown_editor_table_paste_grid_column_count(grid) <= 1 {
      None
    } else {
      Some({ grid, alignments: [] })
    }
  } else {
    match markdown_editor_markdown_table_paste(input) {
      Some(table) => Some({ grid: table.grid, alignments: table.alignments })
      None => None
    }
  }
}

///|
fn markdown_editor_table_paste_grid(input : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for line in markdown_editor_paste_lines(input) {
    let row : Array[String] = []
    for cell in markdown_editor_split_tsv_cells(line) {
      row.push(markdown_editor_table_cell_safe_input(cell))
    }
    rows.push(row)
  }
  rows
}

///|
fn markdown_editor_split_tsv_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = line.to_array()
  let current : Array[Char] = []
  let mut index = 0
  while index <= chars.length() {
    if index == chars.length() || chars[index] == '\t' {
      cells.push(String::from_array(current))
      current.clear()
    } else {
      current.push(chars[index])
    }
    index = index + 1
  }
  cells
}

///|
fn markdown_editor_table_paste_grid_column_count(
  grid : Array[Array[String]],
) -> Int {
  let mut count = 0
  for row in grid {
    if row.length() > count {
      count = row.length()
    }
  }
  count
}

///|
fn markdown_editor_paste_tsv_as_table(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if input == "\t" ||
    !input.contains("\t") ||
    markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let grid = markdown_editor_table_paste_grid(input)
  if grid.length() == 0 ||
    markdown_editor_table_paste_grid_column_count(grid) <= 1 {
    return None
  }
  let table = markdown_editor_table_text_from_paste_grid(grid)
  markdown_editor_paste_table_text_as_block(source, caret, selection, table)
}

///|
fn markdown_editor_paste_markdown_table_as_table(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  match markdown_editor_markdown_table_paste(input) {
    Some(table) =>
      markdown_editor_paste_table_text_as_block(
        source,
        caret,
        selection,
        table.table_text,
      )
    None => None
  }
}

///|
fn markdown_editor_paste_table_text_as_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  table : String,
) -> RichTextInputTransform? {
  markdown_editor_paste_block_text_as_block(source, caret, selection, table)
}

///|
fn markdown_editor_paste_block_text_as_block(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  block_text : String,
) -> RichTextInputTransform? {
  let chars = source.to_array()
  let range = match markdown_editor_active_selection(selection) {
    Some(active) => active.normalized()
    None => {
      let caret = markdown_editor_clamp_int(caret, 0, chars.length())
      @core.TextRange::new(start=caret, end=caret)
    }
  }
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let prefix = markdown_editor_block_insert_prefix(chars, start)
  let suffix = markdown_editor_block_insert_suffix(chars, end)
  let text = String::from_array(chars[:start]) +
    prefix +
    block_text +
    suffix +
    String::from_array(chars[end:])
  Some(
    markdown_editor_transform_result(
      text~,
      caret=start +
        markdown_editor_text_length(prefix) +
        markdown_editor_text_length(block_text),
    ),
  )
}

///|
priv struct MarkdownEditorPastedMarkdownTable {
  grid : Array[Array[String]]
  alignments : Array[@core.TextAlign?]
  table_text : String
}

///|
fn markdown_editor_markdown_table_paste(
  input : String,
) -> MarkdownEditorPastedMarkdownTable? {
  if !input.contains("|") || input.contains("\t") {
    return None
  }
  let source_lines = markdown_editor_paste_lines(input)
  let table_lines = markdown_editor_trim_blank_table_paste_lines(source_lines)
  if table_lines.length() < 2 ||
    !markdown_editor_table_header_candidate(table_lines[0]) ||
    !markdown_editor_table_separator_line(table_lines[1]) {
    return None
  }
  let header = markdown_editor_markdown_table_paste_cells(table_lines[0])
  if header.length() <= 1 {
    return None
  }
  let separator_cells = markdown_editor_split_table_cells(table_lines[1])
  if separator_cells.length() != header.length() {
    return None
  }
  let grid : Array[Array[String]] = [header]
  for index in 2..<table_lines.length() {
    let line = table_lines[index]
    if !markdown_editor_table_body_line(line) ||
      markdown_editor_table_separator_line(line) {
      return None
    }
    grid.push(markdown_editor_markdown_table_paste_cells(line))
  }
  Some({
    grid,
    alignments: markdown_table_alignments_for_separator(table_lines[1]),
    table_text: markdown_join_lines(table_lines),
  })
}

///|
fn markdown_editor_trim_blank_table_paste_lines(
  lines : Array[String],
) -> Array[String] {
  let mut start = 0
  let mut end = lines.length()
  while start < end && markdown_editor_blank_source_line(lines[start]) {
    start = start + 1
  }
  while end > start && markdown_editor_blank_source_line(lines[end - 1]) {
    end = end - 1
  }
  let trimmed : Array[String] = []
  for index in start..<end {
    trimmed.push(lines[index].trim().to_owned())
  }
  trimmed
}

///|
fn markdown_editor_markdown_table_paste_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  for cell in markdown_editor_split_table_cells(line) {
    cells.push(cell.trim().to_owned())
  }
  cells
}

///|
fn markdown_editor_table_text_from_paste_grid(
  grid : Array[Array[String]],
) -> String {
  let column_count = markdown_editor_table_paste_grid_column_count(grid)
  let lines : Array[String] = []
  lines.push(
    markdown_editor_table_paste_join_cells(
      markdown_editor_table_paste_padded_row(grid[0], column_count),
    ),
  )
  let separators : Array[String] = []
  for _ in 0..<column_count {
    separators.push("---")
  }
  lines.push(markdown_editor_table_paste_join_cells(separators))
  if grid.length() == 1 {
    let empty : Array[String] = []
    for _ in 0..<column_count {
      empty.push("")
    }
    lines.push(markdown_editor_table_paste_join_cells(empty))
  } else {
    for row_index in 1..<grid.length() {
      lines.push(
        markdown_editor_table_paste_join_cells(
          markdown_editor_table_paste_padded_row(grid[row_index], column_count),
        ),
      )
    }
  }
  markdown_join_lines(lines)
}

///|
fn markdown_editor_table_paste_padded_row(
  row : Array[String],
  column_count : Int,
) -> Array[String] {
  let cells : Array[String] = []
  for cell in row {
    cells.push(cell)
  }
  while cells.length() < column_count {
    cells.push("")
  }
  cells
}

///|
fn markdown_editor_block_insert_prefix(
  chars : Array[Char],
  start : Int,
) -> String {
  if start <= 0 {
    ""
  } else if chars[start - 1] == '\n' {
    if start >= 2 && chars[start - 2] == '\n' {
      ""
    } else {
      "\n"
    }
  } else {
    "\n\n"
  }
}

///|
fn markdown_editor_block_insert_suffix(
  chars : Array[Char],
  end : Int,
) -> String {
  if end >= chars.length() {
    ""
  } else if chars[end] == '\n' {
    if end + 1 < chars.length() && chars[end + 1] == '\n' {
      ""
    } else {
      "\n"
    }
  } else {
    "\n\n"
  }
}

///|
fn markdown_editor_apply_table_paste_grid(
  source : String,
  block : MarkdownEditorBlock,
  current : MarkdownEditorTableCellRange,
  grid : Array[Array[String]],
  alignments : Array[@core.TextAlign?],
  caret : Int,
) -> RichTextInputTransform {
  let table_lines = markdown_editor_source_lines_for_range(
    source,
    block.source_range,
  )
  let existing_rows = markdown_editor_max_int(0, table_lines.length() - 1)
  let grid_columns = markdown_editor_table_paste_grid_column_count(grid)
  let column_count = markdown_editor_max_int(
    markdown_editor_table_column_count(
      markdown_editor_table_cells_for_block(source, block),
    ),
    current.column + grid_columns,
  )
  let row_count = markdown_editor_max_int(
    existing_rows,
    current.row + grid.length(),
  )
  let lines : Array[String] = []
  let first = markdown_editor_table_paste_row_line(
    table_lines, 0, column_count, current, grid, caret, source,
  )
  lines.push(first)
  lines.push(
    markdown_editor_table_paste_separator_line(
      table_lines, column_count, current, alignments,
    ),
  )
  for row in 1..<row_count {
    lines.push(
      markdown_editor_table_paste_row_line(
        table_lines, row, column_count, current, grid, caret, source,
      ),
    )
  }
  let table_text = markdown_join_lines(lines)
  let text = markdown_editor_substring(source, 0, block.source_range.start) +
    table_text +
    markdown_editor_substring(
      source,
      block.source_range.end,
      markdown_editor_text_length(source),
    )
  let target = markdown_editor_table_paste_last_target(current, grid)
  markdown_editor_transform_result(
    text~,
    caret=markdown_editor_table_paste_caret(
      table_text,
      block.source_range.start,
      target.row,
      target.column,
    ),
  )
}

///|
fn markdown_editor_source_lines_for_range(
  source : String,
  range : MarkdownSourceRange,
) -> Array[String] {
  let lines : Array[String] = []
  for line in markdown_editor_lines(source) {
    if line.start >= range.start && line.end <= range.end {
      lines.push(line.text)
    }
  }
  lines
}

///|
fn markdown_editor_table_paste_row_line(
  table_lines : Array[String],
  row : Int,
  column_count : Int,
  current : MarkdownEditorTableCellRange,
  grid : Array[Array[String]],
  caret : Int,
  source : String,
) -> String {
  let line_index = if row == 0 { 0 } else { row + 1 }
  let base = if line_index < table_lines.length() {
    table_lines[line_index]
  } else {
    ""
  }
  let cells = markdown_editor_table_paste_cells(base, column_count)
  let paste_row = row - current.row
  if paste_row >= 0 && paste_row < grid.length() {
    let pasted = grid[paste_row]
    for paste_column in 0..<pasted.length() {
      let column = current.column + paste_column
      if column < cells.length() {
        cells[column] = if paste_row == 0 && paste_column == 0 {
          markdown_editor_insert_table_paste_cell(
            markdown_editor_table_paste_cell_at(cells, column),
            pasted[paste_column],
            source,
            current,
            caret,
          )
        } else {
          pasted[paste_column]
        }
      }
    }
  }
  markdown_editor_table_paste_join_cells(cells)
}

///|
fn markdown_editor_table_paste_cells(
  line : String,
  column_count : Int,
) -> Array[String] {
  let cells : Array[String] = []
  if line != "" {
    for cell in markdown_editor_split_table_cells(line) {
      cells.push(cell.trim().to_owned())
    }
  }
  while cells.length() < column_count {
    cells.push("")
  }
  cells
}

///|
fn markdown_editor_table_paste_cell_at(
  cells : Array[String],
  column : Int,
) -> String {
  if column < cells.length() {
    cells[column]
  } else {
    ""
  }
}

///|
fn markdown_editor_insert_table_paste_cell(
  original : String,
  insert : String,
  source : String,
  current : MarkdownEditorTableCellRange,
  caret : Int,
) -> String {
  let content = markdown_editor_substring(
    source,
    current.content_start,
    current.content_end,
  )
  let local_offset = markdown_editor_clamp_int(
    caret - current.content_start,
    0,
    markdown_editor_text_length(content),
  )
  if content == original {
    markdown_editor_substring(content, 0, local_offset) +
    insert +
    markdown_editor_substring(
      content,
      local_offset,
      markdown_editor_text_length(content),
    )
  } else {
    markdown_editor_substring(original, 0, local_offset) +
    insert +
    markdown_editor_substring(
      original,
      local_offset,
      markdown_editor_text_length(original),
    )
  }
}

///|
fn markdown_editor_table_paste_separator_line(
  table_lines : Array[String],
  column_count : Int,
  current : MarkdownEditorTableCellRange,
  alignments : Array[@core.TextAlign?],
) -> String {
  let base = if table_lines.length() > 1 { table_lines[1] } else { "" }
  let cells = markdown_editor_table_paste_cells(base, column_count)
  for index in 0..<cells.length() {
    if cells[index] == "" {
      cells[index] = "---"
    }
  }
  for paste_column in 0..<alignments.length() {
    let column = current.column + paste_column
    if column >= 0 && column < cells.length() {
      cells[column] = markdown_editor_table_alignment_marker(
        alignments[paste_column],
      )
    }
  }
  markdown_editor_table_paste_join_cells(cells)
}

///|
fn markdown_editor_table_paste_join_cells(cells : Array[String]) -> String {
  "| " + cells.join(" | ") + " |"
}

///|
priv struct MarkdownEditorTablePasteTarget {
  row : Int
  column : Int
}

///|
fn markdown_editor_table_paste_last_target(
  current : MarkdownEditorTableCellRange,
  grid : Array[Array[String]],
) -> MarkdownEditorTablePasteTarget {
  if grid.length() == 0 {
    return { row: current.row, column: current.column }
  }
  let row = current.row + markdown_editor_max_int(0, grid.length() - 1)
  let last = grid[grid.length() - 1]
  let column = current.column + markdown_editor_max_int(0, last.length() - 1)
  { row, column }
}

///|
fn markdown_editor_table_paste_caret(
  table_text : String,
  table_start : Int,
  row : Int,
  column : Int,
) -> Int {
  let lines = markdown_editor_lines(table_text)
  let line_index = if row == 0 { 0 } else { row + 1 }
  if line_index >= lines.length() {
    return table_start + markdown_editor_text_length(table_text)
  }
  let line = lines[line_index]
  let cells = markdown_editor_table_cells_for_line(
    {
      text: line.text,
      start: table_start + line.start,
      end: table_start + line.end,
    },
    row,
  )
  for cell in cells {
    if cell.column == column {
      return cell.content_end
    }
  }
  table_start + line.end
}

///|
fn markdown_editor_table_cell_safe_input(input : String) -> String {
  let chars = input.to_array()
  let out : Array[Char] = []
  let mut index = 0
  let mut previous_was_space = false
  while index < chars.length() {
    let ch = chars[index]
    if ch == '\n' || ch == '\r' {
      if !previous_was_space {
        out.push(' ')
        previous_was_space = true
      }
    } else if ch == '|' && markdown_editor_table_pipe_is_separator(chars, index) {
      out.push('\\')
      out.push('|')
      previous_was_space = false
    } else {
      out.push(ch)
      previous_was_space = ch == ' ' || ch == '\t'
    }
    index = index + 1
  }
  String::from_array(out)
}

///|
