///|
pub fn program_with_services(
  app : ExcelApp,
  services : @host.HostAppServices,
) -> @moui.Program[ExcelApp, ExcelMsg] {
  ignore(services)
  @moui.Program::new(
    init=() => (app, @moui.Effect::none()),
    update=(model, msg) => ExcelApp::update(model, msg),
    view=app => {
      @views.component(ctx => {
        let _ = ctx.watch(app.model)
        app.view()
      })
    },
    subscriptions=app => ExcelApp::subscriptions(app),
  )
}

///|
pub fn program() -> @moui.Program[ExcelApp, ExcelMsg] {
  let app = ExcelApp::new(@host.HostAppServices::unavailable())
  program_with_services(app, @host.HostAppServices::unavailable())
}

///|
pub fn action_commands(
  app : ExcelApp,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
) -> @views.ActionCommandMap {
  ignore(services)
  @views.ActionCommandMap::new(bindings=[
    nav_binding("Left", "ArrowLeft", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(0, -1)))
    }),
    nav_binding("Right", "ArrowRight", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(0, 1)))
    }),
    nav_binding("Up", "ArrowUp", fn() {
      autocomplete_or_navigate(app, -1, 0, ExcelMsg::AutocompletePrev)
    }),
    nav_binding("Down", "ArrowDown", fn() {
      autocomplete_or_navigate(app, 1, 0, ExcelMsg::AutocompleteNext)
    }),
    action_binding("Page Up", "PageUp", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(-page_row_step(), 0)))
    }),
    action_binding("Page Down", "PageDown", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(page_row_step(), 0)))
    }),
    data_edge_binding(app, "Data Left", "ArrowLeft", 0, -1, meta=true),
    data_edge_binding(app, "Data Left", "ArrowLeft", 0, -1, control=true),
    data_edge_binding(app, "Data Right", "ArrowRight", 0, 1, meta=true),
    data_edge_binding(app, "Data Right", "ArrowRight", 0, 1, control=true),
    data_edge_binding(app, "Data Up", "ArrowUp", -1, 0, meta=true),
    data_edge_binding(app, "Data Up", "ArrowUp", -1, 0, control=true),
    data_edge_binding(app, "Data Down", "ArrowDown", 1, 0, meta=true),
    data_edge_binding(app, "Data Down", "ArrowDown", 1, 0, control=true),
    data_edge_binding(
      app,
      "Extend Data Left",
      "ArrowLeft",
      0,
      -1,
      meta=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Left",
      "ArrowLeft",
      0,
      -1,
      control=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Right",
      "ArrowRight",
      0,
      1,
      meta=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Right",
      "ArrowRight",
      0,
      1,
      control=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Up",
      "ArrowUp",
      -1,
      0,
      meta=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Up",
      "ArrowUp",
      -1,
      0,
      control=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Down",
      "ArrowDown",
      1,
      0,
      meta=true,
      shift=true,
    ),
    data_edge_binding(
      app,
      "Extend Data Down",
      "ArrowDown",
      1,
      0,
      control=true,
      shift=true,
    ),
    action_binding("Next Cell", "Tab", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(0, 1)))
    }),
    action_binding(
      "Previous Cell",
      "Tab",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(0, -1))) },
      shift=true,
    ),
    action_binding("Row Start", "Home", fn() { select_current_row_start(app) }),
    action_binding("Row End", "End", fn() { select_current_row_end(app) }),
    action_binding("Top Left", "Home", fn() { select_top_left(app) }, meta=true),
    action_binding(
      "Top Left",
      "Home",
      fn() { select_top_left(app) },
      control=true,
    ),
    action_binding(
      "Bottom Right",
      "End",
      fn() { select_bottom_right(app) },
      meta=true,
    ),
    action_binding(
      "Bottom Right",
      "End",
      fn() { select_bottom_right(app) },
      control=true,
    ),
    action_binding(
      "Extend Row Start",
      "Home",
      fn() { extend_current_row_start(app) },
      shift=true,
    ),
    action_binding(
      "Extend Row End",
      "End",
      fn() { extend_current_row_end(app) },
      shift=true,
    ),
    action_binding(
      "Extend Top Left",
      "Home",
      fn() { extend_top_left(app) },
      meta=true,
      shift=true,
    ),
    action_binding(
      "Extend Top Left",
      "Home",
      fn() { extend_top_left(app) },
      control=true,
      shift=true,
    ),
    action_binding(
      "Extend Bottom Right",
      "End",
      fn() { extend_bottom_right(app) },
      meta=true,
      shift=true,
    ),
    action_binding(
      "Extend Bottom Right",
      "End",
      fn() { extend_bottom_right(app) },
      control=true,
      shift=true,
    ),
    action_binding(
      "Extend Left",
      "ArrowLeft",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::SelectionNavigate(0, -1))) },
      shift=true,
    ),
    action_binding(
      "Extend Right",
      "ArrowRight",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::SelectionNavigate(0, 1))) },
      shift=true,
    ),
    action_binding(
      "Extend Up",
      "ArrowUp",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::SelectionNavigate(-1, 0))) },
      shift=true,
    ),
    action_binding(
      "Extend Down",
      "ArrowDown",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::SelectionNavigate(1, 0))) },
      shift=true,
    ),
    action_binding(
      "Extend Page Up",
      "PageUp",
      fn() {
        ignore(
          ExcelApp::update(
            app,
            ExcelMsg::SelectionNavigate(-page_row_step(), 0),
          ),
        )
      },
      shift=true,
    ),
    action_binding(
      "Extend Page Down",
      "PageDown",
      fn() {
        ignore(
          ExcelApp::update(app, ExcelMsg::SelectionNavigate(page_row_step(), 0)),
        )
      },
      shift=true,
    ),
    action_binding("Commit Down", "Enter", fn() {
      commit_or_select_autocomplete(app, 1, 0)
    }),
    action_binding(
      "Commit Up",
      "Enter",
      fn() { commit_or_select_autocomplete(app, -1, 0) },
      shift=true,
    ),
    action_binding("Edit Cell", "F2", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellEditStarted))
    }),
    action_binding("Cancel Edit", "Escape", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::CellEditCancelled))
    }),
    action_binding(
      "New Workbook",
      "n",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::NewWorkbook)) },
      meta=true,
    ),
    action_binding(
      "New Workbook",
      "n",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::NewWorkbook)) },
      control=true,
    ),
    action_binding(
      "Open File",
      "o",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FileOpenRequested)) },
      meta=true,
    ),
    action_binding(
      "Open File",
      "o",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FileOpenRequested)) },
      control=true,
    ),
    action_binding(
      "Save File",
      "s",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FileSaveRequested)) },
      meta=true,
    ),
    action_binding(
      "Save File",
      "s",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FileSaveRequested)) },
      control=true,
    ),
    action_binding(
      "Load Demo",
      "d",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::LoadDemo)) },
      meta=true,
    ),
    action_binding(
      "Cut",
      "x",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CutCells)) },
      meta=true,
    ),
    action_binding(
      "Cut",
      "x",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CutCells)) },
      control=true,
    ),
    action_binding(
      "Copy",
      "c",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CopyCells)) },
      meta=true,
    ),
    action_binding(
      "Copy",
      "c",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::CopyCells)) },
      control=true,
    ),
    action_binding(
      "Paste",
      "v",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::PasteCells)) },
      meta=true,
    ),
    action_binding(
      "Paste",
      "v",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::PasteCells)) },
      control=true,
    ),
    action_binding(
      "Select All",
      "a",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::SelectAllCells)) },
      meta=true,
    ),
    action_binding(
      "Select All",
      "a",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::SelectAllCells)) },
      control=true,
    ),
    action_binding(
      "Select Row",
      " ",
      fn() { select_current_row(app) },
      shift=true,
    ),
    action_binding(
      "Select Column",
      " ",
      fn() { select_current_column(app) },
      control=true,
    ),
    action_binding(
      "Fill Down",
      "d",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FillDown)) },
      meta=true,
    ),
    action_binding(
      "Fill Down",
      "d",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FillDown)) },
      control=true,
    ),
    action_binding(
      "Fill Right",
      "r",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FillRight)) },
      meta=true,
    ),
    action_binding(
      "Fill Right",
      "r",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::FillRight)) },
      control=true,
    ),
    action_binding(
      "Undo",
      "z",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::Undo)) },
      meta=true,
      intent=@views.CommandIntent::Undo,
    ),
    action_binding(
      "Undo",
      "z",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::Undo)) },
      control=true,
      intent=@views.CommandIntent::Undo,
    ),
    action_binding(
      "Redo",
      "z",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::Redo)) },
      meta=true,
      shift=true,
      intent=@views.CommandIntent::Redo,
    ),
    action_binding(
      "Redo",
      "y",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::Redo)) },
      control=true,
      intent=@views.CommandIntent::Redo,
    ),
    action_binding(
      "Bold",
      "b",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::ToggleBold)) },
      meta=true,
    ),
    action_binding(
      "Bold",
      "b",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::ToggleBold)) },
      control=true,
    ),
    action_binding(
      "Italic",
      "i",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::ToggleItalic)) },
      meta=true,
    ),
    action_binding(
      "Italic",
      "i",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::ToggleItalic)) },
      control=true,
    ),
    action_binding(
      "Underline",
      "u",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::ToggleUnderline)) },
      meta=true,
    ),
    action_binding(
      "Underline",
      "u",
      fn() { ignore(ExcelApp::update(app, ExcelMsg::ToggleUnderline)) },
      control=true,
    ),
    action_binding("Delete", "Backspace", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::DeleteSelectedCells))
    }),
    action_binding("Delete", "Delete", fn() {
      ignore(ExcelApp::update(app, ExcelMsg::DeleteSelectedCells))
    }),
  ])
}

