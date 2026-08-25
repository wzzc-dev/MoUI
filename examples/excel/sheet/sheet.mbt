///|
pub let default_row_count : Int = 30

///|
pub let default_col_count : Int = 12

///|
pub(all) struct Selection {
  row : Int
  col : Int
} derive(Eq, Debug)

///|
pub(all) struct Clipboard {
  cells : Array[Array[@cell.Cell]]
  origin : Selection
} derive(Eq, Debug)

///|
pub(all) struct IndexedCell {
  index : Int
  cell : @cell.Cell
} derive(Eq, Debug)

///|
pub(all) struct CellChange {
  row : Int
  col : Int
  old_cell : @cell.Cell
  new_cell : @cell.Cell
} derive(Eq, Debug)

///|
priv struct SortRow {
  source_row : Int
  cells : Array[@cell.Cell]
}

///|
priv struct FormulaRefToken {
  addr : @cell.CellAddress
  col_abs : Bool
  row_abs : Bool
}

///|
pub(all) enum UndoOp {
  CellEdit(Int, Int, @cell.Cell, @cell.Cell)
  CellBatchEdit(Array[CellChange])
  CellFormat(Int, Int, @cell.CellFormat, @cell.CellFormat)
  RowInsert(Int)
  ColumnInsert(Int)
  RowDelete(Int, Array[IndexedCell])
  ColumnDelete(Int, Array[IndexedCell])
} derive(Eq, Debug)

///|
pub(all) struct Sheet {
  name : String
  row_count : Int
  col_count : Int
  cells : Map[String, @cell.Cell]
} derive(Debug)

///|
pub(all) struct Workbook {
  sheets : Array[Sheet]
  active_sheet : Int
  selection : Selection?
  selection_range : @cell.CellRange?
  clipboard : Clipboard
  undo_stack : Array[UndoOp]
  redo_stack : Array[UndoOp]
} derive(Debug)

///|
pub fn Selection::new(row~ : Int, col~ : Int) -> Selection {
  { row, col }
}

///|
pub fn Selection::key(self : Selection) -> String {
  @cell.make_key(self.row, self.col)
}

///|
pub fn Clipboard::empty() -> Clipboard {
  { cells: [], origin: Selection::new(row=0, col=0) }
}

///|
pub fn Sheet::new(
  name : String,
  row_count? : Int = default_row_count,
  col_count? : Int = default_col_count,
) -> Sheet {
  { name, row_count, col_count, cells: Map([]) }
}

///|
pub fn Sheet::from_table(
  name : String,
  headers : Array[String],
  rows : Array[Array[String]],
) -> Sheet {
  let sheet = Sheet::new(
    name,
    row_count=rows.length() + 1,
    col_count=headers.length(),
  )
  let mut result = sheet
  for col, value in headers {
    result = result.set_raw_no_undo(0, col, value)
  }
  for row, values in rows {
    for col, value in values {
      result = result.set_raw_no_undo(row + 1, col, value)
    }
  }
  result.recalc()
}

///|
pub fn Sheet::get_cell(self : Sheet, row : Int, col : Int) -> @cell.Cell {
  match self.cells.get(@cell.make_key(row, col)) {
    Some(cell) => cell
    None => @cell.Cell::empty()
  }
}

///|
pub fn Sheet::display_cell(self : Sheet, row : Int, col : Int) -> String {
  self.get_cell(row, col).display()
}

///|
pub fn Sheet::safe_raw(self : Sheet, row : Int, col : Int) -> String {
  self.get_cell(row, col).raw
}

///|
pub fn Sheet::set_raw_no_undo(
  self : Sheet,
  row : Int,
  col : Int,
  raw : String,
) -> Sheet {
  let cells = self.cells.copy()
  let old = self.get_cell(row, col)
  let next_cell = { ..old, raw, value: @cell.parse_raw_value(raw) }
  let key = @cell.make_key(row, col)
  if next_cell.is_empty() {
    cells.remove(key)
  } else {
    cells[key] = next_cell
  }
  {
    ..self,
    row_count: max_int(self.row_count, row + 1),
    col_count: max_int(self.col_count, col + 1),
    cells,
  }
}

///|
pub fn Sheet::set_cell_no_undo(
  self : Sheet,
  row : Int,
  col : Int,
  next_cell : @cell.Cell,
) -> Sheet {
  let cells = self.cells.copy()
  let key = @cell.make_key(row, col)
  if next_cell.is_empty() {
    cells.remove(key)
  } else {
    cells[key] = next_cell
  }
  {
    ..self,
    row_count: max_int(self.row_count, row + 1),
    col_count: max_int(self.col_count, col + 1),
    cells,
  }
}

///|
pub fn Sheet::set_format_no_undo(
  self : Sheet,
  row : Int,
  col : Int,
  format : @cell.CellFormat,
) -> Sheet {
  let old = self.get_cell(row, col)
  self.set_cell_no_undo(row, col, { ..old, format, }).recalc()
}

///|
pub fn Sheet::recalc(self : Sheet) -> Sheet {
  let mut current = self
  for _ in 0..<3 {
    let base = current
    let cells = current.cells.copy()
    for key, existing in base.cells {
      let value = @formula.evaluate(existing.raw, ref_str => {
        match @cell.parse_ref(ref_str) {
          Some(addr) => base.get_cell(addr.row, addr.col).value
          None => @cell.CellValue::Empty
        }
      })
      cells[key] = { ..existing, value, }
    }
    current = { ..current, cells, }
  }
  current
}

///|
pub fn Sheet::used_cell_count(self : Sheet) -> Int {
  let mut count = 0
  for _, cell in self.cells {
    if !cell.raw.is_empty() {
      count = count + 1
    }
  }
  count
}

///|
pub fn Workbook::new() -> Workbook {
  Workbook::from_sheets([Sheet::new("Sheet1")])
}

///|
pub fn Workbook::from_sheets(
  sheets : Array[Sheet],
  active_sheet? : Int = 0,
) -> Workbook {
  let source = if sheets.is_empty() { [Sheet::new("Sheet1")] } else { sheets }
  let active = clamp_int(active_sheet, 0, source.length() - 1)
  {
    sheets: source,
    active_sheet: active,
    selection: None,
    selection_range: None,
    clipboard: Clipboard::empty(),
    undo_stack: [],
    redo_stack: [],
  }
}

