///|
using @moui {type Effect}

///|
pub(all) struct ExcelApp {
  services : @host.HostAppServices
  model : @state.State[ExcelModel]
}

///|
pub(all) struct ExcelModel {
  workbook : @sheet.Workbook
  editing : Bool
  edit_value : String
  file_name : String
  status : String
  file_status : ExcelFileStatus
  context_menu_visible : Bool
  pending_file_path : String
  cell_ref_input : String
  heat_map : Bool
  autocomplete_suggestions : Array[String]
  autocomplete_index : Int
}

///|
pub(all) enum ExcelMsg {
  SheetSelected(Int)
  CellSelected(Int, Int)
  CellEditStarted
  CellRefChanged(String)
  CellValueChanged(String)
  CellRawChanged(Int, Int, String)
  CellEditCommitted
  CellEditCancelled
  NewWorkbook
  LoadDemo
  FileOpenRequested
  FileSaveRequested
  HostCompleted(@host.HostCompletedServiceResponse)
  CellNavigate(Int, Int)
  CopyCells
  CutCells
  PasteCells
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
  Pending(@host.HostServiceRequestId)
}

///|
pub(all) enum ContextMenuAction {
  Cut
  Copy
  Paste
  Delete
  InsertRowAbove
  InsertRowBelow
  InsertColumnLeft
  InsertColumnRight
  ClearContents
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
pub fn ExcelApp::new(services : @host.HostAppServices) -> ExcelApp {
  { services, model: @state.State::new(ExcelModel::new()) }
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
    file_name,
    status,
    file_status: ExcelFileStatus::Idle,
    context_menu_visible: false,
    pending_file_path: "",
    cell_ref_input: "",
    heat_map: false,
    autocomplete_suggestions: [],
    autocomplete_index: 0,
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
      {
        ..self,
        workbook,
        editing: false,
        status: "Committed " + workbook.selected_ref(),
      }
    }
  }
}

///|
pub fn ExcelModel::set_cell_raw(
  self : ExcelModel,
  row : Int,
  col : Int,
  value : String,
) -> ExcelModel {
  let workbook = self.workbook.select_cell(row, col).set_selected_raw(value)
  {
    ..self.update_autocomplete(value),
    workbook,
    editing: true,
    edit_value: value,
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
  {
    ..self,
    editing: false,
    edit_value: self.selected_cell().raw,
    autocomplete_suggestions: [],
    autocomplete_index: 0,
    status: "Edit cancelled",
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
    cell_ref_input: workbook.selected_ref(),
    autocomplete_suggestions: [],
    autocomplete_index: 0,
  }
}

///|
pub fn ExcelModel::go_to_cell(
  self : ExcelModel,
  ref_str : String,
) -> ExcelModel {
  match @cell.parse_ref(ref_str) {
    Some(addr) => self.select_cell(addr.row, addr.col)
    None => { ..self, status: "Invalid cell reference: " + ref_str }
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
    {
      ..self,
      edit_value: "=" + self.autocomplete_suggestions[index] + "(",
      autocomplete_suggestions: [],
      autocomplete_index: 0,
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
  }
}

///|
fn formula_functions() -> Array[String] {
  [
    "SUM", "AVG", "AVERAGE", "MIN", "MAX", "COUNT", "IF", "ROUND", "ABS", "SQRT",
    "POW", "LEN",
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
