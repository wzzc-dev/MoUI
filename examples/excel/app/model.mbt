///|
using @moui {type Effect}

///|
pub(all) struct ExcelApp {
  model : ExcelModel
}

///|
pub(all) struct ExcelModel {
  workbook : @sheet.Workbook
  editing : Bool
  edit_value : String
  edit_original_value : String
  edit_undo_depth : Int
  edit_redo_stack : Array[@sheet.UndoOp]
  file_name : String
  status : String
  file_status : ExcelFileStatus
  context_menu_visible : Bool
  cell_ref_input : String
  heat_map : Bool
  autocomplete_suggestions : Array[String]
  autocomplete_index : Int
  last_clipboard_text : String
  last_clipboard_from_app : Bool
}

///|
pub(all) enum ExcelMsg {
  SheetSelected(Int)
  CellSelected(Int, Int)
  RowSelected(Int)
  ColumnSelected(Int)
  SelectAllCells
  CellEditStarted
  CellRefChanged(String)
  CellValueChanged(String)
  CellRawChanged(Int, Int, String)
  CellEditCommitted
  CellEditCommittedAndNavigate(Int, Int)
  CellEditCancelled
  NewWorkbook
  LoadDemo
  FileOpenRequested
  FileSaveRequested
  ServiceCompleted(ExcelServiceCompletion)
  CellNavigate(Int, Int)
  CellNavigateTo(Int, Int)
  CellNavigateDataEdge(Int, Int)
  SelectionNavigate(Int, Int)
  SelectionNavigateTo(Int, Int)
  SelectionNavigateDataEdge(Int, Int)
  CopyCells
  CutCells
  PasteCells
  FillDown
  FillRight
  SortAscending
  SortDescending
  DeleteSelectedCells
  Undo
  Redo
  ToggleContextMenu
  HideContextMenu
  ContextMenuAction(ContextMenuAction)
  GoToCell(String)
  ToggleBold
  ToggleItalic
  ToggleUnderline
  SetCellAlign(@cell.CellAlign)
  ToggleHeatMap
  SetCellBgColor(String)
  SetCellFormat(@cell.NumFormat)
  ClearCell
  AddSheet
  DeleteSheet(Int)
  AutocompleteSelect(Int)
  AutocompleteNext
  AutocompletePrev
  HideAutocomplete
}

///|
pub(all) enum ExcelFileStatus {
  Idle
  Running(String)
}

///|
pub enum ExcelServiceCompletion {
  FileOpenPicked(@services.ServiceTaskResult[String])
  FileRead(String, @services.ServiceTaskResult[Bytes])
  FileSavePicked(@services.ServiceTaskResult[String])
  FileWritten(String, @services.ServiceTaskResult[Unit])
  ClipboardWritten(String, @services.ServiceTaskResult[Unit])
  ClipboardRead(@services.ServiceTaskResult[String])
}

///|
pub(all) enum ContextMenuAction {
  Cut
  Copy
  Paste
  Delete
  InsertRowAbove
  InsertRowBelow
  DeleteRow
  InsertColumnLeft
  InsertColumnRight
  DeleteColumn
  ClearContents
  SortAscending
  SortDescending
}

///|
pub let row_header_width : Double = 48.0

///|
pub let col_header_height : Double = 28.0

///|
pub let cell_width : Double = 104.0

///|
pub let cell_height : Double = 32.0

///|
pub let grid_width : Double = 1080.0

///|
pub let grid_height : Double = 520.0

///|
pub let shell_width : Double = 1100.0

///|
pub let shell_height : Double = 760.0

///|
pub let cell_gap : Double = 1.0

///|
pub fn ExcelApp::new() -> ExcelApp {
  { model: ExcelModel::new() }
}

///|
pub fn ExcelApp::with_model(self : ExcelApp, model : ExcelModel) -> ExcelApp {
  ignore(self)
  { model, }
}