///|
pub fn Workbook::demo() -> Workbook {
  let sales = Sheet::new("Sales")
    .set_raw_no_undo(0, 0, "Product")
    .set_raw_no_undo(0, 1, "Q1")
    .set_raw_no_undo(0, 2, "Q2")
    .set_raw_no_undo(0, 3, "Q3")
    .set_raw_no_undo(0, 4, "Q4")
    .set_raw_no_undo(0, 5, "Total")
    .set_raw_no_undo(1, 0, "Widget A")
    .set_raw_no_undo(1, 1, "1200")
    .set_raw_no_undo(1, 2, "1350")
    .set_raw_no_undo(1, 3, "1420")
    .set_raw_no_undo(1, 4, "1580")
    .set_raw_no_undo(1, 5, "=SUM(B2:E2)")
    .set_raw_no_undo(2, 0, "Widget B")
    .set_raw_no_undo(2, 1, "800")
    .set_raw_no_undo(2, 2, "920")
    .set_raw_no_undo(2, 3, "1100")
    .set_raw_no_undo(2, 4, "980")
    .set_raw_no_undo(2, 5, "=SUM(B3:E3)")
    .set_raw_no_undo(3, 0, "Gadget X")
    .set_raw_no_undo(3, 1, "2500")
    .set_raw_no_undo(3, 2, "2800")
    .set_raw_no_undo(3, 3, "3100")
    .set_raw_no_undo(3, 4, "2900")
    .set_raw_no_undo(3, 5, "=SUM(B4:E4)")
    .set_raw_no_undo(4, 0, "Gadget Y")
    .set_raw_no_undo(4, 1, "600")
    .set_raw_no_undo(4, 2, "750")
    .set_raw_no_undo(4, 3, "810")
    .set_raw_no_undo(4, 4, "920")
    .set_raw_no_undo(4, 5, "=SUM(B5:E5)")
    .set_raw_no_undo(5, 0, "Module Z")
    .set_raw_no_undo(5, 1, "1800")
    .set_raw_no_undo(5, 2, "1650")
    .set_raw_no_undo(5, 3, "1900")
    .set_raw_no_undo(5, 4, "2100")
    .set_raw_no_undo(5, 5, "=SUM(B6:E6)")
    .recalc()
  let inventory = Sheet::new("Inventory")
    .set_raw_no_undo(0, 0, "Product")
    .set_raw_no_undo(0, 1, "Stock")
    .set_raw_no_undo(0, 2, "Warehouse")
    .set_raw_no_undo(0, 3, "Status")
    .set_raw_no_undo(1, 0, "Widget A")
    .set_raw_no_undo(1, 1, "500")
    .set_raw_no_undo(1, 2, "A1")
    .set_raw_no_undo(1, 3, "OK")
    .set_raw_no_undo(2, 0, "Widget B")
    .set_raw_no_undo(2, 1, "120")
    .set_raw_no_undo(2, 2, "A2")
    .set_raw_no_undo(2, 3, "Low")
    .set_raw_no_undo(3, 0, "Gadget X")
    .set_raw_no_undo(3, 1, "800")
    .set_raw_no_undo(3, 2, "B1")
    .set_raw_no_undo(3, 3, "OK")
    .set_raw_no_undo(4, 0, "Gadget Y")
    .set_raw_no_undo(4, 1, "30")
    .set_raw_no_undo(4, 2, "B2")
    .set_raw_no_undo(4, 3, "Critical")
    .set_raw_no_undo(5, 0, "Module Z")
    .set_raw_no_undo(5, 1, "200")
    .set_raw_no_undo(5, 2, "C1")
    .set_raw_no_undo(5, 3, "OK")
    .recalc()
  Workbook::from_sheets([sales, inventory])
}

///|
pub fn Workbook::active(self : Workbook) -> Sheet {
  self.sheets[self.active_sheet]
}

///|
pub fn Workbook::sheet_names(self : Workbook) -> Array[String] {
  self.sheets.map(sheet => sheet.name)
}

///|
pub fn Workbook::selected_cell(self : Workbook) -> @cell.Cell {
  match self.selection {
    Some(sel) => self.active().get_cell(sel.row, sel.col)
    None => @cell.Cell::empty()
  }
}

///|
pub fn Workbook::selected_ref(self : Workbook) -> String {
  match self.selection_range {
    Some(range) => range_ref(range)
    None =>
      match self.selection {
        Some(sel) => sel.key()
        None => ""
      }
  }
}

///|
pub fn Workbook::select_cell(self : Workbook, row : Int, col : Int) -> Workbook {
  let sheet = self.active()
  let next = Selection::new(
    row=clamp_int(row, 0, sheet.row_count - 1),
    col=clamp_int(col, 0, sheet.col_count - 1),
  )
  { ..self, selection: Some(next), selection_range: None }
}

///|
pub fn Workbook::select_range(
  self : Workbook,
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
) -> Workbook {
  let sheet = self.active()
  let anchor_row = clamp_int(start_row, 0, sheet.row_count - 1)
  let anchor_col = clamp_int(start_col, 0, sheet.col_count - 1)
  let row_start = clamp_int(min_int(start_row, end_row), 0, sheet.row_count - 1)
  let row_end = clamp_int(max_int(start_row, end_row), 0, sheet.row_count - 1)
  let col_start = clamp_int(min_int(start_col, end_col), 0, sheet.col_count - 1)
  let col_end = clamp_int(max_int(start_col, end_col), 0, sheet.col_count - 1)
  {
    ..self,
    selection: Some(Selection::new(row=anchor_row, col=anchor_col)),
    selection_range: Some(
      @cell.CellRange::new(
        start=@cell.CellAddress::new(row=row_start, col=col_start),
        end=@cell.CellAddress::new(row=row_end, col=col_end),
      ),
    ),
  }
}

///|
pub fn Workbook::selected_range(self : Workbook) -> @cell.CellRange? {
  self.selection_range
}

///|
pub fn Workbook::cell_is_selected(
  self : Workbook,
  row : Int,
  col : Int,
) -> Bool {
  match self.selection_range {
    Some(range) =>
      row >= range.start.row &&
      row <= range.end.row &&
      col >= range.start.col &&
      col <= range.end.col
    None =>
      match self.selection {
        Some(sel) => sel.row == row && sel.col == col
        None => false
      }
  }
}

