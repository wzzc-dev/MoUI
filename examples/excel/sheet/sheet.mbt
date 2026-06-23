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
pub(all) enum UndoOp {
  CellEdit(Int, Int, @cell.Cell, @cell.Cell)
  CellFormat(Int, Int, @cell.CellFormat, @cell.CellFormat)
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
  match self.selection {
    Some(sel) => sel.key()
    None => ""
  }
}

///|
pub fn Workbook::select_cell(self : Workbook, row : Int, col : Int) -> Workbook {
  let sheet = self.active()
  let next = Selection::new(
    row=clamp_int(row, 0, sheet.row_count - 1),
    col=clamp_int(col, 0, sheet.col_count - 1),
  )
  { ..self, selection: Some(next) }
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
  match self.selection {
    None => self
    Some(sel) => self.set_format(sel.row, sel.col, updater)
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
  self.set_selected_raw("")
}

///|
pub fn Workbook::copy_selected(self : Workbook) -> Workbook {
  match self.selection {
    None => self
    Some(sel) => {
      let cell = self.active().get_cell(sel.row, sel.col)
      { ..self, clipboard: { cells: [[cell]], origin: sel } }
    }
  }
}

///|
pub fn Workbook::cut_selected(self : Workbook) -> Workbook {
  self.copy_selected().clear_selected()
}

///|
pub fn Workbook::paste_selected(self : Workbook) -> Workbook {
  match self.selection {
    None => self
    Some(sel) =>
      if self.clipboard.cells.length() == 1 &&
        self.clipboard.cells[0].length() == 1 {
        let cell = self.clipboard.cells[0][0]
        let sheet = self.active()
        let old_cell = sheet.get_cell(sel.row, sel.col)
        let updated_sheet = sheet
          .set_cell_no_undo(sel.row, sel.col, cell)
          .recalc()
        let next = self.with_active_sheet(updated_sheet)
        if old_cell == cell {
          next
        } else {
          next.push_undo(UndoOp::CellEdit(sel.row, sel.col, old_cell, cell))
        }
      } else {
        self
      }
  }
}

///|
pub fn Workbook::insert_row(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  let idx = clamp_int(index, 0, sheet.row_count)
  self.with_active_sheet(shift_sheet_rows(sheet, idx, 1))
}

///|
pub fn Workbook::delete_row(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  if index < 0 || index >= sheet.row_count {
    self
  } else {
    self.with_active_sheet(shift_sheet_rows(sheet, index, -1))
  }
}

///|
pub fn Workbook::insert_column(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  let idx = clamp_int(index, 0, sheet.col_count)
  self.with_active_sheet(shift_sheet_cols(sheet, idx, 1))
}

///|
pub fn Workbook::delete_column(self : Workbook, index : Int) -> Workbook {
  let sheet = self.active()
  if index < 0 || index >= sheet.col_count {
    self
  } else {
    self.with_active_sheet(shift_sheet_cols(sheet, index, -1))
  }
}

///|
pub fn Workbook::add_sheet(self : Workbook) -> Workbook {
  let sheets = self.sheets.copy()
  let name = "Sheet " + (sheets.length() + 1).to_string()
  sheets.push(Sheet::new(name))
  {
    ..self,
    sheets,
    active_sheet: sheets.length() - 1,
    selection: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
pub fn Workbook::delete_sheet(self : Workbook, index : Int) -> Workbook {
  if self.sheets.length() <= 1 || index < 0 || index >= self.sheets.length() {
    self
  } else {
    let sheets = self.sheets.copy()
    ignore(sheets.remove(index))
    let active_sheet = clamp_int(self.active_sheet, 0, sheets.length() - 1)
    {
      ..self,
      sheets,
      active_sheet,
      selection: None,
      undo_stack: [],
      redo_stack: [],
    }
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
        UndoOp::CellFormat(row, col, old_format, _new_format) =>
          self.with_active_sheet(
            self.active().set_format_no_undo(row, col, old_format),
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
        UndoOp::CellFormat(row, col, _old_format, new_format) =>
          self.with_active_sheet(
            self.active().set_format_no_undo(row, col, new_format),
          )
      }
      { ..result, undo_stack, redo_stack }
    }
  }
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
          cells[@cell.make_key(row, addr.col)] = cell
        } else if addr.row == index {
          ()
        } else {
          let row = if addr.row > index { addr.row - 1 } else { addr.row }
          cells[@cell.make_key(row, addr.col)] = cell
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
fn shift_sheet_cols(sheet : Sheet, index : Int, delta : Int) -> Sheet {
  let cells : Map[String, @cell.Cell] = Map([])
  for key, cell in sheet.cells {
    match @cell.parse_ref(key) {
      Some(addr) =>
        if delta > 0 {
          let col = if addr.col >= index { addr.col + 1 } else { addr.col }
          cells[@cell.make_key(addr.row, col)] = cell
        } else if addr.col == index {
          ()
        } else {
          let col = if addr.col > index { addr.col - 1 } else { addr.col }
          cells[@cell.make_key(addr.row, col)] = cell
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
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
