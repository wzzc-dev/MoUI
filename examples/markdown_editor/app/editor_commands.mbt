///|
fn markdown_editor_apply_command_at(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection?,
) -> MarkdownEditorEditResult {
  let result = match command {
    Clear => { source: "", caret: 0, selection: None }
    Bold | Italic | Code | Strikethrough =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(range) =>
              markdown_editor_toggle_inline_range(
                source,
                range,
                markdown_editor_inline_marker(command),
              )
            None => markdown_editor_append_snippet(source, command)
          }
        None => markdown_editor_append_snippet(source, command)
      }
    Link | Image =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(range) =>
              if command == Image {
                markdown_editor_toggle_image_range(source, range)
              } else {
                markdown_editor_toggle_link_range(source, range)
              }
            None => markdown_editor_append_snippet(source, command)
          }
        None => markdown_editor_append_snippet(source, command)
      }
    SetLinkTarget(target) | SetImageTarget(target) =>
      match selection {
        Some(selection) =>
          match markdown_editor_active_selection(selection.selection) {
            Some(_) =>
              markdown_editor_set_reference_target(
                source, selection, command, target,
              )
            None => markdown_editor_append_snippet(source, command)
          }
        None => markdown_editor_append_snippet(source, command)
      }
    SetCodeLanguage(language) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_code_language(source, selection, language)
        None => markdown_editor_append_snippet(source, command)
      }
    SetFootnoteText(text) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_footnote_text(source, selection, text)
        None => markdown_editor_append_snippet(source, command)
      }
    SetHtmlBlockText(text) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_html_block_text(source, selection, text)
        None => markdown_editor_append_snippet(source, command)
      }
    InsertTableRow =>
      match selection {
        Some(selection) => markdown_editor_insert_table_row(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    InsertTableColumn =>
      match selection {
        Some(selection) =>
          markdown_editor_insert_table_column(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    DeleteTableRow =>
      match selection {
        Some(selection) => markdown_editor_delete_table_row(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    DeleteTableColumn =>
      match selection {
        Some(selection) =>
          markdown_editor_delete_table_column(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    SetTableColumnAlignment(align) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_table_column_alignment(source, selection, align)
        None => markdown_editor_append_snippet(source, command)
      }
    Paragraph
    | Heading(_)
    | BulletList
    | TaskList
    | OrderedList
    | Quote
    | HorizontalRule
    | Table =>
      match selection {
        Some(selection) =>
          markdown_editor_transform_current_block(source, command, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    CodeBlock =>
      match selection {
        Some(selection) => markdown_editor_toggle_code_block(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
  }
  markdown_editor_normalize_ordered_edit_result(result)
}

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
          return Some(markdown_editor_transform_result(text=source, caret~))
        }
      None => return None
    }
  }
  None
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
  if end > start && chars[end - 1] == '|' {
    end = end - 1
  }
  let mut segment_start = start
  let mut index = start
  let mut column = 0
  while index <= end {
    if index == end || chars[index] == '|' {
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
      Some(index) =>
        return Some(
          markdown_editor_insert_table_row_after_cell(
            source,
            cells,
            cells[index],
          ),
        )
      None => return None
    }
  }
  None
}

///|
fn markdown_editor_insert_table_row(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_append_snippet(source, InsertTableRow)
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
  markdown_editor_append_snippet(source, InsertTableRow)
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
  let row_end = markdown_editor_table_row_end(source, cells, current.row)
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
    return markdown_editor_append_snippet(source, InsertTableColumn)
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
  markdown_editor_append_snippet(source, InsertTableColumn)
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
    return markdown_editor_append_snippet(source, DeleteTableRow)
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
  markdown_editor_append_snippet(source, DeleteTableRow)
}

///|
fn markdown_editor_delete_table_column(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_append_snippet(source, DeleteTableColumn)
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
  markdown_editor_append_snippet(source, DeleteTableColumn)
}

///|
fn markdown_editor_set_table_column_alignment(
  source : String,
  selection : MarkdownEditorSelection,
  align : @core.TextAlign?,
) -> MarkdownEditorEditResult {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return markdown_editor_append_snippet(
      source,
      SetTableColumnAlignment(align),
    )
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
  markdown_editor_append_snippet(source, SetTableColumnAlignment(align))
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
fn markdown_editor_append_snippet(
  source : String,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  let snippet = markdown_editor_command_snippet(command)
  let text = if source == "" { snippet } else { source + "\n\n" + snippet }
  { source: text, caret: markdown_editor_text_length(text), selection: None }
}

///|
fn markdown_editor_wrap_range(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let selected = String::from_array(chars[start:end])
  let text = String::from_array(chars[:start]) +
    marker +
    selected +
    marker +
    String::from_array(chars[end:])
  let marker_len = markdown_editor_text_length(marker)
  let selected_len = markdown_editor_text_length(selected)
  let next_selection = @core.TextRange::new(
    start=start + marker_len,
    end=start + marker_len + selected_len,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_toggle_inline_range(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> MarkdownEditorEditResult {
  let normalized = range.normalized()
  if markdown_editor_range_has_inline_marker(source, normalized, marker) {
    markdown_editor_unwrap_range(source, normalized, marker)
  } else {
    markdown_editor_wrap_range(source, normalized, marker)
  }
}

///|
fn markdown_editor_range_has_inline_marker(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> Bool {
  let marker_length = markdown_editor_text_length(marker)
  let chars = source.to_array()
  range.start >= marker_length &&
  range.end + marker_length <= chars.length() &&
  markdown_editor_source_has_marker(chars, range.start - marker_length, marker) &&
  markdown_editor_source_has_marker(chars, range.end, marker)
}

///|
fn markdown_editor_unwrap_range(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> MarkdownEditorEditResult {
  let marker_length = markdown_editor_text_length(marker)
  let chars = source.to_array()
  let open_start = range.start - marker_length
  let text = String::from_array(chars[:open_start]) +
    String::from_array(chars[range.start:range.end]) +
    String::from_array(chars[range.end + marker_length:])
  let next_selection = @core.TextRange::new(
    start=open_start,
    end=open_start + range.end - range.start,
  )
  { source: text, caret: next_selection.end, selection: Some(next_selection) }
}

///|
fn markdown_editor_toggle_link_range(
  source : String,
  range : @core.TextRange,
) -> MarkdownEditorEditResult {
  let normalized = range.normalized()
  match markdown_editor_range_link_bounds(source, normalized) {
    Some(bounds) =>
      markdown_editor_unwrap_link_range(source, normalized, bounds)
    None => markdown_editor_wrap_link_range(source, normalized)
  }
}

///|
fn markdown_editor_toggle_image_range(
  source : String,
  range : @core.TextRange,
) -> MarkdownEditorEditResult {
  let normalized = range.normalized()
  match markdown_editor_range_image_bounds(source, normalized) {
    Some(bounds) =>
      markdown_editor_unwrap_image_range(source, normalized, bounds)
    None => markdown_editor_wrap_image_range(source, normalized)
  }
}

///|
fn markdown_editor_set_reference_target(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
  target : String,
) -> MarkdownEditorEditResult {
  let range = markdown_editor_active_selection(selection.selection)
    .unwrap_or(@core.TextRange::new(start=selection.caret, end=selection.caret))
    .normalized()
  if command == SetImageTarget(target) {
    match markdown_editor_range_image_bounds(source, range) {
      Some(bounds) =>
        return markdown_editor_replace_reference_target(
          source, range, bounds, target,
        )
      None =>
        return markdown_editor_wrap_image_range_with_target(
          source, range, target,
        )
    }
  }
  match markdown_editor_range_link_bounds(source, range) {
    Some(bounds) =>
      markdown_editor_replace_reference_target(source, range, bounds, target)
    None => markdown_editor_wrap_link_range_with_target(source, range, target)
  }
}

///|
fn markdown_editor_set_code_language(
  source : String,
  selection : MarkdownEditorSelection,
  language : String,
) -> MarkdownEditorEditResult {
  match markdown_editor_code_block_at_selection(source, selection) {
    Some(block) =>
      markdown_editor_replace_code_language(source, selection, block, language)
    None => markdown_editor_append_snippet(source, SetCodeLanguage(language))
  }
}

///|
fn markdown_editor_set_html_block_text(
  source : String,
  selection : MarkdownEditorSelection,
  text : String,
) -> MarkdownEditorEditResult {
  match markdown_editor_html_block_at_selection(source, selection) {
    Some(block) =>
      markdown_editor_replace_html_block_text(source, selection, block, text)
    None => markdown_editor_append_snippet(source, SetHtmlBlockText(text))
  }
}

///|
fn markdown_editor_replace_html_block_text(
  source : String,
  selection : MarkdownEditorSelection,
  block : MarkdownEditorBlock,
  text : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let next_source = String::from_array(chars[:block.source_range.start]) +
    text +
    String::from_array(chars[block.source_range.end:])
  let caret = block.source_range.start + markdown_editor_text_length(text)
  { source: next_source, caret, selection: selection.selection }
}

///|
fn markdown_editor_replace_code_language(
  source : String,
  selection : MarkdownEditorSelection,
  block : MarkdownEditorBlock,
  language : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let marker_end = markdown_editor_code_fence_marker_end(source, block)
  let language = language.trim().to_owned()
  let text = String::from_array(chars[:marker_end]) +
    language +
    String::from_array(chars[block.content_range.start - 1:])
  let delta = markdown_editor_text_length(language) -
    (block.content_range.start - 1 - marker_end)
  let caret = if selection.caret >= block.content_range.start {
    selection.caret + delta
  } else {
    selection.caret
  }
  { source: text, caret, selection: selection.selection }
}

///|
fn markdown_editor_code_fence_marker_end(
  source : String,
  block : MarkdownEditorBlock,
) -> Int {
  let chars = source.to_array()
  let mut index = block.source_range.start
  while index < chars.length() && chars[index] != '`' {
    index = index + 1
  }
  while index < chars.length() && chars[index] == '`' {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_transform_current_block(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if source == "" {
    return markdown_editor_append_snippet(source, command)
  }
  match markdown_editor_active_selection(selection.selection) {
    Some(_) =>
      match command {
        Paragraph | BulletList | TaskList | OrderedList | Quote =>
          return markdown_editor_transform_selected_lines(
            source, command, selection,
          )
        HorizontalRule =>
          return markdown_editor_replace_selected_lines_with_rule(
            source, selection,
          )
        Table =>
          return markdown_editor_replace_selected_lines_with_table(
            source, selection,
          )
        _ => ()
      }
    None => ()
  }
  match markdown_editor_setext_block_at_selection(source, selection) {
    Some(block) =>
      match command {
        Paragraph
        | Heading(_)
        | BulletList
        | TaskList
        | OrderedList
        | Quote
        | HorizontalRule
        | Table =>
          return markdown_editor_transform_setext_block(
            source, command, selection, block,
          )
        _ => ()
      }
    None => ()
  }
  let range = markdown_editor_current_line_range(source, selection)
  let chars = source.to_array()
  let line = String::from_array(chars[range.start:range.end])
  let stripped = markdown_editor_strip_block_marker(line)
  let prefix = markdown_editor_block_prefix(command)
  if command == Paragraph {
    let next_source = String::from_array(chars[:range.start]) +
      stripped +
      String::from_array(chars[range.end:])
    let next_caret = range.start +
      markdown_editor_caret_offset_in_stripped_line(
        line,
        selection.caret - range.start,
      )
    { source: next_source, caret: next_caret, selection: None }
  } else if command == HorizontalRule {
    let next_source = String::from_array(chars[:range.start]) +
      "---" +
      String::from_array(chars[range.end:])
    { source: next_source, caret: range.start + 3, selection: None }
  } else if command == Table {
    let snippet = markdown_editor_command_snippet(Table)
    let next_source = String::from_array(chars[:range.start]) +
      snippet +
      String::from_array(chars[range.end:])
    { source: next_source, caret: range.start + 2, selection: None }
  } else if prefix == "" {
    markdown_editor_append_snippet(source, command)
  } else {
    let replacement = if markdown_editor_line_has_same_block_marker(
        line, command,
      ) {
      stripped
    } else {
      prefix + stripped
    }
    let next_source = String::from_array(chars[:range.start]) +
      replacement +
      String::from_array(chars[range.end:])
    let replacement_prefix_length = markdown_editor_text_length(replacement) -
      markdown_editor_text_length(stripped)
    let next_caret = range.start +
      replacement_prefix_length +
      markdown_editor_caret_offset_in_stripped_line(
        line,
        selection.caret - range.start,
      )
    { source: next_source, caret: next_caret, selection: None }
  }
}

///|
fn markdown_editor_setext_block_at_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlock? {
  let anchor = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if !(block.block.kind is MarkdownBlockKind::Heading(_)) ||
      anchor < block.source_range.start ||
      anchor > block.content_range.end ||
      block.source_range.end <= block.content_range.end {
      continue
    }
    return Some(block)
  }
  None
}

///|
fn markdown_editor_transform_setext_block(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection,
  block : MarkdownEditorBlock,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let text = block.block.text
  let replacement = match command {
    Paragraph => text
    Heading(level) => markdown_editor_heading_marker(level) + " " + text
    BulletList => "- " + text
    TaskList => "- [ ] " + text
    OrderedList => "1. " + text
    Quote => "> " + text
    HorizontalRule => "---"
    Table => markdown_editor_command_snippet(Table)
    _ => text
  }
  let next_source = String::from_array(chars[:block.source_range.start]) +
    replacement +
    String::from_array(chars[block.source_range.end:])
  let caret = if command == Table {
    block.source_range.start + 2
  } else if command == HorizontalRule {
    block.source_range.start + 3
  } else {
    let offset = markdown_editor_clamp_int(
      selection.caret - block.content_range.start,
      0,
      markdown_editor_text_length(text),
    )
    block.source_range.start +
    markdown_editor_text_length(replacement) -
    markdown_editor_text_length(text) +
    offset
  }
  { source: next_source, caret, selection: None }
}

///|
fn markdown_editor_replace_selected_lines_with_table(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let snippet = markdown_editor_command_snippet(Table)
  let text = String::from_array(chars[:range.start]) +
    snippet +
    String::from_array(chars[range.end:])
  let next_selection = @core.TextRange::new(
    start=range.start,
    end=range.start + markdown_editor_text_length(snippet),
  )
  { source: text, caret: range.start + 2, selection: Some(next_selection) }
}

///|
fn markdown_editor_replace_selected_lines_with_rule(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let text = String::from_array(chars[:range.start]) +
    "---" +
    String::from_array(chars[range.end:])
  let next_selection = @core.TextRange::new(
    start=range.start,
    end=range.start + 3,
  )
  { source: text, caret: range.start + 3, selection: Some(next_selection) }
}

///|
fn markdown_editor_line_has_same_block_marker(
  line : String,
  command : MarkdownEditorCommand,
) -> Bool {
  let marker_length = markdown_editor_marker_prefix_length(line)
  let indent_length = markdown_editor_line_indent_prefix_length(line)
  match command {
    Heading(level) => markdown_editor_heading_marker_level(line) == level
    BulletList =>
      marker_length == indent_length + 2 &&
      markdown_editor_string_ends_with(
        markdown_editor_continuation_marker(line),
        "- ",
      )
    TaskList => marker_length == indent_length + 6
    OrderedList => markdown_editor_ordered_marker_length(line.to_array()) > 0
    Quote =>
      marker_length == indent_length + 2 &&
      markdown_editor_string_ends_with(
        markdown_editor_continuation_marker(line),
        "> ",
      )
    _ => false
  }
}

///|
fn markdown_editor_heading_marker_level(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  let mut index = indent
  while index < chars.length() && chars[index] == '#' {
    index = index + 1
  }
  if index > 0 && index < chars.length() && chars[index] == ' ' {
    index - indent
  } else {
    0
  }
}

///|
fn markdown_editor_caret_offset_in_stripped_line(
  line : String,
  caret_offset : Int,
) -> Int {
  let marker_length = markdown_editor_marker_prefix_length(line)
  let stripped_length = markdown_editor_text_length(line) - marker_length
  markdown_editor_clamp_int(caret_offset - marker_length, 0, stripped_length)
}

///|
fn markdown_editor_transform_selected_lines(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let segment = String::from_array(chars[range.start:range.end])
  let transformed = markdown_editor_transform_line_segment(segment, command)
  let text = String::from_array(chars[:range.start]) +
    transformed +
    String::from_array(chars[range.end:])
  let delta = markdown_editor_text_length(transformed) -
    (range.end - range.start)
  let next_selection = Some(
    @core.TextRange::new(
      start=range.start,
      end=range.start + markdown_editor_text_length(transformed),
    ),
  )
  let caret = if selection.caret <= range.start {
    selection.caret
  } else if selection.caret <= range.end {
    range.start + markdown_editor_text_length(transformed)
  } else {
    selection.caret + delta
  }
  { source: text, caret, selection: next_selection }
}

///|
fn markdown_editor_transform_line_segment(
  segment : String,
  command : MarkdownEditorCommand,
) -> String {
  let lines = markdown_editor_lines(segment)
  let transformed : Array[String] = []
  let mut ordered_number = 1
  for line in lines {
    let stripped = markdown_editor_strip_block_marker(line.text)
    match command {
      Paragraph => transformed.push(stripped)
      BulletList => transformed.push("- " + stripped)
      TaskList => transformed.push("- [ ] " + stripped)
      OrderedList => {
        transformed.push(ordered_number.to_string() + ". " + stripped)
        ordered_number = ordered_number + 1
      }
      Quote => transformed.push("> " + stripped)
      _ => transformed.push(line.text)
    }
  }
  markdown_join_lines(transformed)
}

///|
fn markdown_editor_toggle_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if source == "" {
    return markdown_editor_append_snippet(source, CodeBlock)
  }
  match markdown_editor_containing_code_block(source, selection) {
    Some(block) => markdown_editor_unwrap_code_block(source, block, selection)
    None => markdown_editor_wrap_lines_in_code_block(source, selection)
  }
}

///|
fn markdown_editor_containing_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlock? {
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    if block.block.kind is MarkdownBlockKind::CodeBlock &&
      anchor >= block.source_range.start &&
      anchor <= block.source_range.end {
      return Some(block)
    }
  }
  None
}

///|
fn markdown_editor_unwrap_code_block(
  source : String,
  block : MarkdownEditorBlock,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let open_end = markdown_editor_min_int(
    block.content_range.start,
    chars.length(),
  )
  let close_start = markdown_editor_max_int(
    block.content_range.end - 1,
    open_end,
  )
  let text = String::from_array(chars[:block.source_range.start]) +
    String::from_array(chars[open_end:close_start]) +
    String::from_array(chars[block.source_range.end:])
  let removed_before_content = open_end - block.source_range.start
  let removed_total = removed_before_content +
    block.source_range.end -
    close_start
  let caret = if selection.caret <= block.source_range.start {
    selection.caret
  } else if selection.caret <= block.source_range.end {
    markdown_editor_clamp_int(
      selection.caret - removed_before_content,
      block.source_range.start,
      block.source_range.end - removed_total,
    )
  } else {
    selection.caret - removed_total
  }
  let next_selection = match
    markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      Some(
        @core.TextRange::new(
          start=markdown_editor_unwrapped_code_offset(
            range.start,
            block,
            removed_before_content,
            removed_total,
          ),
          end=markdown_editor_unwrapped_code_offset(
            range.end,
            block,
            removed_before_content,
            removed_total,
          ),
        ),
      )
    None => None
  }
  { source: text, caret, selection: next_selection }
}

///|
fn markdown_editor_unwrapped_code_offset(
  offset : Int,
  block : MarkdownEditorBlock,
  removed_before_content : Int,
  removed_total : Int,
) -> Int {
  if offset <= block.source_range.start {
    offset
  } else if offset <= block.source_range.end {
    markdown_editor_clamp_int(
      offset - removed_before_content,
      block.source_range.start,
      block.source_range.end - removed_total,
    )
  } else {
    offset - removed_total
  }
}

///|
fn markdown_editor_wrap_lines_in_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let range = markdown_editor_selected_line_range(source, selection)
  let selected = String::from_array(chars[range.start:range.end])
  let prefix = "```\n"
  let suffix = "\n```"
  let text = String::from_array(chars[:range.start]) +
    prefix +
    selected +
    suffix +
    String::from_array(chars[range.end:])
  let prefix_length = markdown_editor_text_length(prefix)
  let caret = if selection.caret < range.start {
    selection.caret
  } else if selection.caret <= range.end {
    selection.caret + prefix_length
  } else {
    selection.caret + prefix_length + markdown_editor_text_length(suffix)
  }
  let next_selection = match
    markdown_editor_active_selection(selection.selection) {
    Some(active) =>
      Some(
        @core.TextRange::new(
          start=active.start + prefix_length,
          end=active.end + prefix_length,
        ),
      )
    None => None
  }
  { source: text, caret, selection: next_selection }
}

///|
fn markdown_editor_block_prefix(command : MarkdownEditorCommand) -> String {
  match command {
    Paragraph => ""
    Heading(level) => markdown_editor_heading_marker(level) + " "
    BulletList => "- "
    TaskList => "- [ ] "
    OrderedList => "1. "
    Quote => "> "
    _ => ""
  }
}

///|
fn markdown_editor_strip_block_marker(line : String) -> String {
  let offset = markdown_editor_marker_prefix_length(line)
  let chars = line.to_array()
  String::from_array(chars[offset:])
}

///|
fn markdown_editor_marker_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 && chars[indent] == '#' {
    let mut index = indent
    while index < chars.length() && chars[index] == '#' {
      index = index + 1
    }
    if index < chars.length() && chars[index] == ' ' {
      index + 1
    } else {
      0
    }
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
    indent + 6
  } else if chars.length() >= indent + 2 &&
    (chars[indent] == '-' || chars[indent] == '*' || chars[indent] == '+') &&
    chars[indent + 1] == ' ' {
    indent + 2
  } else if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    indent + 2
  } else {
    markdown_editor_ordered_marker_length(chars)
  }
}

///|
fn markdown_editor_ordered_marker_length(chars : Array[Char]) -> Int {
  let indent = markdown_editor_leading_indent_length(chars)
  let mut index = indent
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  if index > indent &&
    index + 1 < chars.length() &&
    chars[index] == '.' &&
    chars[index + 1] == ' ' {
    index + 2
  } else {
    0
  }
}

///|
fn markdown_editor_line_indent_prefix_length(line : String) -> Int {
  markdown_editor_leading_indent_length(line.to_array())
}

///|
fn markdown_editor_leading_indent_length(chars : Array[Char]) -> Int {
  let mut index = 0
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_string_ends_with(source : String, suffix : String) -> Bool {
  let source_chars = source.to_array()
  let suffix_chars = suffix.to_array()
  if suffix_chars.length() > source_chars.length() {
    return false
  }
  let start = source_chars.length() - suffix_chars.length()
  for index in 0..<suffix_chars.length() {
    if source_chars[start + index] != suffix_chars[index] {
      return false
    }
  }
  true
}

///|
fn markdown_editor_inline_marker(command : MarkdownEditorCommand) -> String {
  match command {
    Bold => "**"
    Italic => "*"
    Code => "`"
    Strikethrough => "~~"
    _ => ""
  }
}

///|
fn markdown_editor_command_snippet(command : MarkdownEditorCommand) -> String {
  match command {
    Bold => "**bold text**"
    Italic => "*italic text*"
    Code => "`code`"
    Strikethrough => "~~old text~~"
    Link => "[link text](https://example.com)"
    Image => "![image alt](image.png)"
    SetLinkTarget(target) => "[link text](" + target + ")"
    SetImageTarget(target) => "![image alt](" + target + ")"
    SetCodeLanguage(target) => "```" + target + "\ncode block\n```"
    SetFootnoteText(text) => "[^note]: " + text
    SetHtmlBlockText(text) => text
    Paragraph => "Paragraph"
    Heading(level) =>
      markdown_editor_heading_marker(level) +
      " " +
      markdown_editor_heading_snippet_text(level)
    BulletList => "- List item"
    TaskList => "- [ ] Task item"
    OrderedList => "1. List item"
    Quote => "> Quote"
    CodeBlock => "```\ncode block\n```"
    HorizontalRule => "---"
    Table => "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    InsertTableRow =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    InsertTableColumn =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    DeleteTableRow =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    DeleteTableColumn =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    SetTableColumnAlignment(_) =>
      "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
    Clear => ""
  }
}

///|
fn markdown_editor_heading_marker(level : Int) -> String {
  let count = markdown_editor_clamp_int(level, 1, 6)
  let chars : Array[Char] = []
  for _ in 0..<count {
    chars.push('#')
  }
  String::from_array(chars)
}

///|
fn markdown_editor_heading_snippet_text(level : Int) -> String {
  if level <= 1 {
    "Heading"
  } else if level == 2 {
    "Section"
  } else if level == 3 {
    "Detail"
  } else if level == 4 {
    "Subdetail"
  } else if level == 5 {
    "Note"
  } else {
    "Caption"
  }
}

///|
fn markdown_editor_preview_text(source : String) -> String {
  if source == "" {
    "(empty)"
  } else if markdown_editor_text_length(source) > 700 {
    markdown_editor_substring(source, 0, 700) + "\n..."
  } else {
    source
  }
}

///|
fn markdown_editor_toggle_task_at(
  source : String,
  content_offset : Int,
) -> MarkdownEditorEditResult? {
  let chars = source.to_array()
  for block in parse_markdown_editor_blocks(source) {
    match block.block.kind {
      TaskListItem(checked) =>
        if content_offset == block.content_range.start {
          let marker_index = block.content_range.start - 3
          if marker_index < chars.length() {
            let next = if checked { ' ' } else { 'x' }
            let text = String::from_array(chars[:marker_index]) +
              String::from_array([next]) +
              String::from_array(chars[marker_index + 1:])
            return Some({
              source: text,
              caret: block.content_range.start,
              selection: None,
            })
          }
        }
      _ => ()
    }
  }
  None
}

///|