///|
fn page_row_step() -> Int {
  15
}

///|
fn autocomplete_or_navigate(
  app : ExcelApp,
  drow : Int,
  dcol : Int,
  autocomplete_msg : ExcelMsg,
) -> Unit {
  if app.model.get().autocomplete_suggestions.is_empty() {
    ignore(ExcelApp::update(app, ExcelMsg::CellNavigate(drow, dcol)))
  } else {
    ignore(ExcelApp::update(app, autocomplete_msg))
  }
}

///|
fn commit_or_select_autocomplete(
  app : ExcelApp,
  drow : Int,
  dcol : Int,
) -> Unit {
  let model = app.model.get()
  if model.autocomplete_suggestions.is_empty() {
    ignore(
      ExcelApp::update(app, ExcelMsg::CellEditCommittedAndNavigate(drow, dcol)),
    )
  } else {
    ignore(
      ExcelApp::update(
        app,
        ExcelMsg::AutocompleteSelect(model.autocomplete_index),
      ),
    )
  }
}

///|
fn select_current_row_start(app : ExcelApp) -> Unit {
  let model = app.model.get()
  let row = match model.workbook.selection {
    Some(sel) => sel.row
    None => 0
  }
  ignore(ExcelApp::update(app, ExcelMsg::CellNavigateTo(row, 0)))
}

