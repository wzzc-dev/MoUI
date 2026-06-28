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
) -> RichTextInputTransform {
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
fn markdown_editor_empty_table_row_column_caret(column : Int) -> Int {
  2 + column * 3
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
) -> RichTextInputTransform {
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
