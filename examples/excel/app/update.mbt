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
    FileOpenRequested | FileSaveRequested | HostCompleted(_) => model
  }
}

///|
pub fn ExcelApp::update(
  self : ExcelApp,
  msg : ExcelMsg,
) -> (ExcelApp, Effect[ExcelMsg]) {
  match msg {
    FileOpenRequested => self.handle_file_open()
    FileSaveRequested => self.handle_file_save()
    HostCompleted(completion) => self.handle_host_completion(completion)
    CopyCells => self.copy_cells_to_clipboard()
    CutCells => self.cut_cells_to_clipboard()
    PasteCells => self.paste_cells_from_clipboard()
    ContextMenuAction(ContextMenuAction::Copy) => self.copy_cells_to_clipboard()
    ContextMenuAction(ContextMenuAction::Cut) => self.cut_cells_to_clipboard()
    ContextMenuAction(ContextMenuAction::Paste) =>
      self.paste_cells_from_clipboard()
    _ => {
      let new_model = update(self.model.get(), msg)
      self.model.set(new_model)
      (self, Effect::none())
    }
  }
}

///|
pub fn ExcelApp::handle_file_open(
  self : ExcelApp,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let options = @host.HostFileDialogOptions::new(
    kind=@host.HostFileDialogKind::OpenFile,
    title="Open Excel File",
    filters=["xlsx"],
  )
  let response = self.services.file_dialog(options)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      self.set_pending(id, "Waiting for file picker...", path="")
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      if paths.length() > 0 {
        self.read_file(paths[0])
      } else {
        self.set_status("Cancelled")
      }
    @host.HostServiceResponse::Unavailable(reason) =>
      self.set_status("File dialog unavailable: " + reason)
    _ => (self, Effect::none())
  }
}

///|
pub fn ExcelApp::read_file(
  self : ExcelApp,
  path : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let response = self.services.read_binary_file(path)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      self.set_pending(id, "Reading " + path + "...", path~)
    @host.HostServiceResponse::BinaryFileContent(_, bytes) =>
      self.load_workbook_bytes(path, bytes)
    @host.HostServiceResponse::Unavailable(reason) =>
      self.set_status("Cannot read file: " + reason)
    _ => (self, Effect::none())
  }
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
      self.model.set(model)
      (self, Effect::none())
    }
    Err(message) => self.set_status(message)
  }
}

///|
pub fn ExcelApp::handle_file_save(
  self : ExcelApp,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  let default_name = if current.file_name == "Untitled.xlsx" {
    "output.xlsx"
  } else {
    current.file_name
  }
  let response = self.services.save_file(
    title="Save Excel File",
    default_name=Some(default_name),
    filters=["xlsx"],
  )
  match response {
    @host.HostServiceResponse::Pending(id) =>
      self.set_pending(id, "Saving...", path="")
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      if paths.length() > 0 {
        self.write_file(paths[0])
      } else {
        self.set_status("Cancelled")
      }
    @host.HostServiceResponse::Unavailable(reason) =>
      self.set_status("Save dialog unavailable: " + reason)
    _ => (self, Effect::none())
  }
}

///|
pub fn ExcelApp::write_file(
  self : ExcelApp,
  path : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  match @excel_xlsx.write_workbook(current.workbook, path) {
    Ok(bytes) => {
      let response = self.services.write_binary_file(path, bytes)
      match response {
        @host.HostServiceResponse::Pending(id) =>
          self.set_pending(id, "Writing " + path + "...", path~)
        @host.HostServiceResponse::BinaryFileWritten(_) =>
          self.set_status("Saved " + path)
        @host.HostServiceResponse::Unavailable(reason) =>
          self.set_status("Cannot write file: " + reason)
        _ => (self, Effect::none())
      }
    }
    Err(message) => self.set_status(message)
  }
}

///|
fn ExcelApp::copy_cells_to_clipboard(
  self : ExcelApp,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  let workbook = current.workbook.copy_selected()
  self.write_cells_to_clipboard(workbook, status="Copied")
}

///|
fn ExcelApp::cut_cells_to_clipboard(
  self : ExcelApp,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  let workbook = current.workbook.cut_selected()
  self.write_cells_to_clipboard(workbook, status="Cut")
}

///|
fn ExcelApp::write_cells_to_clipboard(
  self : ExcelApp,
  workbook : @sheet.Workbook,
  status~ : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  if !workbook.has_clipboard() {
    self.model.set({
      ..current,
      workbook,
      context_menu_visible: false,
      last_clipboard_from_app: false,
      status: "Nothing to copy",
    })
    return (self, Effect::none())
  }
  let text = workbook.clipboard_tsv()
  self.model.set({
    ..current,
    workbook,
    context_menu_visible: false,
    last_clipboard_text: text,
    last_clipboard_from_app: true,
    status,
  })
  match self.services.write_clipboard_text(text) {
    @host.HostServiceResponse::ClipboardWritten => (self, Effect::none())
    @host.HostServiceResponse::Pending(id) =>
      self.set_pending(id, status + "; syncing clipboard...", path="")
    @host.HostServiceResponse::Unavailable(reason) =>
      self.set_status(status + " locally; " + reason)
    _ => (self, Effect::none())
  }
}

