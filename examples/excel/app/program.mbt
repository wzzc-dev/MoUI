///|
pub fn program(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[ExcelApp, ExcelMsg] {
  ExcelApp::new().program(environment~)
}

///|
pub fn ExcelApp::program(
  self : ExcelApp,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[ExcelApp, ExcelMsg] {
  let services = environment.services()
  @moui.Program::new(
    init=() => (self, @moui.Effect::none()),
    update=(app, msg) => app.update_with_services(msg, services),
    view=app => app.view(),
  ).with_commands(commands=app => excel_program_commands(app))
}

///|
pub fn excel_program_commands(
  app : ExcelApp,
) -> Array[@moui.ProgramCommand[ExcelMsg]] {
  let model = app.model
  let commands : Array[@moui.ProgramCommand[ExcelMsg]] = []
  let add = command => commands.push(command)
  let add_dual = (label : String, key : String, message : ExcelMsg) => {
    commands.append(excel_dual_commands(label, key, message))
  }

  add(excel_command("Left", "ArrowLeft", CellNavigate(0, -1)))
  add(excel_command("Right", "ArrowRight", CellNavigate(0, 1)))
  add(
    excel_command(
      "Up",
      "ArrowUp",
      if model.autocomplete_suggestions.is_empty() {
        CellNavigate(-1, 0)
      } else {
        AutocompletePrev
      },
    ),
  )
  add(
    excel_command(
      "Down",
      "ArrowDown",
      if model.autocomplete_suggestions.is_empty() {
        CellNavigate(1, 0)
      } else {
        AutocompleteNext
      },
    ),
  )
  add(excel_command("Page Up", "PageUp", CellNavigate(-page_row_step(), 0)))
  add(excel_command("Page Down", "PageDown", CellNavigate(page_row_step(), 0)))
  for
    item in [
      ("Data Left", "ArrowLeft", 0, -1),
      ("Data Right", "ArrowRight", 0, 1),
      ("Data Up", "ArrowUp", -1, 0),
      ("Data Down", "ArrowDown", 1, 0),
    ] {
    let (label, key, drow, dcol) = item
    add(excel_command(label, key, CellNavigateDataEdge(drow, dcol), meta=true))
    add(
      excel_command(label, key, CellNavigateDataEdge(drow, dcol), control=true),
    )
    add(
      excel_command(
        "Extend " + label,
        key,
        SelectionNavigateDataEdge(drow, dcol),
        meta=true,
        shift=true,
      ),
    )
    add(
      excel_command(
        "Extend " + label,
        key,
        SelectionNavigateDataEdge(drow, dcol),
        control=true,
        shift=true,
      ),
    )
  }
  add(excel_command("Next Cell", "Tab", CellNavigate(0, 1)))
  add(excel_command("Previous Cell", "Tab", CellNavigate(0, -1), shift=true))
  let (row, col) = excel_selection_origin(model)
  let sheet = model.active_sheet()
  add(excel_command("Row Start", "Home", CellNavigateTo(row, 0)))
  add(excel_command("Row End", "End", CellNavigateTo(row, sheet.col_count - 1)))
  add(excel_command("Top Left", "Home", CellNavigateTo(0, 0), meta=true))
  add(excel_command("Top Left", "Home", CellNavigateTo(0, 0), control=true))
  add(
    excel_command(
      "Bottom Right",
      "End",
      CellNavigateTo(sheet.row_count - 1, sheet.col_count - 1),
      meta=true,
    ),
  )
  add(
    excel_command(
      "Bottom Right",
      "End",
      CellNavigateTo(sheet.row_count - 1, sheet.col_count - 1),
      control=true,
    ),
  )
  add(
    excel_command(
      "Extend Row Start",
      "Home",
      SelectionNavigateTo(row, 0),
      shift=true,
    ),
  )
  add(
    excel_command(
      "Extend Row End",
      "End",
      SelectionNavigateTo(row, sheet.col_count - 1),
      shift=true,
    ),
  )
  for use_meta in [true, false] {
    add(
      excel_command(
        "Extend Top Left",
        "Home",
        SelectionNavigateTo(0, 0),
        meta=use_meta,
        control=!use_meta,
        shift=true,
      ),
    )
    add(
      excel_command(
        "Extend Bottom Right",
        "End",
        SelectionNavigateTo(sheet.row_count - 1, sheet.col_count - 1),
        meta=use_meta,
        control=!use_meta,
        shift=true,
      ),
    )
  }
  for
    item in [
      ("Extend Left", "ArrowLeft", 0, -1),
      ("Extend Right", "ArrowRight", 0, 1),
      ("Extend Up", "ArrowUp", -1, 0),
      ("Extend Down", "ArrowDown", 1, 0),
      ("Extend Page Up", "PageUp", -page_row_step(), 0),
      ("Extend Page Down", "PageDown", page_row_step(), 0),
    ] {
    let (label, key, drow, dcol) = item
    add(excel_command(label, key, SelectionNavigate(drow, dcol), shift=true))
  }
  add(excel_command("Commit Down", "Enter", excel_commit_message(model, 1, 0)))
  add(
    excel_command(
      "Commit Up",
      "Enter",
      excel_commit_message(model, -1, 0),
      shift=true,
    ),
  )
  add(excel_command("Edit Cell", "F2", CellEditStarted))
  add(excel_command("Cancel Edit", "Escape", CellEditCancelled))
  add_dual("New Workbook", "n", NewWorkbook)
  add_dual("Open File", "o", FileOpenRequested)
  add_dual("Save File", "s", FileSaveRequested)
  add(excel_command("Load Demo", "d", LoadDemo, meta=true))
  add_dual("Cut", "x", CutCells)
  add_dual("Copy", "c", CopyCells)
  add_dual("Paste", "v", PasteCells)
  add_dual("Select All", "a", SelectAllCells)
  add(excel_command("Select Row", " ", RowSelected(row), shift=true))
  add(excel_command("Select Column", " ", ColumnSelected(col), control=true))
  add_dual("Fill Down", "d", FillDown)
  add_dual("Fill Right", "r", FillRight)
  add(
    excel_command(
      "Undo",
      "z",
      Undo,
      meta=true,
      intent=@views.CommandIntent::Undo,
    ),
  )
  add(
    excel_command(
      "Undo",
      "z",
      Undo,
      control=true,
      intent=@views.CommandIntent::Undo,
    ),
  )
  add(
    excel_command(
      "Redo",
      "z",
      Redo,
      meta=true,
      shift=true,
      intent=@views.CommandIntent::Redo,
    ),
  )
  add(
    excel_command(
      "Redo",
      "y",
      Redo,
      control=true,
      intent=@views.CommandIntent::Redo,
    ),
  )
  add_dual("Bold", "b", ToggleBold)
  add_dual("Italic", "i", ToggleItalic)
  add_dual("Underline", "u", ToggleUnderline)
  add(excel_command("Delete", "Backspace", DeleteSelectedCells))
  add(excel_command("Delete", "Delete", DeleteSelectedCells))
  commands
}

///|
fn excel_command(
  label : String,
  key : String,
  message : ExcelMsg,
  meta? : Bool = false,
  control? : Bool = false,
  shift? : Bool = false,
  intent? : @views.CommandIntent = @views.CommandIntent::Activate,
) -> @moui.ProgramCommand[ExcelMsg] {
  @moui.ProgramCommand::new(
    command=@views.ActionCommand::new(
      intent~,
      label~,
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key~,
          modifiers=@views.KeyModifiers::new(meta~, control~, shift~),
        ),
      ),
    ),
    message~,
  )
}

///|
fn excel_dual_commands(
  label : String,
  key : String,
  message : ExcelMsg,
) -> Array[@moui.ProgramCommand[ExcelMsg]] {
  [
    excel_command(label, key, message, meta=true),
    excel_command(label, key, message, control=true),
  ]
}

///|
fn excel_selection_origin(model : ExcelModel) -> (Int, Int) {
  match model.workbook.selection {
    Some(selection) => (selection.row, selection.col)
    None => (0, 0)
  }
}

///|
fn excel_commit_message(model : ExcelModel, drow : Int, dcol : Int) -> ExcelMsg {
  if model.autocomplete_suggestions.is_empty() {
    CellEditCommittedAndNavigate(drow, dcol)
  } else {
    AutocompleteSelect(model.autocomplete_index)
  }
}

///|
fn page_row_step() -> Int {
  15
}
