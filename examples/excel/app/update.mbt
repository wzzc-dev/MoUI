///|
pub fn update(model : ExcelModel, msg : ExcelMsg) -> ExcelModel {
  match msg {
    SheetSelected(index) => model.switch_sheet(index)
    CellSelected(row, col) => model.select_cell(row, col)
    RowSelected(row) => model.select_row(row)
    ColumnSelected(col) => model.select_column(col)
    SelectAllCells => model.select_all_cells()
    CellEditStarted => model.start_editing()
    CellRefChanged(value) => { ..model, cell_ref_input: value }
    CellValueChanged(value) => model.set_formula_bar_value(value)
    CellRawChanged(row, col, value) => model.set_cell_raw(row, col, value)
    CellEditCommitted =>
      {
        ..model.commit_edit(),
        autocomplete_suggestions: [],
        autocomplete_index: 0,
      }
    CellEditCommittedAndNavigate(drow, dcol) =>
      {
        ..model.commit_edit_and_navigate(drow, dcol),
        autocomplete_suggestions: [],
        autocomplete_index: 0,
      }
    CellEditCancelled => model.cancel_edit()
    NewWorkbook => ExcelModel::new()
    LoadDemo => ExcelModel::with_demo_data()
    CellNavigate(drow, dcol) => model.navigate(drow, dcol)
    CellNavigateTo(row, col) => model.select_cell(row, col)
    CellNavigateDataEdge(drow, dcol) => model.navigate_to_data_edge(drow, dcol)
    SelectionNavigate(drow, dcol) => model.extend_selection(drow, dcol)
    SelectionNavigateTo(row, col) => model.extend_selection_to(row, col)
    SelectionNavigateDataEdge(drow, dcol) =>
      model.extend_selection_to_data_edge(drow, dcol)
    CopyCells =>
      { ..model, workbook: model.workbook.copy_selected(), status: "Copied" }
    CutCells =>
      { ..model, workbook: model.workbook.cut_selected(), status: "Cut" }
    PasteCells => {
      let workbook = model.workbook.paste_selected()
      {
        ..model,
        workbook,
        cell_ref_input: workbook.selected_ref(),
        status: "Pasted",
      }
    }
    FillDown =>
      {
        ..model,
        workbook: model.workbook.fill_down_selected(),
        status: "Fill down",
      }
    FillRight =>
      {
        ..model,
        workbook: model.workbook.fill_right_selected(),
        status: "Fill right",
      }
    SortAscending =>
      {
        ..model,
        workbook: model.workbook.sort_selected_by_first_column(ascending=true),
        status: "Sorted A to Z",
      }
    SortDescending =>
      {
        ..model,
        workbook: model.workbook.sort_selected_by_first_column(ascending=false),
        status: "Sorted Z to A",
      }
    DeleteSelectedCells =>
      { ..model, workbook: model.workbook.clear_selected(), status: "Deleted" }
    Undo => { ..model, workbook: model.workbook.undo(), status: "Undo" }
    Redo => { ..model, workbook: model.workbook.redo(), status: "Redo" }
    ToggleContextMenu =>
      { ..model, context_menu_visible: !model.context_menu_visible }
    HideContextMenu => { ..model, context_menu_visible: false }
    ContextMenuAction(action) => model.handle_context_menu(action)
    GoToCell(ref_str) => model.go_to_cell(ref_str)
    ToggleBold => model.toggle_format(fmt => { ..fmt, bold: !fmt.bold }, "Bold")
    ToggleItalic =>
      model.toggle_format(fmt => { ..fmt, italic: !fmt.italic }, "Italic")
    ToggleUnderline =>
      model.toggle_format(
        fmt => { ..fmt, underline: !fmt.underline },
        "Underline",
      )
    SetCellAlign(align) =>
      model.toggle_format(fmt => { ..fmt, align, }, "Aligned")
    ToggleHeatMap => { ..model, heat_map: !model.heat_map }
    SetCellBgColor(color) =>
      model.toggle_format(fmt => { ..fmt, bg_color: color }, "Cell color")
    SetCellFormat(format) =>
      model.toggle_format(fmt => { ..fmt, num_format: format }, "Number format")
    ClearCell =>
      { ..model, workbook: model.workbook.clear_selected(), status: "Cleared" }
    AddSheet =>
      { ..model, workbook: model.workbook.add_sheet(), status: "Added sheet" }
    DeleteSheet(index) =>
      {
        ..model,
        workbook: model.workbook.delete_sheet(index),
        status: "Deleted sheet",
      }
    AutocompleteSelect(index) => model.select_autocomplete(index)
    AutocompleteNext => model.next_autocomplete()
    AutocompletePrev => model.prev_autocomplete()
    HideAutocomplete =>
      { ..model, autocomplete_suggestions: [], autocomplete_index: 0 }
    FileOpenRequested | FileSaveRequested | ServiceCompleted(_) => model
  }
}

