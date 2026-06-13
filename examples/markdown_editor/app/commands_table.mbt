///|
struct MarkdownEditorTableCellRange {
  hit_start : Int
  hit_end : Int
  content_start : Int
  content_end : Int
  row : Int
  column : Int
} derive(Eq, Debug)

///|
fn markdown_editor_move_table_cell(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  forward~ : Bool,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
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
    if cells.length() == 0 {
      return None
    }
    let current = markdown_editor_table_cell_index_at(cells, caret)
    match current {
      Some(index) =>
        if forward {
          if index + 1 < cells.length() {
            return Some(
              markdown_editor_transform_result(
                text=source,
                caret=cells[index + 1].content_start,
              ),
            )
          }
          return Some(
            markdown_editor_append_table_row(source, block, cells[0].row),
          )
        } else if index > 0 {
          return Some(
            markdown_editor_transform_result(
              text=source,
              caret=cells[index - 1].content_start,
            ),
          )
        } else {
          return Some(
            markdown_editor_exit_table_before_table_start(source, block),
          )
        }
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_exit_table_before_table_start(
  source : String,
  block : MarkdownEditorBlock,
) -> @core.RichTextInputTransform {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(
    block.source_range.start,
    0,
    chars.length(),
  )
  if start == 0 {
    return markdown_editor_transform_result(text="\n" + source, caret=0)
  }
  if chars[start - 1] == '\n' {
    if start == 1 || (start >= 2 && chars[start - 2] == '\n') {
      return markdown_editor_transform_result(text=source, caret=start - 1)
    }
    let text = String::from_array(chars[:start]) +
      "\n" +
      String::from_array(chars[start:])
    return markdown_editor_transform_result(text~, caret=start)
  }
  markdown_editor_transform_result(
    text=String::from_array(chars[:start]) +
      "\n\n" +
      String::from_array(chars[start:]),
    caret=start + 1,
  )
}

///|
fn markdown_editor_table_cells_for_block(
  source : String,
  block : MarkdownEditorBlock,
) -> Array[MarkdownEditorTableCellRange] {
  let cells : Array[MarkdownEditorTableCellRange] = []
  let lines = markdown_editor_lines(source)
  let mut table_line_index = 0
  let mut row = 0
  for line in lines {
    if line.start < block.source_range.start ||
      line.end > block.source_range.end {
      continue
    }
    if table_line_index != 1 {
      cells.append(markdown_editor_table_cells_for_line(line, row))
      row = row + 1
    }
    table_line_index = table_line_index + 1
  }
  cells
}

///|
fn markdown_editor_table_cells_for_line(
  line : MarkdownLine,
  row : Int,
) -> Array[MarkdownEditorTableCellRange] {
  let cells : Array[MarkdownEditorTableCellRange] = []
  let chars = line.text.to_array()
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
  let mut column = 0
  while index <= end {
    if index == end ||
      (
        chars[index] == '|' &&
        markdown_editor_table_pipe_is_separator(chars, index)
      ) {
      let content = markdown_editor_table_cell_content_range(
        chars, segment_start, index,
      )
      cells.push({
        hit_start: line.start + segment_start,
        hit_end: line.start + index,
        content_start: line.start + content.start,
        content_end: line.start + content.end,
        row,
        column,
      })
      column = column + 1
      segment_start = index + 1
    }
    index = index + 1
  }
  cells
}

///|
fn markdown_editor_table_pipe_is_separator(
  chars : Array[Char],
  index : Int,
) -> Bool {
  if index < 0 || index >= chars.length() || chars[index] != '|' {
    return false
  }
  let mut slash_count = 0
  let mut cursor = index - 1
  while cursor >= 0 && chars[cursor] == '\\' {
    slash_count = slash_count + 1
    cursor = cursor - 1
  }
  slash_count % 2 == 0
}

///|
fn markdown_editor_table_cell_content_range(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> MarkdownSourceRange {
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

///|
fn markdown_editor_table_cell_index_at(
  cells : Array[MarkdownEditorTableCellRange],
  caret : Int,
) -> Int? {
  for index in 0..<cells.length() {
    let cell = cells[index]
    if caret >= cell.hit_start && caret <= cell.hit_end {
      return Some(index)
    }
  }
  None
}

///|
fn markdown_editor_insert_table_row_on_enter(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
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
    if cells.length() == 0 {
      return None
    }
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) => {
        match
          markdown_editor_exit_table_after_empty_last_row_on_enter(
            source,
            block,
            cells,
            cells[index],
          ) {
          Some(transform) => return Some(transform)
          None => ()
        }
        return Some(
          markdown_editor_insert_table_row_after_cell(
            source,
            cells,
            cells[index],
          ),
        )
      }
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_exit_table_after_empty_last_row_on_enter(
  source : String,
  block : MarkdownEditorBlock,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> @core.RichTextInputTransform? {
  if current.row <= 0 ||
    current.row != markdown_editor_table_last_data_row(cells) ||
    !markdown_editor_table_row_empty(source, cells, current.row) {
    return None
  }
  let data_row_count = markdown_editor_table_data_row_count(cells)
  if data_row_count > 1 {
    let row_start = markdown_editor_table_row_start(cells, current.row)
    let row_end = markdown_editor_table_row_end(source, cells, current.row)
    let chars = source.to_array()
    let remove_start = if row_start > 0 && chars[row_start - 1] == '\n' {
      row_start - 1
    } else {
      row_start
    }
    let text = String::from_array(chars[:remove_start]) +
      String::from_array(chars[row_end:])
    return Some(markdown_editor_exit_table_after_table_end(text, remove_start))
  }
  Some(
    markdown_editor_exit_table_after_table_end(source, block.source_range.end),
  )
}

///|
fn markdown_editor_table_last_data_row(
  cells : Array[MarkdownEditorTableCellRange],
) -> Int {
  let mut row = 0
  for cell in cells {
    if cell.row > row {
      row = cell.row
    }
  }
  row
}

///|
fn markdown_editor_table_row_empty(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  row : Int,
) -> Bool {
  let mut found = false
  for cell in cells {
    if cell.row == row {
      found = true
      let text = markdown_editor_substring(
        source,
        cell.content_start,
        cell.content_end,
      )
      if text.trim().to_owned() != "" {
        return false
      }
    }
  }
  found
}

///|
fn markdown_editor_exit_table_after_table_end(
  source : String,
  table_end : Int,
) -> @core.RichTextInputTransform {
  let chars = source.to_array()
  let table_end = markdown_editor_clamp_int(table_end, 0, chars.length())
  if table_end >= chars.length() {
    return markdown_editor_transform_result(
      text=source + "\n",
      caret=table_end + 1,
    )
  }
  if chars[table_end] == '\n' {
    let caret = table_end + 1
    if caret < chars.length() && chars[caret] == '\n' {
      markdown_editor_transform_result(text=source, caret~)
    } else {
      markdown_editor_transform_result(
        text=String::from_array(chars[:caret]) +
          "\n" +
          String::from_array(chars[caret:]),
        caret~,
      )
    }
  } else {
    markdown_editor_transform_result(
      text=String::from_array(chars[:table_end]) +
        "\n\n" +
        String::from_array(chars[table_end:]),
      caret=table_end + 1,
    )
  }
}

///|
fn markdown_editor_backspace_empty_trailing_table_row(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  markdown_editor_remove_empty_trailing_table_row_at_caret(
    source, caret, selection,
  )
}

///|
fn markdown_editor_delete_empty_trailing_table_row(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  markdown_editor_remove_empty_trailing_table_row_at_caret(
    source, caret, selection,
  )
}

///|
fn markdown_editor_remove_empty_trailing_table_row_at_caret(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> @core.RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let caret = markdown_editor_clamp_int(
    caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    if cells.length() == 0 {
      return None
    }
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return markdown_editor_remove_empty_trailing_table_row_on_backspace(
          source,
          cells,
          cells[index],
        )
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_remove_empty_trailing_table_row_on_backspace(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> @core.RichTextInputTransform? {
  if current.row <= 0 ||
    current.row != markdown_editor_table_last_data_row(cells) ||
    markdown_editor_table_data_row_count(cells) <= 1 ||
    !markdown_editor_table_row_empty(source, cells, current.row) {
    return None
  }
  let row_start = markdown_editor_table_row_start(cells, current.row)
  let row_end = markdown_editor_table_row_end(source, cells, current.row)
  let chars = source.to_array()
  let remove_start = if row_start > 0 && chars[row_start - 1] == '\n' {
    row_start - 1
  } else {
    row_start
  }
  let text = String::from_array(chars[:remove_start]) +
    String::from_array(chars[row_end:])
  let caret = markdown_editor_previous_table_row_column_caret(
    cells,
    current.row,
    current.column,
  )
  Some(
    markdown_editor_transform_result(
      text~,
      caret=markdown_editor_clamp_int(
        caret,
        0,
        markdown_editor_text_length(text),
      ),
    ),
  )
}

///|
fn markdown_editor_previous_table_row_column_caret(
  cells : Array[MarkdownEditorTableCellRange],
  row : Int,
  column : Int,
) -> Int {
  let mut fallback = 0
  for cell in cells {
    if cell.row == row - 1 {
      if cell.column == 0 {
        fallback = cell.content_end
      }
      if cell.column == column {
        return cell.content_end
      }
    }
  }
  fallback
}

///|
fn markdown_editor_insert_table_row(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_noop_result(source, Some(selection))
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) => {
        let transform = markdown_editor_insert_table_row_after_cell(
          source,
          cells,
          cells[index],
        )
        return {
          source: transform.text,
          caret: transform.caret,
          selection: transform.selection,
        }
      }
      None => ()
    }
  }
  markdown_editor_noop_result(source, Some(selection))
}

///|
fn markdown_editor_insert_table_row_after_cell(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> @core.RichTextInputTransform {
  let column_count = markdown_editor_table_column_count(cells)
  let column_count = if column_count <= 0 { 1 } else { column_count }
  let row = markdown_editor_empty_table_row(column_count)
  let row_end = markdown_editor_table_insert_row_end(source, cells, current)
  let chars = source.to_array()
  let text = String::from_array(chars[:row_end]) +
    "\n" +
    row +
    String::from_array(chars[row_end:])
  let target_column = markdown_editor_clamp_int(
    current.column,
    0,
    column_count - 1,
  )
  markdown_editor_transform_result(
    text~,
    caret=row_end +
      1 +
      markdown_editor_empty_table_row_column_caret(target_column),
  )
}

///|
fn markdown_editor_table_insert_row_end(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> Int {
  let row_end = markdown_editor_table_row_end(source, cells, current.row)
  if current.row != 0 {
    return row_end
  }
  let chars = source.to_array()
  if row_end >= chars.length() || chars[row_end] != '\n' {
    return row_end
  }
  markdown_editor_table_row_line_end(chars, row_end + 1)
}

///|
fn markdown_editor_table_row_line_end(chars : Array[Char], start : Int) -> Int {
  let mut end = markdown_editor_clamp_int(start, 0, chars.length())
  while end < chars.length() && chars[end] != '\n' {
    end = end + 1
  }
  end
}

///|
fn markdown_editor_table_column_count(
  cells : Array[MarkdownEditorTableCellRange],
) -> Int {
  let mut count = 0
  for cell in cells {
    if cell.column + 1 > count {
      count = cell.column + 1
    }
  }
  count
}

///|
fn markdown_editor_table_row_end(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  row : Int,
) -> Int {
  let mut end = 0
  for cell in cells {
    if cell.row == row && cell.hit_end > end {
      end = cell.hit_end
    }
  }
  let chars = source.to_array()
  while end < chars.length() && chars[end] != '\n' {
    end = end + 1
  }
  end
}

///|
fn markdown_editor_empty_table_row_column_caret(column : Int) -> Int {
  2 + column * 3
}

///|
fn markdown_editor_insert_table_column(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_noop_result(source, Some(selection))
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return markdown_editor_insert_table_column_after_cell(
          source,
          block,
          cells[index],
        )
      None => ()
    }
  }
  markdown_editor_noop_result(source, Some(selection))
}

///|
fn markdown_editor_insert_table_column_after_cell(
  source : String,
  block : MarkdownEditorBlock,
  current : MarkdownEditorTableCellRange,
) -> MarkdownEditorEditResult {
  let lines = markdown_editor_lines(source)
  let mut text = ""
  let mut table_line_index = 0
  let mut row = 0
  let mut caret = block.source_range.end
  for index, line in lines {
    if index > 0 {
      text = text + "\n"
    }
    if line.start < block.source_range.start ||
      line.end > block.source_range.end {
      text = text + line.text
      continue
    }
    let inserted_text = if table_line_index == 1 {
      markdown_editor_insert_table_column_in_line(
        line.text,
        current.column,
        "---",
      )
    } else {
      let next = markdown_editor_insert_table_column_in_line(
        line.text,
        current.column,
        "",
      )
      if row == current.row {
        caret = line.start +
          markdown_editor_table_column_content_start(next, current.column + 1)
      }
      row = row + 1
      next
    }
    text = text + inserted_text
    table_line_index = table_line_index + 1
  }
  { source: text, caret, selection: None }
}

///|
fn markdown_editor_insert_table_column_in_line(
  line : String,
  column : Int,
  inserted : String,
) -> String {
  let cells = markdown_editor_split_table_cells(line)
  let insert_at = markdown_editor_clamp_int(column + 1, 0, cells.length())
  let parts : Array[String] = []
  for index in 0..<=cells.length() {
    if index == insert_at {
      parts.push(inserted)
    }
    if index < cells.length() {
      parts.push(cells[index].trim().to_owned())
    }
  }
  "| " + parts.join(" | ") + " |"
}

///|
fn markdown_editor_table_column_content_start(
  line : String,
  column : Int,
) -> Int {
  let cells = markdown_editor_table_cells_for_line(
    { text: line, start: 0, end: markdown_editor_text_length(line) },
    0,
  )
  for cell in cells {
    if cell.column == column {
      return cell.content_start
    }
  }
  markdown_editor_text_length(line)
}

///|
fn markdown_editor_delete_table_row(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_noop_result(source, Some(selection))
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return markdown_editor_delete_table_row_at_cell(
          source,
          cells,
          cells[index],
        )
      None => ()
    }
  }
  markdown_editor_noop_result(source, Some(selection))
}

///|
fn markdown_editor_delete_table_column(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_noop_result(source, Some(selection))
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return markdown_editor_delete_table_column_at_cell(
          source,
          block,
          cells,
          cells[index],
        )
      None => ()
    }
  }
  markdown_editor_noop_result(source, Some(selection))
}

///|
fn markdown_editor_set_table_column_alignment(
  source : String,
  selection : MarkdownEditorSelection,
  align : @core.TextAlign?,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_noop_result(source, Some(selection))
  }
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Table) ||
      caret < block.source_range.start ||
      caret > block.source_range.end {
      continue
    }
    let cells = markdown_editor_table_cells_for_block(source, block)
    match markdown_editor_table_cell_index_at(cells, caret) {
      Some(index) =>
        return markdown_editor_rewrite_table_alignment(
          source,
          block,
          cells[index],
          align,
        )
      None => ()
    }
  }
  markdown_editor_noop_result(source, Some(selection))
}