///|
pub fn ExcelModel::new() -> ExcelModel {
  ExcelModel::from_workbook(
    @excel_xlsx.new_workbook(),
    file_name="Untitled.xlsx",
    status="Ready",
  )
}

///|
pub fn ExcelModel::with_demo_data() -> ExcelModel {
  ExcelModel::from_workbook(
    @excel_xlsx.demo_workbook(),
    file_name="Demo.xlsx",
    status="Demo data loaded",
  )
}

///|
pub fn ExcelModel::from_workbook(
  workbook : @sheet.Workbook,
  file_name~ : String,
  status~ : String,
) -> ExcelModel {
  {
    workbook,
    editing: false,
    edit_value: "",
    edit_original_value: "",
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    file_name,
    status,
    file_status: ExcelFileStatus::Idle,
    context_menu_visible: false,
    cell_ref_input: "",
    heat_map: false,
    autocomplete_suggestions: [],
    autocomplete_index: 0,
    last_clipboard_text: "",
    last_clipboard_from_app: false,
  }
}

///|
pub fn ExcelModel::active_sheet(self : ExcelModel) -> @sheet.Sheet {
  self.workbook.active()
}

///|
pub fn ExcelModel::selected_cell(self : ExcelModel) -> @cell.Cell {
  self.workbook.selected_cell()
}

///|
pub fn ExcelModel::selected_format(self : ExcelModel) -> @cell.CellFormat {
  self.selected_cell().format
}

///|
pub fn ExcelModel::selected_ref(self : ExcelModel) -> String {
  self.workbook.selected_ref()
}

///|
pub fn ExcelModel::sheet_names(self : ExcelModel) -> Array[String] {
  self.workbook.sheet_names()
}