///|
fn select_current_row(app : ExcelApp) -> Unit {
  let model = app.model.get()
  let row = match model.workbook.selection {
    Some(sel) => sel.row
    None => 0
  }
  ignore(ExcelApp::update(app, ExcelMsg::RowSelected(row)))
}

///|
fn select_current_column(app : ExcelApp) -> Unit {
  let model = app.model.get()
  let col = match model.workbook.selection {
    Some(sel) => sel.col
    None => 0
  }
  ignore(ExcelApp::update(app, ExcelMsg::ColumnSelected(col)))
}

///|
fn select_current_row_end(app : ExcelApp) -> Unit {
  let model = app.model.get()
  let sheet = model.active_sheet()
  let row = match model.workbook.selection {
    Some(sel) => sel.row
    None => 0
  }
  ignore(
    ExcelApp::update(app, ExcelMsg::CellNavigateTo(row, sheet.col_count - 1)),
  )
}

///|
fn select_top_left(app : ExcelApp) -> Unit {
  ignore(ExcelApp::update(app, ExcelMsg::CellNavigateTo(0, 0)))
}

///|
fn select_bottom_right(app : ExcelApp) -> Unit {
  let sheet = app.model.get().active_sheet()
  ignore(
    ExcelApp::update(
      app,
      ExcelMsg::CellNavigateTo(sheet.row_count - 1, sheet.col_count - 1),
    ),
  )
}