///|
fn range_ref(range : @cell.CellRange) -> String {
  let start = range.start.key()
  let end = range.end.key()
  if start == end {
    start
  } else {
    start + ":" + end
  }
}

///|
pub fn Workbook::switch_sheet(self : Workbook, index : Int) -> Workbook {
  if index < 0 || index >= self.sheets.length() {
    self
  } else {
    {
      ..self,
      active_sheet: index,
      selection: None,
      selection_range: None,
      undo_stack: [],
      redo_stack: [],
    }
  }
}

///|
pub fn Workbook::navigate(self : Workbook, drow : Int, dcol : Int) -> Workbook {
  match self.selection {
    None => self.select_cell(0, 0)
    Some(sel) => self.select_cell(sel.row + drow, sel.col + dcol)
  }
}

///|
pub fn Workbook::navigate_to_data_edge(
  self : Workbook,
  drow : Int,
  dcol : Int,
) -> Workbook {
  match self.selection {
    None => self.select_cell(0, 0)
    Some(sel) => {
      let edge = self.active().data_edge_position(sel.row, sel.col, drow, dcol)
      self.select_cell(edge.row, edge.col)
    }
  }
}

///|
pub fn Workbook::extend_selection(
  self : Workbook,
  drow : Int,
  dcol : Int,
) -> Workbook {
  match self.selection {
    None => self.select_cell(0, 0)
    Some(anchor) => {
      let sheet = self.active()
      let focus = match self.selection_range {
        Some(range) =>
          Selection::new(
            row=if anchor.row == range.start.row {
              range.end.row
            } else {
              range.start.row
            },
            col=if anchor.col == range.start.col {
              range.end.col
            } else {
              range.start.col
            },
          )
        None => anchor
      }
      let next_row = clamp_int(focus.row + drow, 0, sheet.row_count - 1)
      let next_col = clamp_int(focus.col + dcol, 0, sheet.col_count - 1)
      self.select_range(anchor.row, anchor.col, next_row, next_col)
    }
  }
}

///|
pub fn Workbook::extend_selection_to(
  self : Workbook,
  row : Int,
  col : Int,
) -> Workbook {
  match self.selection {
    None => self.select_cell(row, col)
    Some(anchor) => self.select_range(anchor.row, anchor.col, row, col)
  }
}

///|
pub fn Workbook::extend_selection_to_data_edge(
  self : Workbook,
  drow : Int,
  dcol : Int,
) -> Workbook {
  match self.selection {
    None => self.select_cell(0, 0)
    Some(anchor) => {
      let edge = self
        .active()
        .data_edge_position(anchor.row, anchor.col, drow, dcol)
      self.select_range(anchor.row, anchor.col, edge.row, edge.col)
    }
  }
}

///|
pub fn Workbook::set_selected_raw(self : Workbook, raw : String) -> Workbook {
  match self.selection {
    None => self
    Some(sel) => self.set_raw(sel.row, sel.col, raw)
  }
}

///|
pub fn Workbook::set_raw(
  self : Workbook,
  row : Int,
  col : Int,
  raw : String,
) -> Workbook {
  let sheet = self.active()
  let old_cell = sheet.get_cell(row, col)
  let updated_sheet = sheet.set_raw_no_undo(row, col, raw).recalc()
  let new_cell = updated_sheet.get_cell(row, col)
  let next = self.with_active_sheet(updated_sheet)
  if old_cell == new_cell {
    next
  } else {
    next.push_undo(UndoOp::CellEdit(row, col, old_cell, new_cell))
  }
}

///|
pub fn Workbook::set_selected_format(
  self : Workbook,
  updater : (@cell.CellFormat) -> @cell.CellFormat,
) -> Workbook {
  match self.selection_range {
    Some(range) =>
      self.set_format_range(
        range.start.row,
        range.start.col,
        range.end.row,
        range.end.col,
        updater,
      )
    None =>
      match self.selection {
        None => self
        Some(sel) => self.set_format(sel.row, sel.col, updater)
      }
  }
}

///|
pub fn Workbook::set_format_range(
  self : Workbook,
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
  updater : (@cell.CellFormat) -> @cell.CellFormat,
) -> Workbook {
  let sheet = self.active()
  let row_start = clamp_int(min_int(start_row, end_row), 0, sheet.row_count - 1)
  let row_end = clamp_int(max_int(start_row, end_row), 0, sheet.row_count - 1)
  let col_start = clamp_int(min_int(start_col, end_col), 0, sheet.col_count - 1)
  let col_end = clamp_int(max_int(start_col, end_col), 0, sheet.col_count - 1)
  let changes : Array[CellChange] = []
  let mut updated_sheet = sheet
  for row in row_start..<=row_end {
    for col in col_start..<=col_end {
      let old_cell = updated_sheet.get_cell(row, col)
      let new_format = updater(old_cell.format)
      if old_cell.format != new_format {
        let new_cell = { ..old_cell, format: new_format }
        updated_sheet = updated_sheet.set_cell_no_undo(row, col, new_cell)
        changes.push({ row, col, old_cell, new_cell })
      }
    }
  }
  let next = self.with_active_sheet(updated_sheet.recalc())
  if changes.is_empty() {
    next
  } else if changes.length() == 1 {
    let change = changes[0]
    next.push_undo(
      UndoOp::CellEdit(change.row, change.col, change.old_cell, change.new_cell),
    )
  } else {
    next.push_undo(UndoOp::CellBatchEdit(changes))
  }
}

///|
pub fn Workbook::set_format(
  self : Workbook,
  row : Int,
  col : Int,
  updater : (@cell.CellFormat) -> @cell.CellFormat,
) -> Workbook {
  let sheet = self.active()
  let old_cell = sheet.get_cell(row, col)
  let old_format = old_cell.format
  let new_format = updater(old_format)
  if old_format == new_format {
    self
  } else {
    let updated_sheet = sheet.set_format_no_undo(row, col, new_format)
    self
    .with_active_sheet(updated_sheet)
    .push_undo(UndoOp::CellFormat(row, col, old_format, new_format))
  }
}

///|
pub fn Workbook::clear_selected(self : Workbook) -> Workbook {
  match self.selection_range {
    Some(range) =>
      self.clear_range(
        range.start.row,
        range.start.col,
        range.end.row,
        range.end.col,
      )
    None =>
      match self.selection {
        None => self
        Some(sel) => self.clear_range(sel.row, sel.col, sel.row, sel.col)
      }
  }
}