///|
fn markdown_editor_rewrite_table_alignment(
  source : String,
  block : MarkdownEditorBlock,
  current : MarkdownEditorTableCellRange,
  align : @core.TextAlign?,
) -> MarkdownEditorEditResult {
  let lines = markdown_editor_lines(source)
  let mut text = ""
  let mut table_line_index = 0
  for index, line in lines {
    if index > 0 {
      text = text + "\n"
    }
    if line.start < block.source_range.start ||
      line.end > block.source_range.end {
      text = text + line.text
      continue
    }
    if table_line_index == 1 {
      text = text +
        markdown_editor_rewrite_table_alignment_line(
          line.text,
          current.column,
          align,
        )
    } else {
      text = text + line.text
    }
    table_line_index = table_line_index + 1
  }
  { source: text, caret: current.content_start, selection: None }
}

///|
fn markdown_editor_rewrite_table_alignment_line(
  line : String,
  column : Int,
  align : @core.TextAlign?,
) -> String {
  let cells = markdown_editor_split_table_cells(line)
  if cells.length() == 0 {
    return line
  }
  let column = markdown_editor_clamp_int(column, 0, cells.length() - 1)
  let parts : Array[String] = []
  for index in 0..<cells.length() {
    if index == column {
      parts.push(markdown_editor_table_alignment_marker(align))
    } else {
      parts.push(cells[index].trim().to_owned())
    }
  }
  "| " + parts.join(" | ") + " |"
}

