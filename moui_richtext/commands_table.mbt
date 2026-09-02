///|
priv struct MarkdownEditorTableCellRange {
  hit_start : Int
  hit_end : Int
  content_start : Int
  content_end : Int
  row : Int
  column : Int
}

///|
fn markdown_editor_move_table_cell(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  forward~ : Bool,
) -> RichTextInputTransform? {
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
) -> RichTextInputTransform {
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
) -> RichTextInputTransform? {
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
) -> RichTextInputTransform? {
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
) -> RichTextInputTransform {
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
) -> RichTextInputTransform? {
  markdown_editor_remove_empty_trailing_table_row_at_caret(
    source, caret, selection,
  )
}

///|
fn markdown_editor_delete_empty_trailing_table_row(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  markdown_editor_remove_empty_trailing_table_row_at_caret(
    source, caret, selection,
  )
}

///|
fn markdown_editor_remove_empty_trailing_table_row_at_caret(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
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
) -> RichTextInputTransform? {
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
