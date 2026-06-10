///|
fn markdown_editor_apply_command_at(
  source : String,
  command : MarkdownEditorCommand,
  selection : MarkdownEditorSelection?,
) -> MarkdownEditorEditResult {
  let result = match command {
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
            None =>
              markdown_editor_toggle_inline_at_caret(
                source,
                selection.caret,
                command,
              )
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
            None =>
              markdown_editor_toggle_reference_at_caret(
                source, selection, command,
              )
          }
        None => markdown_editor_append_snippet(source, command)
      }
    SetLinkTarget(target) | SetImageTarget(target) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_reference_target(
            source, selection, command, target,
          )
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
        None => markdown_editor_noop_result(source, selection)
      }
    InsertTableColumn =>
      match selection {
        Some(selection) =>
          markdown_editor_insert_table_column(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    DeleteTableRow =>
      match selection {
        Some(selection) => markdown_editor_delete_table_row(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    DeleteTableColumn =>
      match selection {
        Some(selection) =>
          markdown_editor_delete_table_column(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    SetTableColumnAlignment(align) =>
      match selection {
        Some(selection) =>
          markdown_editor_set_table_column_alignment(source, selection, align)
        None => markdown_editor_noop_result(source, selection)
      }
    InsertTableOfContents =>
      match selection {
        Some(selection) =>
          markdown_editor_insert_table_of_contents(source, selection)
        None => markdown_editor_append_snippet(source, command)
      }
    InsertFrontMatter =>
      match selection {
        Some(_) => markdown_editor_insert_front_matter(source)
        None => markdown_editor_append_snippet(source, command)
      }
    DuplicateBlock =>
      match selection {
        Some(selection) =>
          markdown_editor_duplicate_current_block(source, selection)
        None => markdown_editor_noop_result(source, selection)
      }
    MoveBlockUp =>
      match selection {
        Some(selection) =>
          markdown_editor_move_current_block(source, selection, up=true)
        None => markdown_editor_noop_result(source, selection)
      }
    MoveBlockDown =>
      match selection {
        Some(selection) =>
          markdown_editor_move_current_block(source, selection, up=false)
        None => markdown_editor_noop_result(source, selection)
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
fn markdown_editor_append_snippet(
  source : String,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  let snippet = markdown_editor_command_snippet(command)
  let text = if source == "" { snippet } else { source + "\n\n" + snippet }
  { source: text, caret: markdown_editor_text_length(text), selection: None }
}

///|
fn markdown_editor_insert_table_of_contents(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let toc = markdown_editor_table_of_contents_markdown(source)
  let range = markdown_editor_active_selection(selection.selection)
    .unwrap_or(@core.TextRange::new(start=selection.caret, end=selection.caret))
    .normalized()
  markdown_editor_replace_with_block(source, range, toc)
}

///|
fn markdown_editor_insert_front_matter(
  source : String,
) -> MarkdownEditorEditResult {
  let blocks = parse_markdown_editor_blocks(source)
  if blocks.length() > 0 && blocks[0].block.kind is FrontMatter {
    return {
      source,
      caret: blocks[0].content_range.end,
      selection: Some(
        @core.TextRange::new(
          start=blocks[0].content_range.start,
          end=blocks[0].content_range.end,
        ),
      ),
    }
  }
  let snippet = markdown_editor_command_snippet(InsertFrontMatter)
  let text = if source == "" { snippet } else { snippet + "\n\n" + source }
  { source: text, caret: markdown_editor_text_length(snippet), selection: None }
}

///|
fn markdown_editor_table_of_contents_markdown(source : String) -> String {
  let outline = MarkdownEditorSnapshot::parse(source).outline
  if outline.length() == 0 {
    return markdown_editor_command_snippet(InsertTableOfContents)
  }
  let rows : Array[String] = ["## Contents"]
  for item in outline {
    let title = if item.title.trim().to_owned() == "" {
      "Untitled"
    } else {
      item.title.trim().to_owned()
    }
    let indent = markdown_editor_toc_indent(item.level)
    rows.push(
      indent +
      "- [" +
      markdown_editor_toc_escape_link_text(title) +
      "](#" +
      markdown_editor_toc_slug(title) +
      ")",
    )
  }
  markdown_join_lines(rows)
}

///|
fn markdown_editor_replace_with_block(
  source : String,
  range : @core.TextRange,
  block : String,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let start = markdown_editor_clamp_int(range.start, 0, chars.length())
  let end = markdown_editor_clamp_int(range.end, start, chars.length())
  let before = String::from_array(chars[:start])
  let after = String::from_array(chars[end:])
  let prefix = markdown_editor_block_insert_prefix(chars, start)
  let suffix = markdown_editor_block_insert_suffix(chars, end)
  let text = before + prefix + block + suffix + after
  let caret = markdown_editor_text_length(before + prefix + block)
  { source: text, caret, selection: None }
}

///|
fn markdown_editor_toc_indent(level : Int) -> String {
  let spaces : Array[Char] = []
  let count = markdown_editor_max_int(0, level - 1) * 2
  for _ in 0..<count {
    spaces.push(' ')
  }
  String::from_array(spaces)
}

///|
fn markdown_editor_toc_escape_link_text(text : String) -> String {
  let chars : Array[Char] = []
  for ch in text {
    if ch == '[' || ch == ']' || ch == '\\' {
      chars.push('\\')
    }
    chars.push(ch)
  }
  String::from_array(chars)
}

///|
fn markdown_editor_toc_slug(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_dash = false
  for ch in text.to_lower() {
    if markdown_editor_toc_slug_char(ch) {
      chars.push(ch)
      previous_dash = false
    } else if ch.is_ascii_whitespace() || ch == '-' {
      if !previous_dash && chars.length() > 0 {
        chars.push('-')
        previous_dash = true
      }
    }
  }
  while chars.length() > 0 && chars[chars.length() - 1] == '-' {
    ignore(chars.pop())
  }
  if chars.length() == 0 {
    "section"
  } else {
    String::from_array(chars)
  }
}

///|
fn markdown_editor_toc_slug_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_'
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
fn markdown_editor_toggle_inline_at_caret(
  source : String,
  caret : Int,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  let marker = markdown_editor_inline_marker(command)
  match markdown_editor_inline_marker_pair_at_caret(source, caret, marker) {
    Some(range) => markdown_editor_unwrap_range(source, range, marker)
    None => markdown_editor_append_snippet(source, command)
  }
}

///|
fn markdown_editor_inline_marker_pair_at_caret(
  source : String,
  caret : Int,
  marker : String,
) -> @core.TextRange? {
  let marker_length = markdown_editor_text_length(marker)
  if marker_length == 0 {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_find_inline_opening_marker(chars, caret, marker) {
    Some(open_start) =>
      match
        markdown_editor_find_inline_closing_marker(
          chars,
          open_start + marker_length,
          marker,
        ) {
        Some(close_start) =>
          if caret >= open_start + marker_length &&
            caret <= close_start &&
            markdown_editor_inline_marker_pair_supported(
              chars, open_start, marker_length, close_start, marker,
            ) {
            Some(
              @core.TextRange::new(
                start=open_start + marker_length,
                end=close_start,
              ),
            )
          } else {
            None
          }
        None => None
      }
    None => None
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
fn markdown_editor_toggle_reference_at_caret(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> MarkdownEditorEditResult {
  if command == Image {
    match markdown_editor_image_context(source, selection) {
      Some(context) =>
        markdown_editor_unwrap_image_range(
          source,
          context.range,
          context.bounds,
        )
      None => markdown_editor_append_snippet(source, command)
    }
  } else {
    match markdown_editor_link_context(source, selection) {
      Some(context) =>
        markdown_editor_unwrap_link_range(source, context.range, context.bounds)
      None => markdown_editor_append_snippet(source, command)
    }
  }
}

///|
fn markdown_editor_set_reference_target(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
  target : String,
) -> MarkdownEditorEditResult {
  let active = markdown_editor_active_selection(selection.selection)
  let range = active
    .unwrap_or(@core.TextRange::new(start=selection.caret, end=selection.caret))
    .normalized()
  if command == SetImageTarget(target) {
    match markdown_editor_image_context(source, selection) {
      Some(context) =>
        return markdown_editor_replace_reference_target(
          source,
          context.range,
          context.bounds,
          target,
        )
      None =>
        match active {
          Some(_) =>
            return markdown_editor_wrap_image_range_with_target(
              source, range, target,
            )
          None => return markdown_editor_append_snippet(source, command)
        }
    }
  }
  match markdown_editor_link_context(source, selection) {
    Some(context) =>
      markdown_editor_replace_reference_target(
        source,
        context.range,
        context.bounds,
        target,
      )
    None =>
      match active {
        Some(_) =>
          markdown_editor_wrap_link_range_with_target(source, range, target)
        None => markdown_editor_append_snippet(source, command)
      }
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
  let parts = markdown_editor_line_block_parts(line)
  if command == Paragraph {
    let replacement = markdown_editor_paragraph_line_text(line, parts)
    let next_source = String::from_array(chars[:range.start]) +
      replacement +
      String::from_array(chars[range.end:])
    let paragraph_offset = if markdown_editor_line_block_parts_has_inner_marker(
        parts,
      ) &&
      markdown_editor_block_command_context_has_quote(parts.context_prefix) {
      markdown_editor_text_length(parts.context_prefix) +
      markdown_editor_caret_offset_in_line_block_parts(
        parts,
        selection.caret - range.start,
      )
    } else {
      markdown_editor_caret_offset_in_stripped_line(
        line,
        selection.caret - range.start,
      )
    }
    let next_caret = range.start + paragraph_offset
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
  } else if markdown_editor_block_command_context_has_quote(
      parts.context_prefix,
    ) &&
    (
      command == BulletList ||
      command == TaskList ||
      command == OrderedList ||
      command is Heading(_)
    ) {
    let has_same_marker = markdown_editor_line_has_same_block_marker_after_context(
      line,
      command,
      parts.context_prefix,
    )
    let marker = if has_same_marker { "" } else { prefix }
    let replacement = parts.context_prefix + marker + parts.content
    let next_source = String::from_array(chars[:range.start]) +
      replacement +
      String::from_array(chars[range.end:])
    let next_caret = range.start +
      markdown_editor_text_length(parts.context_prefix) +
      markdown_editor_text_length(marker) +
      markdown_editor_caret_offset_in_line_block_parts(
        parts,
        selection.caret - range.start,
      )
    { source: next_source, caret: next_caret, selection: None }
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
  let ordered_contexts : Array[MarkdownEditorOrderedRenumberContext] = []
  for line in lines {
    let parts = markdown_editor_line_block_parts(line.text)
    let content_is_blank = parts.content.trim().to_owned() == ""
    match command {
      Paragraph =>
        transformed.push(markdown_editor_paragraph_line_text(line.text, parts))
      BulletList =>
        if content_is_blank {
          transformed.push(markdown_editor_block_command_blank_line(parts))
        } else {
          transformed.push(parts.context_prefix + "- " + parts.content)
        }
      TaskList =>
        if content_is_blank {
          transformed.push(markdown_editor_block_command_blank_line(parts))
        } else {
          transformed.push(parts.context_prefix + "- [ ] " + parts.content)
        }
      OrderedList =>
        if content_is_blank {
          transformed.push(markdown_editor_block_command_blank_line(parts))
        } else {
          let number = markdown_editor_next_selected_ordered_number(
            ordered_contexts,
            parts.context_prefix,
          )
          transformed.push(
            parts.context_prefix + number.to_string() + ". " + parts.content,
          )
        }
      Quote =>
        if markdown_editor_block_command_context_has_quote(parts.context_prefix) {
          transformed.push(line.text)
        } else {
          transformed.push(parts.context_prefix + "> " + parts.content)
        }
      _ => transformed.push(line.text)
    }
  }
  markdown_join_lines(transformed)
}

///|
priv struct MarkdownEditorLineBlockParts {
  context_prefix : String
  content_start : Int
  content : String
}

///|
fn markdown_editor_line_block_parts(
  line : String,
) -> MarkdownEditorLineBlockParts {
  let chars = line.to_array()
  let context_length = markdown_editor_block_command_context_prefix_length(line)
  let marker_length = markdown_editor_marker_prefix_length_after_context(
    line, context_length,
  )
  let content_start = if marker_length > 0 {
    marker_length
  } else {
    context_length
  }
  {
    context_prefix: String::from_array(chars[:context_length]),
    content_start,
    content: String::from_array(chars[content_start:]),
  }
}

///|
fn markdown_editor_caret_offset_in_line_block_parts(
  parts : MarkdownEditorLineBlockParts,
  caret_offset : Int,
) -> Int {
  markdown_editor_clamp_int(
    caret_offset - parts.content_start,
    0,
    markdown_editor_text_length(parts.content),
  )
}

///|
fn markdown_editor_paragraph_line_text(
  line : String,
  parts : MarkdownEditorLineBlockParts,
) -> String {
  if markdown_editor_line_block_parts_has_inner_marker(parts) &&
    markdown_editor_block_command_context_has_quote(parts.context_prefix) {
    parts.context_prefix + parts.content
  } else {
    markdown_editor_strip_block_marker(line)
  }
}

///|
fn markdown_editor_line_block_parts_has_inner_marker(
  parts : MarkdownEditorLineBlockParts,
) -> Bool {
  parts.content_start > markdown_editor_text_length(parts.context_prefix)
}

///|
fn markdown_editor_block_command_blank_line(
  parts : MarkdownEditorLineBlockParts,
) -> String {
  if markdown_editor_block_command_context_has_quote(parts.context_prefix) {
    parts.context_prefix
  } else {
    ""
  }
}

///|
fn markdown_editor_block_command_context_has_quote(prefix : String) -> Bool {
  let chars = prefix.to_array()
  for index in 0..<chars.length() {
    if chars[index] == '>' {
      return true
    }
  }
  false
}

///|
fn markdown_editor_line_has_same_block_marker_after_context(
  line : String,
  command : MarkdownEditorCommand,
  context_prefix : String,
) -> Bool {
  let chars = line.to_array()
  let context_length = markdown_editor_text_length(context_prefix)
  markdown_editor_line_has_same_block_marker(
    String::from_array(chars[context_length:]),
    command,
  )
}

///|
fn markdown_editor_block_command_context_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let mut index = 0
  let mut scanning = true
  while scanning {
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index + 1 < chars.length() &&
      chars[index] == '>' &&
      chars[index + 1] == ' ' {
      index = index + 2
    } else {
      scanning = false
    }
  }
  index
}

///|
fn markdown_editor_marker_prefix_length_after_context(
  line : String,
  context_length : Int,
) -> Int {
  let chars = line.to_array()
  let nested_marker_length = markdown_editor_marker_prefix_length(
    String::from_array(chars[context_length:]),
  )
  if nested_marker_length > 0 {
    context_length + nested_marker_length
  } else {
    0
  }
}

///|
fn markdown_editor_next_selected_ordered_number(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  context_prefix : String,
) -> Int {
  let indent = markdown_editor_text_length(context_prefix)
  markdown_editor_trim_ordered_renumber_contexts(contexts, indent)
  if contexts.length() > 0 &&
    contexts[contexts.length() - 1].indent == indent &&
    contexts[contexts.length() - 1].context_prefix == context_prefix {
    let context = contexts[contexts.length() - 1]
    ignore(contexts.pop())
    contexts.push({ indent, context_prefix, expected: context.expected + 1 })
    context.expected
  } else {
    while contexts.length() > 0 &&
          contexts[contexts.length() - 1].indent >= indent {
      ignore(contexts.pop())
    }
    contexts.push({ indent, context_prefix, expected: 2 })
    1
  }
}

///|
priv struct MarkdownEditorBlockPosition {
  block : MarkdownEditorBlock
  index : Int
}

///|
priv struct MarkdownEditorBlockGroup {
  start_index : Int
  end_index : Int
  source_start : Int
  source_end : Int
}

///|
fn markdown_editor_noop_result(
  source : String,
  selection : MarkdownEditorSelection?,
) -> MarkdownEditorEditResult {
  match selection {
    Some(selection) =>
      { source, caret: selection.caret, selection: selection.selection }
    None =>
      { source, caret: markdown_editor_text_length(source), selection: None }
  }
}

///|
fn markdown_editor_duplicate_current_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  match markdown_editor_active_edit_group(source, selection) {
    Some(group) => {
      let chars = source.to_array()
      let block_text = String::from_array(
        chars[group.source_start:group.source_end],
      )
      if block_text == "" {
        return markdown_editor_noop_result(source, Some(selection))
      }
      let duplicate_start = group.source_end + 1
      let next_source = String::from_array(chars[:group.source_end]) +
        "\n" +
        block_text +
        String::from_array(chars[group.source_end:])
      {
        source: next_source,
        caret: markdown_editor_map_offset_to_group(
          selection.caret,
          group,
          duplicate_start,
        ),
        selection: markdown_editor_map_selection_to_group(
          selection.selection,
          group,
          duplicate_start,
        ),
      }
    }
    None => markdown_editor_noop_result(source, Some(selection))
  }
}

///|
fn markdown_editor_move_current_block(
  source : String,
  selection : MarkdownEditorSelection,
  up~ : Bool,
) -> MarkdownEditorEditResult {
  match markdown_editor_active_edit_group(source, selection) {
    Some(group) => {
      let blocks = parse_markdown_editor_blocks(source)
      let chars = source.to_array()
      if up {
        match markdown_editor_previous_edit_block(blocks, group.start_index) {
          Some(previous) => {
            let previous_text = String::from_array(
              chars[previous.source_range.start:previous.source_range.end],
            )
            let group_text = String::from_array(
              chars[group.source_start:group.source_end],
            )
            let gap = String::from_array(
              chars[previous.source_range.end:group.source_start],
            )
            let next_source = String::from_array(
                chars[:previous.source_range.start],
              ) +
              group_text +
              gap +
              previous_text +
              String::from_array(chars[group.source_end:])
            markdown_editor_moved_group_result(
              next_source,
              selection,
              group,
              new_start=previous.source_range.start,
            )
          }
          None => markdown_editor_noop_result(source, Some(selection))
        }
      } else {
        match markdown_editor_next_edit_block(blocks, group.end_index) {
          Some(next) => {
            let group_text = String::from_array(
              chars[group.source_start:group.source_end],
            )
            let next_text = String::from_array(
              chars[next.source_range.start:next.source_range.end],
            )
            let gap = String::from_array(
              chars[group.source_end:next.source_range.start],
            )
            let new_start = group.source_start +
              markdown_editor_text_length(next_text) +
              markdown_editor_text_length(gap)
            let next_source = String::from_array(chars[:group.source_start]) +
              next_text +
              gap +
              group_text +
              String::from_array(chars[next.source_range.end:])
            markdown_editor_moved_group_result(
              next_source,
              selection,
              group,
              new_start~,
            )
          }
          None => markdown_editor_noop_result(source, Some(selection))
        }
      }
    }
    None => markdown_editor_noop_result(source, Some(selection))
  }
}

///|
fn markdown_editor_moved_group_result(
  source : String,
  selection : MarkdownEditorSelection,
  group : MarkdownEditorBlockGroup,
  new_start~ : Int,
) -> MarkdownEditorEditResult {
  {
    source,
    caret: markdown_editor_map_offset_to_group(
      selection.caret,
      group,
      new_start,
    ),
    selection: markdown_editor_map_selection_to_group(
      selection.selection,
      group,
      new_start,
    ),
  }
}

///|
fn markdown_editor_active_edit_group(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlockGroup? {
  let blocks = parse_markdown_editor_blocks(source)
  match markdown_editor_active_selection(selection.selection) {
    Some(range) => {
      let normalized = range.normalized()
      let mut start_index = -1
      let mut end_index = -1
      for index in 0..<blocks.length() {
        let block = blocks[index]
        if markdown_editor_empty_line_block_for_edit(block) {
          continue
        }
        if normalized.start < block.source_range.end &&
          normalized.end > block.source_range.start {
          if start_index < 0 {
            start_index = index
          }
          end_index = index
        }
      }
      if start_index >= 0 && end_index >= start_index {
        return Some({
          start_index,
          end_index,
          source_start: blocks[start_index].source_range.start,
          source_end: blocks[end_index].source_range.end,
        })
      }
    }
    None => ()
  }
  match
    markdown_editor_active_edit_block_from_blocks(blocks, source, selection) {
    Some(current) =>
      Some({
        start_index: current.index,
        end_index: current.index,
        source_start: current.block.source_range.start,
        source_end: current.block.source_range.end,
      })
    None => None
  }
}

///|
fn markdown_editor_active_edit_block_from_blocks(
  blocks : Array[MarkdownEditorBlock],
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorBlockPosition? {
  let chars = source.to_array()
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(anchor, 0, chars.length())
  for index in 0..<blocks.length() {
    let block = blocks[index]
    if markdown_editor_empty_line_block_for_edit(block) {
      continue
    }
    if anchor >= block.source_range.start && anchor <= block.source_range.end {
      return Some({ block, index })
    }
  }
  None
}

///|
fn markdown_editor_previous_edit_block(
  blocks : Array[MarkdownEditorBlock],
  index : Int,
) -> MarkdownEditorBlock? {
  let mut candidate = index - 1
  while candidate >= 0 {
    let block = blocks[candidate]
    if !markdown_editor_empty_line_block_for_edit(block) {
      return Some(block)
    }
    candidate = candidate - 1
  }
  None
}

///|
fn markdown_editor_next_edit_block(
  blocks : Array[MarkdownEditorBlock],
  index : Int,
) -> MarkdownEditorBlock? {
  let mut candidate = index + 1
  while candidate < blocks.length() {
    let block = blocks[candidate]
    if !markdown_editor_empty_line_block_for_edit(block) {
      return Some(block)
    }
    candidate = candidate + 1
  }
  None
}

///|
fn markdown_editor_empty_line_block_for_edit(
  block : MarkdownEditorBlock,
) -> Bool {
  block.source_range.start == block.source_range.end && block.block.text == ""
}

///|
fn markdown_editor_map_offset_to_group(
  offset : Int,
  group : MarkdownEditorBlockGroup,
  group_start : Int,
) -> Int {
  group_start +
  markdown_editor_clamp_int(
    offset - group.source_start,
    0,
    group.source_end - group.source_start,
  )
}

///|
fn markdown_editor_map_selection_to_group(
  selection : @core.TextRange?,
  group : MarkdownEditorBlockGroup,
  group_start : Int,
) -> @core.TextRange? {
  match markdown_editor_active_selection(selection) {
    Some(range) =>
      if range.start >= group.source_start && range.end <= group.source_end {
        Some(
          @core.TextRange::new(
            start=markdown_editor_map_offset_to_group(
              range.start,
              group,
              group_start,
            ),
            end=markdown_editor_map_offset_to_group(
              range.end,
              group,
              group_start,
            ),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn markdown_editor_toggle_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  if source == "" {
    return markdown_editor_append_snippet(source, CodeBlock)
  }
  match markdown_editor_containing_quoted_code_block(source, selection) {
    Some(block) =>
      return markdown_editor_unwrap_quoted_code_block(source, block, selection)
    None => ()
  }
  match markdown_editor_containing_code_block(source, selection) {
    Some(block) => markdown_editor_unwrap_code_block(source, block, selection)
    None => markdown_editor_wrap_lines_in_code_block(source, selection)
  }
}

///|
struct MarkdownEditorQuotedCodeBlock {
  source_range : MarkdownSourceRange
  content_range : MarkdownSourceRange
} derive(Eq, Debug)

///|
struct MarkdownEditorQuotedCodeFence {
  quote_prefix : String
  fence : String
} derive(Eq, Debug)

///|
fn markdown_editor_containing_quoted_code_block(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorQuotedCodeBlock? {
  let lines = markdown_editor_lines(source)
  if lines.length() < 2 {
    return None
  }
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(
    anchor,
    0,
    markdown_editor_text_length(source),
  )
  let anchor_line = markdown_editor_line_index_at_offset(lines, anchor)
  let mut open_index = anchor_line
  while open_index >= 0 {
    match markdown_editor_quoted_code_fence_opening(lines[open_index].text) {
      Some(opening) =>
        for close_index in (open_index + 1)..<lines.length() {
          if markdown_editor_quoted_code_fence_closing(
              lines[close_index].text,
              opening,
            ) {
            if anchor >= lines[open_index].start &&
              anchor <= lines[close_index].end {
              let content_start = if close_index > open_index + 1 {
                lines[open_index + 1].start
              } else {
                lines[close_index].start
              }
              let content_end = if close_index > open_index + 1 {
                lines[close_index - 1].end
              } else {
                lines[close_index].start
              }
              return Some({
                source_range: {
                  start: lines[open_index].start,
                  end: lines[close_index].end,
                },
                content_range: { start: content_start, end: content_end },
              })
            }
            break
          }
        }
      None => ()
    }
    if open_index == 0 {
      break
    }
    open_index = open_index - 1
  }
  None
}

///|
fn markdown_editor_line_index_at_offset(
  lines : Array[MarkdownLine],
  offset : Int,
) -> Int {
  let mut result = 0
  for index in 0..<lines.length() {
    if offset >= lines[index].start && offset <= lines[index].end {
      return index
    }
    if offset > lines[index].end {
      result = index
    }
  }
  result
}

///|
fn markdown_editor_quoted_code_fence_opening(
  line : String,
) -> MarkdownEditorQuotedCodeFence? {
  let quote_prefix = markdown_editor_quote_context_prefix(line)
  if quote_prefix == "" {
    return None
  }
  let nested = markdown_editor_substring(
    line,
    markdown_editor_text_length(quote_prefix),
    markdown_editor_text_length(line),
  )
  match markdown_editor_opening_code_fence_marker(nested) {
    Some(fence) => Some({ quote_prefix, fence: fence.marker })
    None => None
  }
}

///|
fn markdown_editor_quoted_code_fence_closing(
  line : String,
  opening : MarkdownEditorQuotedCodeFence,
) -> Bool {
  let chars = line.to_array()
  if !markdown_editor_source_has_marker(chars, 0, opening.quote_prefix) {
    return false
  }
  let nested = markdown_editor_substring(
    line,
    markdown_editor_text_length(opening.quote_prefix),
    markdown_editor_text_length(line),
  )
  markdown_editor_closing_code_fence(nested, opening.fence)
}

///|
fn markdown_editor_unwrap_quoted_code_block(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult {
  let chars = source.to_array()
  let text = String::from_array(chars[:block.source_range.start]) +
    String::from_array(chars[block.content_range.start:block.content_range.end]) +
    String::from_array(chars[block.source_range.end:])
  let removed_before_content = block.content_range.start -
    block.source_range.start
  let removed_total = removed_before_content +
    block.source_range.end -
    block.content_range.end
  let caret = markdown_editor_unwrapped_quoted_code_offset(
    selection.caret,
    block,
    removed_before_content,
    removed_total,
  )
  let next_selection = match
    markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      Some(
        @core.TextRange::new(
          start=markdown_editor_unwrapped_quoted_code_offset(
            range.start,
            block,
            removed_before_content,
            removed_total,
          ),
          end=markdown_editor_unwrapped_quoted_code_offset(
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
fn markdown_editor_unwrapped_quoted_code_offset(
  offset : Int,
  block : MarkdownEditorQuotedCodeBlock,
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
  let quote_prefix = markdown_editor_code_block_quote_prefix(selected)
  let prefix = quote_prefix + "```\n"
  let suffix = "\n" + quote_prefix + "```"
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
fn markdown_editor_code_block_quote_prefix(selected : String) -> String {
  let lines = markdown_editor_lines(selected)
  if lines.length() == 0 {
    return ""
  }
  let prefix = markdown_editor_quote_context_prefix(lines[0].text)
  if prefix == "" {
    return ""
  }
  for line in lines {
    let text = line.text
    if text.trim().to_owned() == "" {
      continue
    }
    let line_chars = text.to_array()
    if !markdown_editor_source_has_marker(line_chars, 0, prefix) {
      return ""
    }
  }
  prefix
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
    InsertTableOfContents => "## Contents\n\n- [Section](#section)"
    InsertFrontMatter => "---\ntitle: Untitled\ntags: []\n---"
    DuplicateBlock | MoveBlockUp | MoveBlockDown => ""
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
  for block in parse_markdown_editor_blocks(source) {
    match block.block.kind {
      TaskListItem(checked) =>
        if content_offset == block.content_range.start {
          return markdown_editor_toggle_task_block(source, block, checked)
        }
      _ => ()
    }
  }
  None
}

///|
fn markdown_editor_toggle_current_task(
  source : String,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorEditResult? {
  let caret = markdown_editor_clamp_int(
    selection.caret,
    0,
    markdown_editor_text_length(source),
  )
  for block in parse_markdown_editor_blocks(source) {
    match block.block.kind {
      TaskListItem(checked) =>
        if caret >= block.source_range.start && caret <= block.source_range.end {
          return markdown_editor_toggle_task_block(source, block, checked)
        }
      _ => ()
    }
  }
  None
}

///|
fn markdown_editor_toggle_task_block(
  source : String,
  block : MarkdownEditorBlock,
  checked : Bool,
) -> MarkdownEditorEditResult? {
  let chars = source.to_array()
  let marker_index = block.content_range.start - 3
  if marker_index < 0 || marker_index >= chars.length() {
    return None
  }
  let next = if checked { ' ' } else { 'x' }
  let text = String::from_array(chars[:marker_index]) +
    String::from_array([next]) +
    String::from_array(chars[marker_index + 1:])
  Some({ source: text, caret: block.content_range.start, selection: None })
}

///|