///|
fn markdown_editor_table_alignment_marker(align : @core.TextAlign?) -> String {
  match align {
    Some(@core.TextAlign::TextStart) => ":---"
    Some(@core.TextAlign::TextCenter) => ":---:"
    Some(@core.TextAlign::TextEnd) => "---:"
    None => "---"
  }
}

///|
fn markdown_editor_delete_table_column_at_cell(
  source : String,
  block : MarkdownEditorBlock,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> MarkdownEditorEditResult {
  let column_count = markdown_editor_table_column_count(cells)
  if column_count <= 1 {
    return markdown_editor_clear_table_column(source, block, current)
  }
  markdown_editor_rewrite_table_column(
    source,
    block,
    current.column,
    delete=true,
    clear=false,
  )
}

///|
fn markdown_editor_clear_table_column(
  source : String,
  block : MarkdownEditorBlock,
  current : MarkdownEditorTableCellRange,
) -> MarkdownEditorEditResult {
  markdown_editor_rewrite_table_column(
    source,
    block,
    current.column,
    delete=false,
    clear=true,
  )
}

///|
fn markdown_editor_rewrite_table_column(
  source : String,
  block : MarkdownEditorBlock,
  column : Int,
  delete~ : Bool,
  clear~ : Bool,
) -> MarkdownEditorEditResult {
  let lines = markdown_editor_lines(source)
  let mut text = ""
  let mut table_line_index = 0
  let mut row = 0
  let mut caret = block.source_range.start
  for index, line in lines {
    if index > 0 {
      text = text + "\n"
    }
    if line.start < block.source_range.start ||
      line.end > block.source_range.end {
      text = text + line.text
      continue
    }
    let replacement = if table_line_index == 1 {
      markdown_editor_rewrite_table_column_in_line(
        line.text,
        column,
        "",
        delete~,
        clear=false,
      )
    } else {
      let next = markdown_editor_rewrite_table_column_in_line(
        line.text,
        column,
        "",
        delete~,
        clear~,
      )
      if row == 0 {
        caret = line.start +
          markdown_editor_table_column_content_start(
            next,
            if delete {
              markdown_editor_max_int(0, column - 1)
            } else {
              column
            },
          )
      }
      row = row + 1
      next
    }
    text = text + replacement
    table_line_index = table_line_index + 1
  }
  { source: text, caret, selection: None }
}

///|
fn markdown_editor_rewrite_table_column_in_line(
  line : String,
  column : Int,
  delete~ : Bool,
  clear~ : Bool,
  clear_text : String,
) -> String {
  let cells = markdown_editor_split_table_cells(line)
  let column = markdown_editor_clamp_int(column, 0, cells.length() - 1)
  let parts : Array[String] = []
  for index in 0..<cells.length() {
    if index == column {
      if clear {
        parts.push(clear_text)
      } else if !delete {
        parts.push(cells[index].trim().to_owned())
      }
    } else {
      parts.push(cells[index].trim().to_owned())
    }
  }
  if parts.length() == 0 {
    parts.push(clear_text)
  }
  "| " + parts.join(" | ") + " |"
}

///|
fn markdown_editor_delete_table_row_at_cell(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> MarkdownEditorEditResult {
  if current.row == 0 {
    return markdown_editor_clear_table_row(source, cells, current)
  }
  let data_row_count = markdown_editor_table_data_row_count(cells)
  if data_row_count <= 1 {
    return markdown_editor_clear_table_row(source, cells, current)
  }
  let row_start = markdown_editor_table_row_start(cells, current.row)
  let row_end = markdown_editor_table_row_end(source, cells, current.row)
  let chars = source.to_array()
  let remove_start = if row_start > 0 && chars[row_start - 1] == '\n' {
    row_start - 1
  } else {
    row_start
  }
  let text = String::from_array(chars[:remove_start]) +
    String::from_array(chars[row_end:])
  let caret = markdown_editor_clamp_int(
    remove_start,
    0,
    markdown_editor_text_length(text),
  )
  { source: text, caret, selection: None }
}

///|
fn markdown_editor_clear_table_row(
  source : String,
  cells : Array[MarkdownEditorTableCellRange],
  current : MarkdownEditorTableCellRange,
) -> MarkdownEditorEditResult {
  let column_count = markdown_editor_table_column_count(cells)
  let row_start = markdown_editor_table_row_start(cells, current.row)
  let row_end = markdown_editor_table_row_end(source, cells, current.row)
  let row = markdown_editor_empty_table_row(column_count)
  let chars = source.to_array()
  let text = String::from_array(chars[:row_start]) +
    row +
    String::from_array(chars[row_end:])
  { source: text, caret: row_start + 2, selection: None }
}

///|
fn markdown_editor_table_data_row_count(
  cells : Array[MarkdownEditorTableCellRange],
) -> Int {
  let mut count = 0
  for cell in cells {
    if cell.row > 0 && cell.column == 0 {
      count = count + 1
    }
  }
  count
}

///|
fn markdown_editor_table_row_start(
  cells : Array[MarkdownEditorTableCellRange],
  row : Int,
) -> Int {
  let mut start = -1
  for cell in cells {
    if cell.row == row && (start < 0 || cell.hit_start < start) {
      start = cell.hit_start
    }
  }
  if start < 0 {
    0
  } else {
    start - 1
  }
}

///|
fn markdown_editor_append_table_row(
  source : String,
  block : MarkdownEditorBlock,
  first_row : Int,
) -> @core.RichTextInputTransform {
  let cells = markdown_editor_table_cells_for_block(source, block)
  let column_count = cells.filter(cell => cell.row == first_row).length()
  let column_count = if column_count <= 0 { 1 } else { column_count }
  let row = markdown_editor_empty_table_row(column_count)
  let chars = source.to_array()
  let text = String::from_array(chars[:block.source_range.end]) +
    "\n" +
    row +
    String::from_array(chars[block.source_range.end:])
  markdown_editor_transform_result(text~, caret=block.source_range.end + 3)
}

///|
fn markdown_editor_empty_table_row(column_count : Int) -> String {
  let cells : Array[String] = []
  for _ in 0..<column_count {
    cells.push("")
  }
  "| " + cells.join(" | ") + " |"
}

///|
