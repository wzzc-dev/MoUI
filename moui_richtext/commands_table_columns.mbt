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
      text = text + line.text.to_owned()
      continue
    }
    let inserted_text = if table_line_index == 1 {
      markdown_editor_insert_table_column_in_line(
        line.text.to_owned(),
        current.column,
        "---",
      )
    } else {
      let next = markdown_editor_insert_table_column_in_line(
        line.text.to_owned(),
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
      text = text + line.text.to_owned()
      continue
    }
    if table_line_index == 1 {
      text = text +
        markdown_editor_rewrite_table_alignment_line(
          line.text.to_owned(),
          current.column,
          align,
        )
    } else {
      text = text + line.text.to_owned()
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
      text = text + line.text.to_owned()
      continue
    }
    let replacement = if table_line_index == 1 {
      markdown_editor_rewrite_table_column_in_line(
        line.text.to_owned(),
        column,
        "",
        delete~,
        clear=false,
      )
    } else {
      let next = markdown_editor_rewrite_table_column_in_line(
        line.text.to_owned(),
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