///|
fn ExcelApp::paste_cells_from_clipboard(
  self : ExcelApp,
) -> (ExcelApp, Effect[ExcelMsg]) {
  match self.services.read_clipboard_text() {
    @host.HostServiceResponse::ClipboardText(text) =>
      self.apply_clipboard_text(text)
    @host.HostServiceResponse::Pending(id) =>
      self.set_pending(id, "Reading clipboard...", path="")
    @host.HostServiceResponse::Unavailable(reason) =>
      self.paste_cells_locally(reason)
    _ => self.paste_cells_locally("clipboard text unavailable")
  }
}

///|
fn ExcelApp::apply_clipboard_text(
  self : ExcelApp,
  text : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  let use_internal_clipboard = current.last_clipboard_from_app &&
    text == current.last_clipboard_text &&
    current.workbook.has_clipboard()
  let workbook = if use_internal_clipboard {
    current.workbook.paste_selected()
  } else {
    current.workbook.paste_tsv(text)
  }
  self.model.set({
    ..current,
    workbook,
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    file_status: ExcelFileStatus::Idle,
    pending_file_path: "",
    last_clipboard_text: text,
    last_clipboard_from_app: use_internal_clipboard,
    status: "Pasted",
  })
  (self, Effect::none())
}

///|
fn ExcelApp::paste_cells_locally(
  self : ExcelApp,
  reason : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  let status = if reason.is_empty() {
    "Pasted"
  } else {
    "Pasted locally; " + reason
  }
  let workbook = current.workbook.paste_selected()
  self.model.set({
    ..current,
    workbook,
    cell_ref_input: workbook.selected_ref(),
    context_menu_visible: false,
    file_status: ExcelFileStatus::Idle,
    pending_file_path: "",
    status,
  })
  (self, Effect::none())
}

///|
pub fn ExcelApp::handle_host_completion(
  self : ExcelApp,
  completion : @host.HostCompletedServiceResponse,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let current = self.model.get()
  match current.file_status {
    ExcelFileStatus::Pending(id) =>
      if completion.id != id {
        (self, Effect::none())
      } else {
        match (completion.request, completion.response) {
          (
            @host.HostServiceRequest::Clipboard(
              @host.HostClipboardRequest::ReadText
            ),
            @host.HostServiceResponse::ClipboardText(text),
          ) => self.apply_clipboard_text(text)
          (
            @host.HostServiceRequest::Clipboard(
              @host.HostClipboardRequest::ReadText
            ),
            @host.HostServiceResponse::Unavailable(reason),
          ) => self.paste_cells_locally(reason)
          (
            @host.HostServiceRequest::Clipboard(
              @host.HostClipboardRequest::WriteText(_)
            ),
            @host.HostServiceResponse::ClipboardWritten,
          ) => self.set_status("Clipboard updated")
          (
            @host.HostServiceRequest::Clipboard(
              @host.HostClipboardRequest::WriteText(_)
            ),
            @host.HostServiceResponse::Unavailable(reason),
          ) => self.set_status("Clipboard sync failed: " + reason)
          (_, @host.HostServiceResponse::FileDialogSelection(paths)) =>
            if paths.length() > 0 {
              self.read_file(paths[0])
            } else {
              self.set_status("Cancelled")
            }
          (_, @host.HostServiceResponse::BinaryFileContent(_, bytes)) =>
            self.load_workbook_bytes(current.pending_file_path, bytes)
          (_, @host.HostServiceResponse::BinaryFileWritten(_)) =>
            self.set_status("File saved")
          (_, @host.HostServiceResponse::Unavailable(reason)) =>
            self.set_status("Error: " + reason)
          _ => (self, Effect::none())
        }
      }
    _ => (self, Effect::none())
  }
}

///|
pub fn ExcelApp::set_status(
  self : ExcelApp,
  status : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let model = self.model.get()
  self.model.set({ ..model, status, file_status: ExcelFileStatus::Idle })
  (self, Effect::none())
}

///|
pub fn ExcelApp::set_pending(
  self : ExcelApp,
  id : @host.HostServiceRequestId,
  status : String,
  path~ : String,
) -> (ExcelApp, Effect[ExcelMsg]) {
  let model = self.model.get()
  self.model.set({
    ..model,
    status,
    pending_file_path: path,
    file_status: ExcelFileStatus::Pending(id),
  })
  (self, Effect::none())
}

///|
pub fn ExcelApp::subscriptions(self : ExcelApp) -> @moui.Subscription[ExcelMsg] {
  let current = self.model.get()
  match current.file_status {
    ExcelFileStatus::Pending(id) =>
      self.services.completion_subscription(
        id,
        map=completion => ExcelMsg::HostCompleted(completion),
        label="Excel host operation completion",
      )
    ExcelFileStatus::Idle => @moui.Subscription::none()
  }
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
  let builder = StringBuilder::new()
  for ch in chars {
    builder.write_char(ch)
  }
  builder.to_string()
}