///|
pub fn ExcelApp::update(
  self : ExcelApp,
  msg : ExcelMsg,
) -> (ExcelApp, Effect[ExcelMsg]) {
  self.update_with_services(msg, @services.AppServices::unavailable())
}

///|
pub fn ExcelApp::update_with_services(
  self : ExcelApp,
  msg : ExcelMsg,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  match msg {
    FileOpenRequested => self.handle_file_open(services)
    FileSaveRequested => self.handle_file_save(services)
    ServiceCompleted(completion) =>
      self.apply_service_completion(completion, services)
    CopyCells => self.copy_cells_to_clipboard(services)
    CutCells => self.cut_cells_to_clipboard(services)
    PasteCells => self.paste_cells_from_clipboard(services)
    ContextMenuAction(ContextMenuAction::Copy) =>
      self.copy_cells_to_clipboard(services)
    ContextMenuAction(ContextMenuAction::Cut) =>
      self.cut_cells_to_clipboard(services)
    ContextMenuAction(ContextMenuAction::Paste) =>
      self.paste_cells_from_clipboard(services)
    _ => (self.with_model(update(self.model, msg)), Effect::none())
  }
}

///|
pub fn ExcelApp::handle_file_open(
  self : ExcelApp,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let next = self.set_running("Waiting for file picker...")
  (
    next,
    services
    .files()
    .open_file(
      options=@services.FileDialogOptions::new(title="Open Excel File", filters=[
        "xlsx",
      ]),
    )
    .effect(map=result => ServiceCompleted(FileOpenPicked(result))),
  )
}

///|
pub fn ExcelApp::read_file(
  self : ExcelApp,
  path : String,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let next = self.set_running("Reading " + path + "...")
  (
    next,
    services
    .files()
    .read_bytes(path)
    .effect(map=result => ServiceCompleted(FileRead(path, result))),
  )
}

///|
pub fn ExcelApp::load_workbook_bytes(
  self : ExcelApp,
  path : String,
  bytes : Bytes,
) -> (ExcelApp, Effect[ExcelMsg]) {
  match @excel_xlsx.load_workbook(bytes) {
    Ok(workbook) => {
      let model = ExcelModel::from_workbook(
        workbook,
        file_name=display_file_name(path),
        status="Loaded " + path,
      )
      (self.with_model(model), Effect::none())
    }
    Err(message) => self.set_status(message)
  }
}

///|
pub fn ExcelApp::handle_file_save(
  self : ExcelApp,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  let default_name = if current.file_name == "Untitled.xlsx" {
    "output.xlsx"
  } else {
    current.file_name
  }
  let next = self.set_running("Saving...")
  (
    next,
    services
    .files()
    .save_file(
      options=@services.FileDialogOptions::new(
        title="Save Excel File",
        default_name=Some(default_name),
        filters=["xlsx"],
      ),
    )
    .effect(map=result => ServiceCompleted(FileSavePicked(result))),
  )
}

///|
pub fn ExcelApp::write_file(
  self : ExcelApp,
  path : String,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  match @excel_xlsx.write_workbook(current.workbook, path) {
    Ok(bytes) => {
      let next = self.set_running("Writing " + path + "...")
      (
        next,
        services
        .files()
        .write_bytes(path, bytes)
        .effect(map=result => ServiceCompleted(FileWritten(path, result))),
      )
    }
    Err(message) => self.set_status(message)
  }
}

///|
fn ExcelApp::copy_cells_to_clipboard(
  self : ExcelApp,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  let workbook = current.workbook.copy_selected()
  self.write_cells_to_clipboard(workbook, services, status="Copied")
}

///|
fn ExcelApp::cut_cells_to_clipboard(
  self : ExcelApp,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  let workbook = current.workbook.cut_selected()
  self.write_cells_to_clipboard(workbook, services, status="Cut")
}