///|
pub fn ExcelModel::select_cell(
  self : ExcelModel,
  row : Int,
  col : Int,
) -> ExcelModel {
  let workbook = self.workbook.select_cell(row, col)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::select_row(self : ExcelModel, row : Int) -> ExcelModel {
  let sheet = self.active_sheet()
  let workbook = self.workbook.select_range(row, 0, row, sheet.col_count - 1)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::select_column(self : ExcelModel, col : Int) -> ExcelModel {
  let sheet = self.active_sheet()
  let workbook = self.workbook.select_range(0, col, sheet.row_count - 1, col)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::select_all_cells(self : ExcelModel) -> ExcelModel {
  let sheet = self.active_sheet()
  let workbook = self.workbook.select_range(
    0,
    0,
    sheet.row_count - 1,
    sheet.col_count - 1,
  )
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::switch_sheet(self : ExcelModel, index : Int) -> ExcelModel {
  let workbook = self.workbook.switch_sheet(index)
  {
    ..self,
    workbook,
    editing: false,
    edit_value: "",
    edit_original_value: "",
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: "",
    context_menu_visible: false,
    status: "Switched to " + workbook.active().name,
  }
}

///|
pub fn ExcelModel::start_editing(self : ExcelModel) -> ExcelModel {
  match self.workbook.selection {
    None => self
    Some(_) =>
      {
        ..self,
        editing: true,
        edit_value: self.selected_cell().raw,
        edit_original_value: self.selected_cell().raw,
        edit_undo_depth: self.workbook.undo_stack.length(),
        edit_redo_stack: self.workbook.redo_stack.copy(),
        status: "Editing...",
      }
  }
}

///|
pub fn ExcelModel::commit_edit(self : ExcelModel) -> ExcelModel {
  match self.workbook.selection {
    None => self
    Some(_) => {
      let workbook = self.workbook.set_selected_raw(self.edit_value)
      let selected = workbook.selected_cell()
      {
        ..self,
        workbook,
        editing: false,
        edit_original_value: selected.raw,
        edit_undo_depth: workbook.undo_stack.length(),
        edit_redo_stack: workbook.redo_stack.copy(),
        status: "Committed " + workbook.selected_ref(),
      }
    }
  }
}

///|
pub fn ExcelModel::commit_edit_and_navigate(
  self : ExcelModel,
  drow : Int,
  dcol : Int,
) -> ExcelModel {
  self.commit_edit().navigate(drow, dcol)
}

///|
pub fn ExcelModel::set_cell_raw(
  self : ExcelModel,
  row : Int,
  col : Int,
  value : String,
) -> ExcelModel {
  let selected_workbook = self.workbook.select_cell(row, col)
  let continuing_edit = self.editing &&
    (match self.workbook.selection {
      Some(sel) => sel.row == row && sel.col == col
      None => false
    })
  let edit_original_value = if continuing_edit {
    self.edit_original_value
  } else {
    selected_workbook.selected_cell().raw
  }
  let edit_undo_depth = if continuing_edit {
    self.edit_undo_depth
  } else {
    selected_workbook.undo_stack.length()
  }
  let edit_redo_stack = if continuing_edit {
    self.edit_redo_stack.copy()
  } else {
    selected_workbook.redo_stack.copy()
  }
  let workbook = selected_workbook.set_selected_raw(value)
  {
    ..self.update_autocomplete(value),
    workbook,
    editing: true,
    edit_value: value,
    edit_original_value,
    edit_undo_depth,
    edit_redo_stack,
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    status: "Editing " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::set_formula_bar_value(
  self : ExcelModel,
  value : String,
) -> ExcelModel {
  match self.workbook.selection {
    None =>
      { ..self.update_autocomplete(value), edit_value: value, editing: false }
    Some(sel) => self.set_cell_raw(sel.row, sel.col, value)
  }
}

///|
pub fn ExcelModel::cancel_edit(self : ExcelModel) -> ExcelModel {
  match (self.editing, self.workbook.selection) {
    (true, Some(sel)) => {
      let restored_sheet = self.workbook
        .active()
        .set_raw_no_undo(sel.row, sel.col, self.edit_original_value)
        .recalc()
      let undo_stack = self.workbook.undo_stack.copy()
      undo_stack.truncate(self.edit_undo_depth)
      let redo_stack = self.edit_redo_stack.copy()
      let workbook = {
        ..self.workbook.with_active_sheet(restored_sheet),
        undo_stack,
        redo_stack,
      }
      let selected = workbook.selected_cell()
      {
        ..self,
        workbook,
        editing: false,
        edit_value: selected.raw,
        edit_original_value: selected.raw,
        edit_undo_depth: workbook.undo_stack.length(),
        edit_redo_stack: workbook.redo_stack.copy(),
        autocomplete_suggestions: [],
        autocomplete_index: 0,
        status: "Edit cancelled",
      }
    }
    _ =>
      {
        ..self,
        editing: false,
        edit_value: self.selected_cell().raw,
        edit_original_value: self.selected_cell().raw,
        edit_undo_depth: self.workbook.undo_stack.length(),
        edit_redo_stack: self.workbook.redo_stack.copy(),
        autocomplete_suggestions: [],
        autocomplete_index: 0,
        status: "Edit cancelled",
      }
  }
}

///|
pub fn ExcelModel::navigate(
  self : ExcelModel,
  drow : Int,
  dcol : Int,
) -> ExcelModel {
  let workbook = self.workbook.navigate(drow, dcol)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    autocomplete_suggestions: [],
    autocomplete_index: 0,
  }
}

///|
pub fn ExcelModel::navigate_to_data_edge(
  self : ExcelModel,
  drow : Int,
  dcol : Int,
) -> ExcelModel {
  let workbook = self.workbook.navigate_to_data_edge(drow, dcol)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    autocomplete_suggestions: [],
    autocomplete_index: 0,
  }
}

///|
pub fn ExcelModel::extend_selection(
  self : ExcelModel,
  drow : Int,
  dcol : Int,
) -> ExcelModel {
  let workbook = self.workbook.extend_selection(drow, dcol)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    autocomplete_suggestions: [],
    autocomplete_index: 0,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::extend_selection_to(
  self : ExcelModel,
  row : Int,
  col : Int,
) -> ExcelModel {
  let workbook = self.workbook.extend_selection_to(row, col)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    autocomplete_suggestions: [],
    autocomplete_index: 0,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::extend_selection_to_data_edge(
  self : ExcelModel,
  drow : Int,
  dcol : Int,
) -> ExcelModel {
  let workbook = self.workbook.extend_selection_to_data_edge(drow, dcol)
  let selected = workbook.selected_cell()
  {
    ..self,
    workbook,
    editing: false,
    edit_value: selected.raw,
    edit_original_value: selected.raw,
    edit_undo_depth: workbook.undo_stack.length(),
    edit_redo_stack: workbook.redo_stack.copy(),
    cell_ref_input: workbook.selected_ref(),
    autocomplete_suggestions: [],
    autocomplete_index: 0,
    status: "Selected " + workbook.selected_ref(),
  }
}

///|
pub fn ExcelModel::go_to_cell(
  self : ExcelModel,
  ref_str : String,
) -> ExcelModel {
  let target = ref_str.trim().to_owned()
  match @cell.parse_range(target) {
    Some(range) => {
      let workbook = self.workbook.select_range(
        range.start.row,
        range.start.col,
        range.end.row,
        range.end.col,
      )
      let selected = workbook.selected_cell()
      {
        ..self,
        workbook,
        editing: false,
        edit_value: selected.raw,
        edit_original_value: selected.raw,
        edit_undo_depth: workbook.undo_stack.length(),
        edit_redo_stack: workbook.redo_stack.copy(),
        cell_ref_input: workbook.selected_ref(),
        context_menu_visible: false,
        autocomplete_suggestions: [],
        autocomplete_index: 0,
        status: "Selected " + workbook.selected_ref(),
      }
    }
    None =>
      match @cell.parse_ref(target) {
        Some(addr) => self.select_cell(addr.row, addr.col)
        None => { ..self, status: "Invalid cell reference: " + ref_str }
      }
  }
}

///|
pub fn ExcelModel::update_edit_value(
  self : ExcelModel,
  value : String,
) -> ExcelModel {
  { ..self.update_autocomplete(value), edit_value: value }
}

///|
pub fn ExcelModel::update_autocomplete(
  self : ExcelModel,
  input : String,
) -> ExcelModel {
  let suggestions : Array[String] = []
  if input.length() > 1 && input[0] == '=' {
    let prefix = input[1:].to_owned().to_upper()
    for candidate in formula_functions() {
      if starts_with(candidate, prefix) {
        suggestions.push(candidate)
      }
    }
  }
  { ..self, autocomplete_suggestions: suggestions, autocomplete_index: 0 }
}

///|
pub fn ExcelModel::select_autocomplete(
  self : ExcelModel,
  index : Int,
) -> ExcelModel {
  if index >= 0 && index < self.autocomplete_suggestions.length() {
    let value = "=" + self.autocomplete_suggestions[index] + "("
    match self.workbook.selection {
      Some(sel) =>
        {
          ..self.set_cell_raw(sel.row, sel.col, value),
          autocomplete_suggestions: [],
          autocomplete_index: 0,
        }
      None =>
        {
          ..self,
          edit_value: value,
          autocomplete_suggestions: [],
          autocomplete_index: 0,
        }
    }
  } else {
    self
  }
}

///|
pub fn ExcelModel::next_autocomplete(self : ExcelModel) -> ExcelModel {
  if self.autocomplete_suggestions.is_empty() {
    self
  } else {
    let next = self.autocomplete_index + 1
    {
      ..self,
      autocomplete_index: if next >= self.autocomplete_suggestions.length() {
        0
      } else {
        next
      },
    }
  }
}

///|
pub fn ExcelModel::prev_autocomplete(self : ExcelModel) -> ExcelModel {
  if self.autocomplete_suggestions.is_empty() {
    self
  } else {
    let next = self.autocomplete_index - 1
    {
      ..self,
      autocomplete_index: if next < 0 {
        self.autocomplete_suggestions.length() - 1
      } else {
        next
      },
    }
  }
}

///|
pub fn ExcelModel::toggle_format(
  self : ExcelModel,
  updater : (@cell.CellFormat) -> @cell.CellFormat,
  status : String,
) -> ExcelModel {
  let workbook = self.workbook.set_selected_format(updater)
  { ..self, workbook, status }
}

///|
pub fn ExcelModel::handle_context_menu(
  self : ExcelModel,
  action : ContextMenuAction,
) -> ExcelModel {
  match action {
    ContextMenuAction::Cut =>
      {
        ..self,
        workbook: self.workbook.cut_selected(),
        context_menu_visible: false,
        status: "Cut",
      }
    ContextMenuAction::Copy =>
      {
        ..self,
        workbook: self.workbook.copy_selected(),
        context_menu_visible: false,
        status: "Copied",
      }
    ContextMenuAction::Paste =>
      {
        ..self,
        workbook: self.workbook.paste_selected(),
        context_menu_visible: false,
        status: "Pasted",
      }
    ContextMenuAction::Delete | ContextMenuAction::ClearContents =>
      {
        ..self,
        workbook: self.workbook.clear_selected(),
        context_menu_visible: false,
        status: "Cleared",
      }
    ContextMenuAction::InsertRowAbove => {
      let row = match self.workbook.selection {
        Some(sel) => sel.row
        None => 0
      }
      {
        ..self,
        workbook: self.workbook.insert_row(row),
        context_menu_visible: false,
        status: "Inserted row",
      }
    }
    ContextMenuAction::InsertRowBelow => {
      let row = match self.workbook.selection {
        Some(sel) => sel.row + 1
        None => 0
      }
      {
        ..self,
        workbook: self.workbook.insert_row(row),
        context_menu_visible: false,
        status: "Inserted row",
      }
    }
    ContextMenuAction::DeleteRow => {
      let row = match self.workbook.selection {
        Some(sel) => sel.row
        None => 0
      }
      {
        ..self,
        workbook: self.workbook.delete_row(row),
        context_menu_visible: false,
        status: "Deleted row",
      }
    }
    ContextMenuAction::InsertColumnLeft => {
      let col = match self.workbook.selection {
        Some(sel) => sel.col
        None => 0
      }
      {
        ..self,
        workbook: self.workbook.insert_column(col),
        context_menu_visible: false,
        status: "Inserted column",
      }
    }
    ContextMenuAction::InsertColumnRight => {
      let col = match self.workbook.selection {
        Some(sel) => sel.col + 1
        None => 0
      }
      {
        ..self,
        workbook: self.workbook.insert_column(col),
        context_menu_visible: false,
        status: "Inserted column",
      }
    }
    ContextMenuAction::DeleteColumn => {
      let col = match self.workbook.selection {
        Some(sel) => sel.col
        None => 0
      }
      {
        ..self,
        workbook: self.workbook.delete_column(col),
        context_menu_visible: false,
        status: "Deleted column",
      }
    }
    ContextMenuAction::SortAscending =>
      {
        ..self,
        workbook: self.workbook.sort_selected_by_first_column(ascending=true),
        context_menu_visible: false,
        status: "Sorted A to Z",
      }
    ContextMenuAction::SortDescending =>
      {
        ..self,
        workbook: self.workbook.sort_selected_by_first_column(ascending=false),
        context_menu_visible: false,
        status: "Sorted Z to A",
      }
  }
}

///|
fn formula_functions() -> Array[String] {
  [
    "SUM", "AVG", "AVERAGE", "MIN", "MAX", "COUNT", "PRODUCT", "MEDIAN", "IF", "AND",
    "OR", "NOT", "ROUND", "ABS", "SQRT", "POW", "LEN",
  ]
}

///|
fn starts_with(value : String, prefix : String) -> Bool {
  if prefix.length() > value.length() {
    false
  } else {
    value[:prefix.length()].to_owned() == prefix
  }
}