///|
pub fn Workbook::clear_range(
  self : Workbook,
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
) -> Workbook {
  let sheet = self.active()
  let row_start = clamp_int(min_int(start_row, end_row), 0, sheet.row_count - 1)
  let row_end = clamp_int(max_int(start_row, end_row), 0, sheet.row_count - 1)
  let col_start = clamp_int(min_int(start_col, end_col), 0, sheet.col_count - 1)
  let col_end = clamp_int(max_int(start_col, end_col), 0, sheet.col_count - 1)
  let changes : Array[CellChange] = []
  let empty = @cell.Cell::empty()
  let mut updated_sheet = sheet
  for row in row_start..<=row_end {
    for col in col_start..<=col_end {
      let old_cell = updated_sheet.get_cell(row, col)
      if old_cell != empty {
        updated_sheet = updated_sheet.set_cell_no_undo(row, col, empty)
        changes.push({ row, col, old_cell, new_cell: empty })
      }
    }
  }
  let next = self.with_active_sheet(updated_sheet.recalc())
  if changes.is_empty() {
    next
  } else if changes.length() == 1 {
    let change = changes[0]
    next.push_undo(
      UndoOp::CellEdit(change.row, change.col, change.old_cell, change.new_cell),
    )
  } else {
    next.push_undo(UndoOp::CellBatchEdit(changes))
  }
}

///|
pub fn Workbook::copy_selected(self : Workbook) -> Workbook {
  match self.selection_range {
    Some(range) =>
      self.copy_range(
        range.start.row,
        range.start.col,
        range.end.row,
        range.end.col,
      )
    None =>
      match self.selection {
        None => self
        Some(sel) => {
          let cell = self.active().get_cell(sel.row, sel.col)
          { ..self, clipboard: { cells: [[cell]], origin: sel } }
        }
      }
  }
}

///|
pub fn Workbook::copy_range(
  self : Workbook,
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
) -> Workbook {
  let sheet = self.active()
  let row_start = clamp_int(min_int(start_row, end_row), 0, sheet.row_count - 1)
  let row_end = clamp_int(max_int(start_row, end_row), 0, sheet.row_count - 1)
  let col_start = clamp_int(min_int(start_col, end_col), 0, sheet.col_count - 1)
  let col_end = clamp_int(max_int(start_col, end_col), 0, sheet.col_count - 1)
  let rows : Array[Array[@cell.Cell]] = []
  for row in row_start..<=row_end {
    let cells : Array[@cell.Cell] = []
    for col in col_start..<=col_end {
      cells.push(sheet.get_cell(row, col))
    }
    rows.push(cells)
  }
  {
    ..self,
    clipboard: {
      cells: rows,
      origin: Selection::new(row=row_start, col=col_start),
    },
  }
}

///|
pub fn Workbook::has_clipboard(self : Workbook) -> Bool {
  !self.clipboard.cells.is_empty()
}

///|
pub fn Workbook::clipboard_tsv(self : Workbook) -> String {
  let rows : Array[String] = []
  for row_cells in self.clipboard.cells {
    let values : Array[String] = []
    for cell in row_cells {
      values.push(tsv_escape_cell(cell.display()))
    }
    rows.push(values.join("\t"))
  }
  rows.join("\n")
}

///|
pub fn Workbook::cut_selected(self : Workbook) -> Workbook {
  self.copy_selected().clear_selected()
}

///|
pub fn Workbook::paste_selected(self : Workbook) -> Workbook {
  match self.selection {
    None => self
    Some(sel) => {
      let changes : Array[CellChange] = []
      let mut sheet = self.active()
      let row_count = self.clipboard.cells.length()
      let mut col_count = 0
      for row_cells in self.clipboard.cells {
        col_count = max_int(col_count, row_cells.length())
      }
      for row_offset, row_cells in self.clipboard.cells {
        for col_offset, source_cell in row_cells {
          let row = sel.row + row_offset
          let col = sel.col + col_offset
          let old_cell = sheet.get_cell(row, col)
          let next_cell = adjust_pasted_cell(
            source_cell,
            drow=row - (self.clipboard.origin.row + row_offset),
            dcol=col - (self.clipboard.origin.col + col_offset),
          )
          sheet = sheet.set_cell_no_undo(row, col, next_cell)
          if old_cell != next_cell {
            changes.push({ row, col, old_cell, new_cell: next_cell })
          }
        }
      }
      let next = self
        .with_active_sheet(sheet.recalc())
        .select_pasted_area(sel, row_count, col_count)
      if changes.is_empty() {
        next
      } else if changes.length() == 1 {
        let change = changes[0]
        next.push_undo(
          UndoOp::CellEdit(
            change.row,
            change.col,
            change.old_cell,
            change.new_cell,
          ),
        )
      } else {
        next.push_undo(UndoOp::CellBatchEdit(changes))
      }
    }
  }
}

///|
pub fn Workbook::paste_tsv(self : Workbook, text : String) -> Workbook {
  match self.selection {
    None => self
    Some(sel) => {
      let rows = parse_tsv_rows(text)
      if rows.is_empty() {
        return self
      }
      let row_count = rows.length()
      let mut col_count = 0
      for row_values in rows {
        col_count = max_int(col_count, row_values.length())
      }
      let changes : Array[CellChange] = []
      let mut sheet = self.active()
      for row_offset, row_values in rows {
        for col_offset, raw in row_values {
          let row = sel.row + row_offset
          let col = sel.col + col_offset
          let old_cell = sheet.get_cell(row, col)
          let next_cell = { ..old_cell, raw, value: @cell.parse_raw_value(raw) }
          sheet = sheet.set_cell_no_undo(row, col, next_cell)
          if old_cell != next_cell {
            changes.push({ row, col, old_cell, new_cell: next_cell })
          }
        }
      }
      let next = self
        .with_active_sheet(sheet.recalc())
        .select_pasted_area(sel, row_count, col_count)
      if changes.is_empty() {
        next
      } else if changes.length() == 1 {
        let change = changes[0]
        next.push_undo(
          UndoOp::CellEdit(
            change.row,
            change.col,
            change.old_cell,
            change.new_cell,
          ),
        )
      } else {
        next.push_undo(UndoOp::CellBatchEdit(changes))
      }
    }
  }
}