///|
fn ExcelApp::write_cells_to_clipboard(
  self : ExcelApp,
  workbook : @sheet.Workbook,
  services : @services.AppServices,
  status~ : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  if !workbook.has_clipboard() {
    return (
      self.with_model({
        ..current,
        workbook,
        context_menu_visible: false,
        last_clipboard_from_app: false,
        status: "Nothing to copy",
      }),
      Effect::none(),
    )
  }
  let text = workbook.clipboard_tsv()
  let next = self.with_model({
    ..current,
    workbook,
    context_menu_visible: false,
    last_clipboard_text: text,
    last_clipboard_from_app: true,
    status,
  })
  (
    next,
    services
    .clipboard()
    .write_text(text)
    .effect(map=result => ServiceCompleted(ClipboardWritten(status, result))),
  )
}

///|
fn ExcelApp::paste_cells_from_clipboard(
  self : ExcelApp,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let next = self.set_running("Reading clipboard...")
  (
    next,
    services
    .clipboard()
    .read_text()
    .effect(map=result => ServiceCompleted(ClipboardRead(result))),
  )
}

///|
fn ExcelApp::apply_clipboard_text(
  self : ExcelApp,
  text : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  let use_internal_clipboard = current.last_clipboard_from_app &&
    text == current.last_clipboard_text &&
    current.workbook.has_clipboard()
  let workbook = if use_internal_clipboard {
    current.workbook.paste_selected()
  } else {
    current.workbook.paste_tsv(text)
  }
  let next = self.with_model({
    ..current,
    workbook,
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    file_status: ExcelFileStatus::Idle,
    last_clipboard_text: text,
    last_clipboard_from_app: use_internal_clipboard,
    status: "Pasted",
  })
  (next, Effect::none())
}

///|
fn ExcelApp::paste_cells_locally(
  self : ExcelApp,
  reason : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model
  let status = if reason.is_empty() {
    "Pasted"
  } else {
    "Pasted locally; " + reason
  }
  let workbook = current.workbook.paste_selected()
  let next = self.with_model({
    ..current,
    workbook,
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    file_status: ExcelFileStatus::Idle,
    status,
  })
  (next, Effect::none())
}

///|
pub fn ExcelApp::apply_service_completion(
  self : ExcelApp,
  completion : ExcelServiceCompletion,
  services : @services.AppServices,
) -> (ExcelApp, Effect[ExcelMsg]) {
  match completion {
    FileOpenPicked(result) =>
      match result {
        Success(path) => self.read_file(path, services)
        Failure(error) =>
          self.set_status("File dialog unavailable: " + error.message)
        Cancelled => self.set_status("Cancelled")
      }
    FileRead(path, result) =>
      match result {
        Success(bytes) => self.load_workbook_bytes(path, bytes)
        Failure(error) => self.set_status("Cannot read file: " + error.message)
        Cancelled => self.set_status("Read cancelled")
      }
    FileSavePicked(result) =>
      match result {
        Success(path) => self.write_file(path, services)
        Failure(error) =>
          self.set_status("Save dialog unavailable: " + error.message)
        Cancelled => self.set_status("Cancelled")
      }
    FileWritten(path, result) =>
      match result {
        Success(_) => self.set_status("Saved " + path)
        Failure(error) => self.set_status("Cannot write file: " + error.message)
        Cancelled => self.set_status("Write cancelled")
      }
    ClipboardWritten(status, result) =>
      match result {
        Success(_) => self.set_status("Clipboard updated")
        Failure(error) => self.set_status(status + " locally; " + error.message)
        Cancelled => self.set_status(status + " locally; clipboard cancelled")
      }
    ClipboardRead(result) =>
      match result {
        Success(text) => self.apply_clipboard_text(text)
        Failure(error) => self.paste_cells_locally(error.message)
        Cancelled => self.paste_cells_locally("clipboard read cancelled")
      }
  }
}

///|
pub fn ExcelApp::set_status(
  self : ExcelApp,
  status : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  (
    self.with_model({ ..self.model, status, file_status: ExcelFileStatus::Idle }),
    Effect::none(),
  )
}

///|
pub fn ExcelApp::set_running(self : ExcelApp, status : String) -> ExcelApp {
  self.with_model({
    ..self.model,
    status,
    file_status: ExcelFileStatus::Running(status),
  })
}

///|
fn display_file_name(path : String) -> String {
  let chars = path.to_array()
  let mut start = 0
  for i, ch in chars {
    if ch == '/' || ch == '\\' {
      start = i + 1
    }
  }
  chars_to_string(chars[start:])
}

///|
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let builder = StringBuilder()
  for ch in chars {
    builder.write_char(ch)
  }
  builder.to_string()
}