///|
fn extend_current_row_start(app : ExcelApp) -> Unit {
  let model = app.model.get()
  let row = match model.workbook.selection {
    Some(sel) => sel.row
    None => 0
  }
  ignore(ExcelApp::update(app, ExcelMsg::SelectionNavigateTo(row, 0)))
}

///|
fn extend_current_row_end(app : ExcelApp) -> Unit {
  let model = app.model.get()
  let sheet = model.active_sheet()
  let row = match model.workbook.selection {
    Some(sel) => sel.row
    None => 0
  }
  ignore(
    ExcelApp::update(
      app,
      ExcelMsg::SelectionNavigateTo(row, sheet.col_count - 1),
    ),
  )
}

///|
fn extend_top_left(app : ExcelApp) -> Unit {
  ignore(ExcelApp::update(app, ExcelMsg::SelectionNavigateTo(0, 0)))
}

///|
fn extend_bottom_right(app : ExcelApp) -> Unit {
  let sheet = app.model.get().active_sheet()
  ignore(
    ExcelApp::update(
      app,
      ExcelMsg::SelectionNavigateTo(sheet.row_count - 1, sheet.col_count - 1),
    ),
  )
}

///|
fn nav_binding(
  label : String,
  key : String,
  handle : () -> Unit,
) -> @views.CommandBinding {
  @views.CommandBinding::new(
    command=@views.ActionCommand::new(
      intent=@views.CommandIntent::Activate,
      label~,
      shortcut=Some(@views.KeyboardShortcut::new(key~)),
      context_menu=false,
    ),
    handle~,
  )
}

///|
fn action_binding(
  label : String,
  key : String,
  handle : () -> Unit,
  meta? : Bool = false,
  control? : Bool = false,
  shift? : Bool = false,
  intent? : @views.CommandIntent = @views.CommandIntent::Activate,
) -> @views.CommandBinding {
  let modifiers = @views.KeyModifiers::new(meta~, control~, shift~)
  @views.CommandBinding::new(
    command=@views.ActionCommand::new(
      intent~,
      label~,
      shortcut=Some(@views.KeyboardShortcut::new(key~, modifiers~)),
      context_menu=false,
    ),
    handle~,
  )
}

///|
fn data_edge_binding(
  app : ExcelApp,
  label : String,
  key : String,
  drow : Int,
  dcol : Int,
  meta? : Bool = false,
  control? : Bool = false,
  shift? : Bool = false,
) -> @views.CommandBinding {
  action_binding(
    label,
    key,
    fn() {
      if shift {
        ignore(
          ExcelApp::update(app, ExcelMsg::SelectionNavigateDataEdge(drow, dcol)),
        )
      } else {
        ignore(
          ExcelApp::update(app, ExcelMsg::CellNavigateDataEdge(drow, dcol)),
        )
      }
    },
    meta~,
    control~,
    shift~,
  )
}