///|
fn Workbook::select_pasted_area(
  self : Workbook,
  anchor : Selection,
  row_count : Int,
  col_count : Int,
) -> Workbook {
  if row_count <= 0 || col_count <= 0 {
    self
  } else if row_count == 1 && col_count == 1 {
    self.select_cell(anchor.row, anchor.col)
  } else {
    self.select_range(
      anchor.row,
      anchor.col,
      anchor.row + row_count - 1,
      anchor.col + col_count - 1,
    )
  }
}

///|
fn parse_tsv_rows(text : String) -> Array[Array[String]] {
  if text.is_empty() {
    return []
  }
  let rows : Array[Array[String]] = []
  let chars = text.to_array()
  let mut row : Array[String] = []
  let cell = StringBuilder()
  let mut quoted = false
  let mut ended_with_row_separator = false
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if quoted {
      if ch == '"' {
        if index + 1 < chars.length() && chars[index + 1] == '"' {
          cell.write_char('"')
          index = index + 2
        } else {
          quoted = false
          index = index + 1
        }
      } else {
        cell.write_char(ch)
        index = index + 1
      }
    } else if ch == '"' && cell.is_empty() {
      quoted = true
      ended_with_row_separator = false
      index = index + 1
    } else if ch == '\t' {
      row.push(cell.to_string())
      cell.reset()
      ended_with_row_separator = false
      index = index + 1
    } else if ch == '\n' {
      row.push(cell.to_string())
      rows.push(row)
      row = []
      cell.reset()
      ended_with_row_separator = true
      index = index + 1
    } else if ch == '\r' {
      row.push(cell.to_string())
      rows.push(row)
      row = []
      cell.reset()
      ended_with_row_separator = true
      if index + 1 < chars.length() && chars[index + 1] == '\n' {
        index = index + 2
      } else {
        index = index + 1
      }
    } else {
      cell.write_char(ch)
      ended_with_row_separator = false
      index = index + 1
    }
  }
  if !(ended_with_row_separator && row.is_empty() && cell.is_empty()) {
    row.push(cell.to_string())
    rows.push(row)
  }
  rows
}

///|
fn tsv_escape_cell(value : String) -> String {
  if !(value.contains("\t") ||
    value.contains("\n") ||
    value.contains("\r") ||
    value.contains("\"")) {
    return value
  }
  let builder = StringBuilder()
  builder.write_char('"')
  for ch in value {
    if ch == '"' {
      builder.write_char('"')
      builder.write_char('"')
    } else {
      builder.write_char(ch)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
pub fn Workbook::sort_selected_by_first_column(
  self : Workbook,
  ascending~ : Bool,
) -> Workbook {
  match self.selection_range {
    None => self
    Some(range) => {
      if range.start.row >= range.end.row {
        return self
      }
      let sheet = self.active()
      let rows : Array[SortRow] = []
      for row in range.start.row..<=range.end.row {
        let cells : Array[@cell.Cell] = []
        for col in range.start.col..<=range.end.col {
          cells.push(sheet.get_cell(row, col))
        }
        rows.push({ source_row: row, cells })
      }
      rows.sort_by(fn(left, right) {
        compare_sort_rows(left, right, ascending~)
      })
      let changes : Array[CellChange] = []
      let mut updated_sheet = sheet
      for row_offset, sort_row in rows {
        let target_row = range.start.row + row_offset
        for col_offset, next_cell in sort_row.cells {
          let col = range.start.col + col_offset
          let old_cell = updated_sheet.get_cell(target_row, col)
          if old_cell != next_cell {
            updated_sheet = updated_sheet.set_cell_no_undo(
              target_row, col, next_cell,
            )
            changes.push({ row: target_row, col, old_cell, new_cell: next_cell })
          }
        }
      }
      let next = self.with_active_sheet(updated_sheet.recalc())
      if changes.is_empty() {
        next
      } else if changes.length() == 1 {
        let change = changes[0]
        next.push_undo(
          UndoOp::CellEdit(
            change.row,
            change.col,
            change.old_cell,
            change.new_cell,
          ),
        )
      } else {
        next.push_undo(UndoOp::CellBatchEdit(changes))
      }
    }
  }
}

///|
fn compare_sort_rows(left : SortRow, right : SortRow, ascending~ : Bool) -> Int {
  let left_key = left.cells[0]
  let right_key = right.cells[0]
  let left_blank = sort_cell_is_blank(left_key)
  let right_blank = sort_cell_is_blank(right_key)
  if left_blank && right_blank {
    left.source_row.compare(right.source_row)
  } else if left_blank {
    1
  } else if right_blank {
    -1
  } else {
    let value_order = compare_sort_cells(left_key, right_key)
    let directed = if ascending { value_order } else { -value_order }
    if directed == 0 {
      left.source_row.compare(right.source_row)
    } else {
      directed
    }
  }
}

///|
fn sort_cell_is_blank(cell : @cell.Cell) -> Bool {
  cell.raw.trim().to_owned().is_empty() || cell.value is @cell.CellValue::Empty
}

///|
fn compare_sort_cells(left : @cell.Cell, right : @cell.Cell) -> Int {
  match (left.value, right.value) {
    (@cell.CellValue::Number(a), @cell.CellValue::Number(b)) =>
      compare_double(a, b)
    (@cell.CellValue::Text(a), @cell.CellValue::Text(b)) => compare_text(a, b)
    (@cell.CellValue::Error(a), @cell.CellValue::Error(b)) => compare_text(a, b)
    (left_value, right_value) => {
      let rank_order = sort_value_rank(left_value).compare(
        sort_value_rank(right_value),
      )
      if rank_order == 0 {
        compare_text(left.display(), right.display())
      } else {
        rank_order
      }
    }
  }
}

///|
fn sort_value_rank(value : @cell.CellValue) -> Int {
  match value {
    @cell.CellValue::Number(_) => 0
    @cell.CellValue::Text(_) => 1
    @cell.CellValue::Error(_) => 2
    @cell.CellValue::Empty => 3
  }
}

///|
fn compare_double(left : Double, right : Double) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_text(left : String, right : String) -> Int {
  let primary = left.compare_ignore_ascii_case(right)
  if primary == 0 {
    left.compare(right)
  } else {
    primary
  }
}

///|
pub fn Workbook::fill_down_selected(self : Workbook) -> Workbook {
  match self.selection_range {
    None => self
    Some(range) => {
      if range.start.row >= range.end.row {
        return self
      }
      let sheet = self.active()
      let changes : Array[CellChange] = []
      let mut updated_sheet = sheet
      for row in (range.start.row + 1)..<=range.end.row {
        for col in range.start.col..<=range.end.col {
          let source_cell = sheet.get_cell(range.start.row, col)
          let old_cell = updated_sheet.get_cell(row, col)
          let next_cell = adjust_pasted_cell(
            source_cell,
            drow=row - range.start.row,
            dcol=0,
          )
          if old_cell != next_cell {
            updated_sheet = updated_sheet.set_cell_no_undo(row, col, next_cell)
            changes.push({ row, col, old_cell, new_cell: next_cell })
          }
        }
      }
      let next = self.with_active_sheet(updated_sheet.recalc())
      if changes.is_empty() {
        next
      } else if changes.length() == 1 {
        let change = changes[0]
        next.push_undo(
          UndoOp::CellEdit(
            change.row,
            change.col,
            change.old_cell,
            change.new_cell,
          ),
        )
      } else {
        next.push_undo(UndoOp::CellBatchEdit(changes))
      }
    }
  }
}

///|
pub fn Workbook::fill_right_selected(self : Workbook) -> Workbook {
  match self.selection_range {
    None => self
    Some(range) => {
      if range.start.col >= range.end.col {
        return self
      }
      let sheet = self.active()
      let changes : Array[CellChange] = []
      let mut updated_sheet = sheet
      for row in range.start.row..<=range.end.row {
        for col in (range.start.col + 1)..<=range.end.col {
          let source_cell = sheet.get_cell(row, range.start.col)
          let old_cell = updated_sheet.get_cell(row, col)
          let next_cell = adjust_pasted_cell(
            source_cell,
            drow=0,
            dcol=col - range.start.col,
          )
          if old_cell != next_cell {
            updated_sheet = updated_sheet.set_cell_no_undo(row, col, next_cell)
            changes.push({ row, col, old_cell, new_cell: next_cell })
          }
        }
      }
      let next = self.with_active_sheet(updated_sheet.recalc())
      if changes.is_empty() {
        next
      } else if changes.length() == 1 {
        let change = changes[0]
        next.push_undo(
          UndoOp::CellEdit(
            change.row,
            change.col,
            change.old_cell,
            change.new_cell,
          ),
        )
      } else {
        next.push_undo(UndoOp::CellBatchEdit(changes))
      }
    }
  }
}

///|
pub fn Workbook::insert_row(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  let idx = clamp_int(index, 0, sheet.row_count)
  self
  .with_active_sheet(shift_sheet_rows(sheet, idx, 1))
  .push_undo(UndoOp::RowInsert(idx))
}

///|
pub fn Workbook::delete_row(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  if index < 0 || index >= sheet.row_count {
    self
  } else {
    let deleted = collect_row_cells(sheet, index)
    self
    .with_active_sheet(shift_sheet_rows(sheet, index, -1))
    .push_undo(UndoOp::RowDelete(index, deleted))
  }
}

///|
pub fn Workbook::insert_column(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  let idx = clamp_int(index, 0, sheet.col_count)
  self
  .with_active_sheet(shift_sheet_cols(sheet, idx, 1))
  .push_undo(UndoOp::ColumnInsert(idx))
}

///|
pub fn Workbook::delete_column(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  if index < 0 || index >= sheet.col_count {
    self
  } else {
    let deleted = collect_column_cells(sheet, index)
    self
    .with_active_sheet(shift_sheet_cols(sheet, index, -1))
    .push_undo(UndoOp::ColumnDelete(index, deleted))
  }
}

///|
pub fn Workbook::add_sheet(self : Workbook) -> Workbook {
  let sheets = self.sheets.copy()
  let name = next_sheet_name(sheets)
  sheets.push(Sheet::new(name))
  {
    ..self,
    sheets,
    active_sheet: sheets.length() - 1,
    selection: None,
    selection_range: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn next_sheet_name(sheets : Array[Sheet]) -> String {
  let mut index = sheets.length() + 1
  while true {
    let name = "Sheet " + index.to_string()
    if !sheets.any(sheet => sheet.name == name) {
      return name
    }
    index = index + 1
  }
  "Sheet"
}

///|
pub fn Workbook::delete_sheet(self : Workbook, index : Int) -> Workbook {
  if self.sheets.length() <= 1 || index < 0 || index >= self.sheets.length() {
    self
  } else {
    let sheets = self.sheets.copy()
    ignore(sheets.remove(index))
    let active_sheet = active_sheet_after_delete(
      self.active_sheet,
      index,
      sheets.length(),
    )
    {
      ..self,
      sheets,
      active_sheet,
      selection: None,
      selection_range: None,
      undo_stack: [],
      redo_stack: [],
    }
  }
}

///|
fn active_sheet_after_delete(
  active : Int,
  deleted : Int,
  next_len : Int,
) -> Int {
  if deleted < active {
    active - 1
  } else if deleted == active && active >= next_len {
    next_len - 1
  } else {
    active
  }
}

///|
pub fn Workbook::undo(self : Workbook) -> Workbook {
  match self.undo_stack.last() {
    None => self
    Some(op) => {
      let undo_stack = self.undo_stack.copy()
      ignore(undo_stack.pop())
      let redo_stack = self.redo_stack.copy()
      redo_stack.push(op)
      let result = match op {
        UndoOp::CellEdit(row, col, old_cell, _new_cell) =>
          self.with_active_sheet(
            self.active().set_cell_no_undo(row, col, old_cell).recalc(),
          )
        UndoOp::CellBatchEdit(changes) =>
          self.with_active_sheet(
            apply_cell_changes(self.active(), changes, old=true),
          )
        UndoOp::CellFormat(row, col, old_format, _new_format) =>
          self.with_active_sheet(
            self.active().set_format_no_undo(row, col, old_format),
          )
        UndoOp::RowInsert(index) =>
          self.with_active_sheet(shift_sheet_rows(self.active(), index, -1))
        UndoOp::ColumnInsert(index) =>
          self.with_active_sheet(shift_sheet_cols(self.active(), index, -1))
        UndoOp::RowDelete(index, cells) =>
          self.with_active_sheet(restore_row_cells(self.active(), index, cells))
        UndoOp::ColumnDelete(index, cells) =>
          self.with_active_sheet(
            restore_column_cells(self.active(), index, cells),
          )
      }
      { ..result, undo_stack, redo_stack }
    }
  }
}

///|
pub fn Workbook::redo(self : Workbook) -> Workbook {
  match self.redo_stack.last() {
    None => self
    Some(op) => {
      let redo_stack = self.redo_stack.copy()
      ignore(redo_stack.pop())
      let undo_stack = self.undo_stack.copy()
      undo_stack.push(op)
      let result = match op {
        UndoOp::CellEdit(row, col, _old_cell, new_cell) =>
          self.with_active_sheet(
            self.active().set_cell_no_undo(row, col, new_cell).recalc(),
          )
        UndoOp::CellBatchEdit(changes) =>
          self.with_active_sheet(
            apply_cell_changes(self.active(), changes, old=false),
          )
        UndoOp::CellFormat(row, col, _old_format, new_format) =>
          self.with_active_sheet(
            self.active().set_format_no_undo(row, col, new_format),
          )
        UndoOp::RowInsert(index) =>
          self.with_active_sheet(shift_sheet_rows(self.active(), index, 1))
        UndoOp::ColumnInsert(index) =>
          self.with_active_sheet(shift_sheet_cols(self.active(), index, 1))
        UndoOp::RowDelete(index, _cells) =>
          self.with_active_sheet(shift_sheet_rows(self.active(), index, -1))
        UndoOp::ColumnDelete(index, _cells) =>
          self.with_active_sheet(shift_sheet_cols(self.active(), index, -1))
      }
      { ..result, undo_stack, redo_stack }
    }
  }
}

///|
fn apply_cell_changes(
  sheet : Sheet,
  changes : Array[CellChange],
  old~ : Bool,
) -> Sheet {
  let mut result = sheet
  for change in changes {
    result = result.set_cell_no_undo(
      change.row,
      change.col,
      if old {
        change.old_cell
      } else {
        change.new_cell
      },
    )
  }
  result.recalc()
}

///|
pub fn Workbook::with_active_sheet(self : Workbook, sheet : Sheet) -> Workbook {
  let sheets = self.sheets.copy()
  sheets[self.active_sheet] = sheet
  { ..self, sheets, }
}

///|
pub fn Workbook::push_undo(self : Workbook, op : UndoOp) -> Workbook {
  let undo_stack = self.undo_stack.copy()
  undo_stack.push(op)
  { ..self, undo_stack, redo_stack: [] }
}

///|
fn shift_sheet_rows(sheet : Sheet, index : Int, delta : Int) -> Sheet {
  let cells : Map[String, @cell.Cell] = Map([])
  for key, cell in sheet.cells {
    match @cell.parse_ref(key) {
      Some(addr) =>
        if delta > 0 {
          let row = if addr.row >= index { addr.row + 1 } else { addr.row }
          cells[@cell.make_key(row, addr.col)] = adjust_cell_row_refs(
            cell, index, delta,
          )
        } else if addr.row == index {
          ()
        } else {
          let row = if addr.row > index { addr.row - 1 } else { addr.row }
          cells[@cell.make_key(row, addr.col)] = adjust_cell_row_refs(
            cell, index, delta,
          )
        }
      None => ()
    }
  }
  let row_count = if delta > 0 {
    sheet.row_count + 1
  } else {
    max_int(1, sheet.row_count - 1)
  }
  { ..sheet, row_count, cells }.recalc()
}

///|
fn collect_row_cells(sheet : Sheet, row : Int) -> Array[IndexedCell] {
  let cells : Array[IndexedCell] = []
  for key, cell in sheet.cells {
    match @cell.parse_ref(key) {
      Some(addr) => if addr.row == row { cells.push({ index: addr.col, cell }) }
      None => ()
    }
  }
  cells
}

///|
fn restore_row_cells(
  sheet : Sheet,
  row : Int,
  cells : Array[IndexedCell],
) -> Sheet {
  let mut result = shift_sheet_rows(sheet, row, 1)
  for item in cells {
    result = result.set_cell_no_undo(row, item.index, item.cell)
  }
  result.recalc()
}

///|
fn shift_sheet_cols(sheet : Sheet, index : Int, delta : Int) -> Sheet {
  let cells : Map[String, @cell.Cell] = Map([])
  for key, cell in sheet.cells {
    match @cell.parse_ref(key) {
      Some(addr) =>
        if delta > 0 {
          let col = if addr.col >= index { addr.col + 1 } else { addr.col }
          cells[@cell.make_key(addr.row, col)] = adjust_cell_col_refs(
            cell, index, delta,
          )
        } else if addr.col == index {
          ()
        } else {
          let col = if addr.col > index { addr.col - 1 } else { addr.col }
          cells[@cell.make_key(addr.row, col)] = adjust_cell_col_refs(
            cell, index, delta,
          )
        }
      None => ()
    }
  }
  let col_count = if delta > 0 {
    sheet.col_count + 1
  } else {
    max_int(1, sheet.col_count - 1)
  }
  { ..sheet, col_count, cells }.recalc()
}

///|
fn collect_column_cells(sheet : Sheet, col : Int) -> Array[IndexedCell] {
  let cells : Array[IndexedCell] = []
  for key, cell in sheet.cells {
    match @cell.parse_ref(key) {
      Some(addr) => if addr.col == col { cells.push({ index: addr.row, cell }) }
      None => ()
    }
  }
  cells
}

///|
fn restore_column_cells(
  sheet : Sheet,
  col : Int,
  cells : Array[IndexedCell],
) -> Sheet {
  let mut result = shift_sheet_cols(sheet, col, 1)
  for item in cells {
    result = result.set_cell_no_undo(item.index, col, item.cell)
  }
  result.recalc()
}

///|
fn adjust_pasted_cell(
  cell : @cell.Cell,
  drow~ : Int,
  dcol~ : Int,
) -> @cell.Cell {
  { ..cell, raw: translate_formula_refs(cell.raw, drow~, dcol~) }
}

///|
fn translate_formula_refs(raw : String, drow~ : Int, dcol~ : Int) -> String {
  rewrite_formula_refs(raw, ref_token => {
    let row = if ref_token.row_abs {
      ref_token.addr.row
    } else {
      ref_token.addr.row + drow
    }
    let col = if ref_token.col_abs {
      ref_token.addr.col
    } else {
      ref_token.addr.col + dcol
    }
    if row < 0 || col < 0 {
      "#REF!"
    } else {
      format_ref_token(ref_token, row, col)
    }
  })
}

///|
fn adjust_cell_row_refs(
  cell : @cell.Cell,
  index : Int,
  delta : Int,
) -> @cell.Cell {
  {
    ..cell,
    raw: rewrite_formula_refs(cell.raw, ref_token => {
      shift_row_ref(ref_token, index, delta)
    }),
  }
}

///|
fn adjust_cell_col_refs(
  cell : @cell.Cell,
  index : Int,
  delta : Int,
) -> @cell.Cell {
  {
    ..cell,
    raw: rewrite_formula_refs(cell.raw, ref_token => {
      shift_col_ref(ref_token, index, delta)
    }),
  }
}

///|
fn shift_row_ref(token : FormulaRefToken, index : Int, delta : Int) -> String {
  let addr = token.addr
  if delta > 0 {
    let row = if addr.row >= index { addr.row + delta } else { addr.row }
    format_ref_token(token, row, addr.col)
  } else if addr.row == index {
    "#REF!"
  } else {
    let row = if addr.row > index { addr.row + delta } else { addr.row }
    format_ref_token(token, row, addr.col)
  }
}

///|
fn shift_col_ref(token : FormulaRefToken, index : Int, delta : Int) -> String {
  let addr = token.addr
  if delta > 0 {
    let col = if addr.col >= index { addr.col + delta } else { addr.col }
    format_ref_token(token, addr.row, col)
  } else if addr.col == index {
    "#REF!"
  } else {
    let col = if addr.col > index { addr.col + delta } else { addr.col }
    format_ref_token(token, addr.row, col)
  }
}

///|
fn rewrite_formula_refs(
  raw : String,
  rewrite : (FormulaRefToken) -> String,
) -> String {
  if raw.length() <= 1 || raw[0] != '=' {
    return raw
  }
  let chars = raw.to_array()
  let builder = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    if is_ascii_letter(chars[i]) || chars[i] == '$' {
      let start = i
      let mut col_abs = false
      if chars[i] == '$' {
        col_abs = true
        i = i + 1
      }
      let col_start = i
      while i < chars.length() && is_ascii_letter(chars[i]) {
        i = i + 1
      }
      let col_end = i
      let mut row_abs = false
      if i < chars.length() && chars[i] == '$' {
        row_abs = true
        i = i + 1
      }
      let row_start = i
      while i < chars.length() && is_ascii_digit(chars[i]) {
        i = i + 1
      }
      let token = chars_to_string(chars[start:i])
      if col_start < col_end && row_start < i {
        match @cell.parse_ref(token) {
          Some(addr) =>
            builder.write_string(rewrite({ addr, col_abs, row_abs }))
          None => builder.write_string(token)
        }
      } else {
        builder.write_string(token)
      }
    } else {
      builder.write_char(chars[i])
      i = i + 1
    }
  }
  builder.to_string()
}

///|
fn format_ref_token(token : FormulaRefToken, row : Int, col : Int) -> String {
  let col_prefix = if token.col_abs { "$" } else { "" }
  let row_prefix = if token.row_abs { "$" } else { "" }
  col_prefix + @cell.column_label(col) + row_prefix + (row + 1).to_string()
}

///|
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let builder = StringBuilder()
  for ch in chars {
    builder.write_char(ch)
  }
  builder.to_string()
}

///|
fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn Sheet::data_edge_position(
  self : Sheet,
  row : Int,
  col : Int,
  drow : Int,
  dcol : Int,
) -> Selection {
  let row_dir = sign_int(drow)
  let col_dir = sign_int(dcol)
  if (row_dir == 0 && col_dir == 0) || (row_dir != 0 && col_dir != 0) {
    Selection::new(
      row=clamp_int(row, 0, self.row_count - 1),
      col=clamp_int(col, 0, self.col_count - 1),
    )
  } else {
    let start_row = clamp_int(row, 0, self.row_count - 1)
    let start_col = clamp_int(col, 0, self.col_count - 1)
    let current_empty = self.get_cell(start_row, start_col).is_empty()
    let next_row = start_row + row_dir
    let next_col = start_col + col_dir
    if !self.in_bounds(next_row, next_col) {
      Selection::new(row=start_row, col=start_col)
    } else if current_empty {
      self.first_non_empty_or_boundary(next_row, next_col, row_dir, col_dir)
    } else if self.get_cell(next_row, next_col).is_empty() {
      self.first_non_empty_or_boundary(next_row, next_col, row_dir, col_dir)
    } else {
      self.last_contiguous_non_empty(next_row, next_col, row_dir, col_dir)
    }
  }
}

///|
fn Sheet::first_non_empty_or_boundary(
  self : Sheet,
  row : Int,
  col : Int,
  row_dir : Int,
  col_dir : Int,
) -> Selection {
  let mut edge_row = row
  let mut edge_col = col
  let mut probe_row = row
  let mut probe_col = col
  while self.in_bounds(probe_row, probe_col) &&
        self.get_cell(probe_row, probe_col).is_empty() {
    edge_row = probe_row
    edge_col = probe_col
    probe_row = probe_row + row_dir
    probe_col = probe_col + col_dir
  }
  if self.in_bounds(probe_row, probe_col) {
    Selection::new(row=probe_row, col=probe_col)
  } else {
    Selection::new(row=edge_row, col=edge_col)
  }
}

///|
fn Sheet::last_contiguous_non_empty(
  self : Sheet,
  row : Int,
  col : Int,
  row_dir : Int,
  col_dir : Int,
) -> Selection {
  let mut edge_row = row
  let mut edge_col = col
  let mut probe_row = row + row_dir
  let mut probe_col = col + col_dir
  while self.in_bounds(probe_row, probe_col) &&
        !self.get_cell(probe_row, probe_col).is_empty() {
    edge_row = probe_row
    edge_col = probe_col
    probe_row = probe_row + row_dir
    probe_col = probe_col + col_dir
  }
  Selection::new(row=edge_row, col=edge_col)
}

///|
fn Sheet::in_bounds(self : Sheet, row : Int, col : Int) -> Bool {
  row >= 0 && row < self.row_count && col >= 0 && col < self.col_count
}

///|
fn sign_int(value : Int) -> Int {
  if value < 0 {
    -1
  } else if value > 0 {
    1
  } else {
    0
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
