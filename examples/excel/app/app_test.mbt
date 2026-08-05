///|
test "excel model loads demo workbook" {
  let model = ExcelModel::with_demo_data()
  inspect(model.sheet_names().length().to_string(), content="2")
  inspect(model.sheet_names()[0], content="Sales")
  inspect(model.active_sheet().display_cell(1, 5), content="5550")
}

///|
test "excel model switches sheets and selects cells" {
  let model = ExcelModel::with_demo_data()
  let switched = update(model, ExcelMsg::SheetSelected(1))
  inspect(switched.workbook.active_sheet.to_string(), content="1")
  inspect(switched.active_sheet().name, content="Inventory")
  let selected = update(switched, ExcelMsg::CellSelected(1, 1))
  inspect(selected.cell_ref_input, content="B2")
  inspect(selected.edit_value, content="500")
}

///|
test "excel model selects entire rows and columns" {
  let model = ExcelModel::with_demo_data()
  let row_selected = update(model, ExcelMsg::RowSelected(1))
  inspect(row_selected.selected_ref(), content="A2:L2")
  inspect(
    row_selected.workbook.cell_is_selected(1, 5).to_string(),
    content="true",
  )
  inspect(
    row_selected.workbook.cell_is_selected(2, 5).to_string(),
    content="false",
  )
  let col_selected = update(model, ExcelMsg::ColumnSelected(1))
  inspect(col_selected.selected_ref(), content="B1:B30")
  inspect(
    col_selected.workbook.cell_is_selected(5, 1).to_string(),
    content="true",
  )
  inspect(
    col_selected.workbook.cell_is_selected(5, 2).to_string(),
    content="false",
  )
}

///|
test "excel model selects all cells from corner header" {
  let model = update(ExcelModel::with_demo_data(), ExcelMsg::SelectAllCells)
  inspect(model.selected_ref(), content="A1:L30")
  inspect(model.workbook.cell_is_selected(0, 0).to_string(), content="true")
  inspect(model.workbook.cell_is_selected(29, 11).to_string(), content="true")
  let cleared = update(model, ExcelMsg::ClearCell)
  inspect(cleared.active_sheet().display_cell(0, 0), content="")
  inspect(cleared.active_sheet().display_cell(1, 5), content="")
  let undone = update(cleared, ExcelMsg::Undo)
  inspect(undone.active_sheet().display_cell(0, 0), content="Product")
  inspect(undone.active_sheet().display_cell(1, 5), content="5550")
}

///|
test "excel model formats selected ranges" {
  let model = update(ExcelModel::with_demo_data(), ExcelMsg::RowSelected(1))
  let formatted = update(model, ExcelMsg::ToggleBold)
  inspect(
    formatted.active_sheet().get_cell(1, 0).format.bold.to_string(),
    content="true",
  )
  inspect(
    formatted.active_sheet().get_cell(1, 5).format.bold.to_string(),
    content="true",
  )
  inspect(
    formatted.active_sheet().get_cell(2, 0).format.bold.to_string(),
    content="false",
  )
  let undone = update(formatted, ExcelMsg::Undo)
  inspect(
    undone.active_sheet().get_cell(1, 0).format.bold.to_string(),
    content="false",
  )
}

///|
test "excel model edits formulas and number formats" {
  let model = ExcelModel::with_demo_data().select_cell(1, 5).start_editing()
  let changed = update(model, ExcelMsg::CellValueChanged("=SUM(B2:E2)"))
  let committed = update(changed, ExcelMsg::CellEditCommitted)
  inspect(committed.active_sheet().display_cell(1, 5), content="5550")
  let formatted = update(
    committed,
    ExcelMsg::SetCellFormat(@cell.NumFormat::Currency),
  )
  inspect(formatted.selected_cell().display(), content="$5550.00")
}

///|
test "excel formula bar writes through to selected cell" {
  let model = ExcelModel::with_demo_data().select_cell(1, 1)
  let changed = update(model, ExcelMsg::CellValueChanged("42"))
  inspect(changed.active_sheet().safe_raw(1, 1), content="42")
  inspect(changed.active_sheet().display_cell(1, 1), content="42")
  inspect(changed.edit_value, content="42")
  assert_true(changed.editing)
  let committed = update(changed, ExcelMsg::CellEditCommitted)
  assert_false(committed.editing)
}

///|
test "excel model commits edits and navigates like enter" {
  let model = ExcelModel::with_demo_data().select_cell(1, 1)
  let changed = update(model, ExcelMsg::CellValueChanged("42"))
  let moved_down = update(changed, ExcelMsg::CellEditCommittedAndNavigate(1, 0))
  inspect(moved_down.active_sheet().safe_raw(1, 1), content="42")
  inspect(moved_down.selected_ref(), content="B3")
  inspect(moved_down.edit_value, content="800")
  assert_false(moved_down.editing)
  let moved_up = update(
    moved_down,
    ExcelMsg::CellEditCommittedAndNavigate(-1, 0),
  )
  inspect(moved_up.selected_ref(), content="B2")
}

///|
test "excel model cancels edit and restores previous undo stack" {
  let model = ExcelModel::with_demo_data().select_cell(1, 1)
  let committed = update(
    update(model, ExcelMsg::CellValueChanged("42")),
    ExcelMsg::CellEditCommitted,
  )
  inspect(committed.active_sheet().safe_raw(1, 1), content="42")
  inspect(committed.workbook.undo_stack.length().to_string(), content="1")
  let editing = update(
    committed.start_editing(),
    ExcelMsg::CellValueChanged("99"),
  )
  inspect(editing.active_sheet().safe_raw(1, 1), content="99")
  inspect(editing.workbook.undo_stack.length().to_string(), content="2")
  let cancelled = update(editing, ExcelMsg::CellEditCancelled)
  inspect(cancelled.active_sheet().safe_raw(1, 1), content="42")
  inspect(cancelled.edit_value, content="42")
  assert_false(cancelled.editing)
  inspect(cancelled.workbook.undo_stack.length().to_string(), content="1")
  let undone = update(cancelled, ExcelMsg::Undo)
  inspect(undone.active_sheet().safe_raw(1, 1), content="1200")
}

///|
test "excel model supports copy paste undo redo and navigation" {
  let model = ExcelModel::with_demo_data().select_cell(1, 0)
  let copied = update(model, ExcelMsg::CopyCells)
  let pasted = update(copied.select_cell(2, 1), ExcelMsg::PasteCells)
  inspect(pasted.active_sheet().display_cell(2, 1), content="Widget A")
  let undone = update(pasted, ExcelMsg::Undo)
  inspect(undone.active_sheet().display_cell(2, 1), content="800")
  let redone = update(undone, ExcelMsg::Redo)
  inspect(redone.active_sheet().display_cell(2, 1), content="Widget A")
  let moved = update(redone.select_cell(1, 1), ExcelMsg::CellNavigate(1, 1))
  inspect(moved.cell_ref_input, content="C3")
}

///|
test "excel app syncs copy and paste with system clipboard" {
  let clipboard = Ref("")
  let services = clipboard_services(clipboard)
  let app = ExcelApp::new()
  let model = ExcelModel::with_demo_data()
  app.model.set({ ..model, workbook: model.workbook.select_range(1, 0, 2, 1) })
  ignore(excel_dispatch_message(app, services, ExcelMsg::CopyCells))
  inspect(clipboard.val, content="Widget A\t1200\nWidget B\t800")
  clipboard.val = "North\t10\nSouth\t20"
  app.model.set(app.model.get().select_cell(10, 0))
  ignore(excel_dispatch_message(app, services, ExcelMsg::PasteCells))
  inspect(app.model.get().active_sheet().display_cell(10, 0), content="North")
  inspect(app.model.get().active_sheet().display_cell(10, 1), content="10")
  inspect(app.model.get().active_sheet().display_cell(11, 0), content="South")
  inspect(app.model.get().active_sheet().display_cell(11, 1), content="20")
  inspect(app.model.get().selected_ref(), content="A11:B12")
  inspect(app.model.get().cell_ref_input, content="A11:B12")
  app.model.set(app.model.get().select_cell(13, 0))
  ignore(excel_dispatch_message(app, services, ExcelMsg::PasteCells))
  inspect(app.model.get().active_sheet().display_cell(13, 0), content="North")
  inspect(app.model.get().active_sheet().display_cell(13, 1), content="10")
  inspect(app.model.get().selected_ref(), content="A14:B15")
  inspect(app.model.get().cell_ref_input, content="A14:B15")
}

///|
test "excel app preserves formula references for app-originated clipboard text" {
  let clipboard = Ref("")
  let services = clipboard_services(clipboard)
  let app = ExcelApp::new()
  let sheet = @sheet.Sheet::new("Formulas", row_count=4, col_count=4)
    .set_raw_no_undo(0, 0, "10")
    .set_raw_no_undo(1, 1, "5")
    .set_raw_no_undo(0, 1, "=A1+$A$1")
    .recalc()
  let workbook = @sheet.Workbook::from_sheets([sheet]).select_cell(0, 1)
  app.model.set(
    ExcelModel::from_workbook(
      workbook,
      file_name="Formula.xlsx",
      status="Ready",
    ),
  )
  ignore(excel_dispatch_message(app, services, ExcelMsg::CopyCells))
  inspect(clipboard.val, content="20")
  app.model.set(app.model.get().select_cell(1, 2))
  ignore(excel_dispatch_message(app, services, ExcelMsg::PasteCells))
  inspect(app.model.get().active_sheet().safe_raw(1, 2), content="=B2+$A$1")
  inspect(app.model.get().active_sheet().display_cell(1, 2), content="15")
}

///|
test "excel app applies pending clipboard read completions" {
  let queue = @backend_common.ServiceAsyncQueue::new()
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common.app_services(bridge~, async_queue=Some(queue))
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(12, 0))
  let runtime = excel_dispatch_message(app, services, ExcelMsg::PasteCells)
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
      pending[0].id,
      @host.HostServiceResponse::ClipboardText("Async\t42"),
    ),
  )
  ignore(runtime)
  inspect(app.model.get().active_sheet().display_cell(12, 0), content="Async")
  inspect(app.model.get().active_sheet().display_cell(12, 1), content="42")
}

///|
test "excel model navigates to absolute cell boundaries" {
  let model = ExcelModel::with_demo_data().select_cell(5, 5).start_editing()
  let row_start = update(model, ExcelMsg::CellNavigateTo(5, 0))
  inspect(row_start.selected_ref(), content="A6")
  assert_false(row_start.editing)
  let bottom_right = update(row_start, ExcelMsg::CellNavigateTo(29, 11))
  inspect(bottom_right.selected_ref(), content="L30")
  let clamped = update(bottom_right, ExcelMsg::CellNavigateTo(100, 100))
  inspect(clamped.selected_ref(), content="L30")
}

///|
test "excel model navigates to data edges" {
  let model = ExcelModel::with_demo_data().select_cell(1, 1)
  let right = update(model, ExcelMsg::CellNavigateDataEdge(0, 1))
  inspect(right.selected_ref(), content="F2")
  let boundary = update(right, ExcelMsg::CellNavigateDataEdge(0, 1))
  inspect(boundary.selected_ref(), content="L2")
  let down_range = update(model, ExcelMsg::SelectionNavigateDataEdge(1, 0))
  inspect(down_range.selected_ref(), content="B2:B6")
  inspect(down_range.cell_ref_input, content="B2:B6")
}

///|
test "excel model extends selection with shift navigation" {
  let model = ExcelModel::with_demo_data().select_cell(1, 1)
  let right = update(model, ExcelMsg::SelectionNavigate(0, 1))
  inspect(right.selected_ref(), content="B2:C2")
  inspect(right.cell_ref_input, content="B2:C2")
  let down = update(right, ExcelMsg::SelectionNavigate(1, 0))
  inspect(down.selected_ref(), content="B2:C3")
  let shrunk = update(down, ExcelMsg::SelectionNavigate(0, -1))
  inspect(shrunk.selected_ref(), content="B2:B3")
  let row_start = update(model, ExcelMsg::SelectionNavigateTo(1, 0))
  inspect(row_start.selected_ref(), content="A2:B2")
  inspect(row_start.cell_ref_input, content="A2:B2")
  let bottom_right = update(model, ExcelMsg::SelectionNavigateTo(29, 11))
  inspect(bottom_right.selected_ref(), content="B2:L30")
  assert_false(bottom_right.editing)
}

///|
test "excel model supports row column and sheet operations" {
  let model = ExcelModel::with_demo_data()
  let with_row = update(
    model,
    ExcelMsg::ContextMenuAction(ContextMenuAction::InsertRowBelow),
  )
  inspect(with_row.active_sheet().row_count.to_string(), content="31")
  let row_undone = update(with_row, ExcelMsg::Undo)
  inspect(row_undone.active_sheet().row_count.to_string(), content="30")
  let row_redone = update(row_undone, ExcelMsg::Redo)
  inspect(row_redone.active_sheet().row_count.to_string(), content="31")
  let with_col = update(
    model,
    ExcelMsg::ContextMenuAction(ContextMenuAction::InsertColumnRight),
  )
  inspect(with_col.active_sheet().col_count.to_string(), content="13")
  let col_undone = update(with_col, ExcelMsg::Undo)
  inspect(col_undone.active_sheet().col_count.to_string(), content="12")
  let col_redone = update(col_undone, ExcelMsg::Redo)
  inspect(col_redone.active_sheet().col_count.to_string(), content="13")
  let row_deleted = update(
    model.select_cell(1, 1),
    ExcelMsg::ContextMenuAction(ContextMenuAction::DeleteRow),
  )
  inspect(row_deleted.active_sheet().row_count.to_string(), content="29")
  inspect(row_deleted.active_sheet().display_cell(1, 0), content="Widget B")
  let row_restored = update(row_deleted, ExcelMsg::Undo)
  inspect(row_restored.active_sheet().row_count.to_string(), content="30")
  inspect(row_restored.active_sheet().display_cell(1, 0), content="Widget A")
  let col_deleted = update(
    model.select_cell(1, 1),
    ExcelMsg::ContextMenuAction(ContextMenuAction::DeleteColumn),
  )
  inspect(col_deleted.active_sheet().col_count.to_string(), content="11")
  inspect(col_deleted.active_sheet().display_cell(1, 1), content="1350")
  let col_restored = update(col_deleted, ExcelMsg::Undo)
  inspect(col_restored.active_sheet().col_count.to_string(), content="12")
  inspect(col_restored.active_sheet().display_cell(1, 1), content="1200")
  let added = update(model, ExcelMsg::AddSheet)
  inspect(added.workbook.sheets.length().to_string(), content="3")
  let deleted = update(added, ExcelMsg::DeleteSheet(2))
  inspect(deleted.workbook.sheets.length().to_string(), content="2")
}

///|
test "excel model sorts selected ranges" {
  let sheet = @sheet.Sheet::new("Sort", row_count=5, col_count=3)
    .set_raw_no_undo(0, 0, "Name")
    .set_raw_no_undo(0, 1, "Score")
    .set_raw_no_undo(1, 0, "Gamma")
    .set_raw_no_undo(1, 1, "3")
    .set_raw_no_undo(2, 0, "alpha")
    .set_raw_no_undo(2, 1, "1")
    .set_raw_no_undo(3, 0, "Beta")
    .set_raw_no_undo(3, 1, "2")
    .recalc()
  let model = ExcelModel::from_workbook(
    @sheet.Workbook::from_sheets([sheet]).select_range(1, 0, 3, 1),
    file_name="Sort.xlsx",
    status="Ready",
  )
  let ascending = update(model, ExcelMsg::SortAscending)
  inspect(ascending.active_sheet().display_cell(1, 0), content="alpha")
  inspect(ascending.active_sheet().display_cell(2, 0), content="Beta")
  inspect(ascending.active_sheet().display_cell(3, 0), content="Gamma")
  inspect(ascending.status, content="Sorted A to Z")
  let descending = update(ascending, ExcelMsg::SortDescending)
  inspect(descending.active_sheet().display_cell(1, 0), content="Gamma")
  inspect(descending.active_sheet().display_cell(2, 0), content="Beta")
  inspect(descending.active_sheet().display_cell(3, 0), content="alpha")
  let via_menu = update(
    { ..model, context_menu_visible: true },
    ExcelMsg::ContextMenuAction(ContextMenuAction::SortAscending),
  )
  inspect(via_menu.active_sheet().display_cell(1, 0), content="alpha")
  assert_false(via_menu.context_menu_visible)
}

///|
test "excel model supports go to cell and autocomplete" {
  let model = ExcelModel::with_demo_data()
  let navigated = update(model, ExcelMsg::GoToCell("C3"))
  inspect(navigated.cell_ref_input, content="C3")
  let range = update(navigated.start_editing(), ExcelMsg::GoToCell(" B2:D4 "))
  inspect(range.selected_ref(), content="B2:D4")
  inspect(range.cell_ref_input, content="B2:D4")
  assert_false(range.editing)
  let reversed = update(range, ExcelMsg::GoToCell("D4:B2"))
  inspect(reversed.selected_ref(), content="B2:D4")
  let suggested = update(navigated, ExcelMsg::CellValueChanged("=S"))
  assert_true(suggested.autocomplete_suggestions.length() > 0)
  let selected = update(suggested, ExcelMsg::AutocompleteSelect(0))
  assert_true(selected.edit_value.length() > 2)
  inspect(selected.active_sheet().safe_raw(2, 2), content="=SUM(")
}

///|
test "excel runtime draws desktop shell" {
  let commands = @runtime.new_program_with_dimensions(
    program=program(),
    width=shell_width,
    height=shell_height,
  ).draw_commands()
  assert_true(commands.length() > 0)
  assert_true(has_text(commands, "New"))
  assert_true(has_text(commands, "fx"))
  assert_true(has_text(commands, "Heat"))
}

///|
test "excel runtime formula input updates workbook" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program(),
    width=shell_width,
    height=shell_height,
  )
  assert_true(runtime.focus_key("excel-formula-input"))
  ignore(runtime.dispatch_focused_text_command(@core.CommandIntent::SelectAll))
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("42")),
  )
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="42")
  inspect(app.model.get().active_sheet().display_cell(1, 1), content="42")
}

///|
test "excel runtime grid cell input updates workbook" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data())
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program(),
    width=shell_width,
    height=shell_height,
  )
  assert_true(runtime.focus_key("excel-cell-input-B2"))
  ignore(runtime.dispatch_focused_text_command(@core.CommandIntent::SelectAll))
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("99")),
  )
  inspect(app.model.get().selected_ref(), content="B2")
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="99")
  inspect(app.model.get().edit_value, content="99")
}

///|
test "excel runtime direct typing replaces selected cell content" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data())
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program(),
    width=shell_width,
    height=shell_height,
  )
  assert_true(runtime.focus_key("excel-cell-input-B2"))
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("99")),
  )
  inspect(app.model.get().selected_ref(), content="B2")
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="99")
  inspect(app.model.get().edit_value, content="99")
  assert_true(app.model.get().editing)
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("0")),
  )
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="990")
  inspect(app.model.get().edit_value, content="990")
}

///|
test "excel action command map is available" {
  let app = ExcelApp::new()
  let commands = action_commands(app)
  inspect(commands.commands().length().to_string(), content="79")
}

///|
test "excel action commands dispatch delete key clearing" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="Delete"))
    is Some(_),
  )
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="")
  let restored = update(app.model.get(), ExcelMsg::Undo)
  app.model.set(restored.select_cell(1, 1))
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="Backspace"))
    is Some(_),
  )
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="")
}

///|
test "excel action commands dispatch enter commit navigation" {
  let app = ExcelApp::new()
  app.model.set(
    update(
      ExcelModel::with_demo_data().select_cell(1, 1),
      ExcelMsg::CellValueChanged("42"),
    ),
  )
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="Enter")) is Some(_),
  )
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="42")
  inspect(app.model.get().selected_ref(), content="B3")
  assert_false(app.model.get().editing)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B2")
}

///|
test "excel action commands dispatch f2 edit shortcut" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="F2")) is Some(_),
  )
  assert_true(app.model.get().editing)
  inspect(app.model.get().edit_value, content="1200")
}

///|
test "excel action commands dispatch formula autocomplete shortcuts" {
  let app = ExcelApp::new()
  app.model.set(
    update(
      ExcelModel::with_demo_data().select_cell(1, 1),
      ExcelMsg::CellValueChanged("=A"),
    ),
  )
  let commands = action_commands(app)
  inspect(app.model.get().autocomplete_index.to_string(), content="0")
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="ArrowDown"))
    is Some(_),
  )
  inspect(app.model.get().autocomplete_index.to_string(), content="1")
  inspect(app.model.get().selected_ref(), content="B2")
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="Enter")) is Some(_),
  )
  inspect(app.model.get().edit_value, content="=AVERAGE(")
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="=AVERAGE(")
  inspect(app.model.get().selected_ref(), content="B2")
  inspect(
    app.model.get().autocomplete_suggestions.length().to_string(),
    content="0",
  )
}

///|
test "excel action commands dispatch tab navigation" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="Tab")) is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="C2")
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="Tab",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B2")
}

///|
test "excel action commands dispatch boundary navigation" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5).start_editing())
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="Home")) is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A6")
  assert_false(app.model.get().editing)
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="End")) is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="L6")
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="Home",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A1")
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="End",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="L30")
}

///|
test "excel action commands dispatch page navigation" {
  let app = ExcelApp::new()
  let commands = action_commands(app)
  app.model.set(ExcelModel::with_demo_data().select_cell(9, 1))
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="PageDown"))
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B25")
  assert_true(
    commands.dispatch_shortcut(@core.KeyboardEvent::new(key="PageUp"))
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B10")
  app.model.set(ExcelModel::with_demo_data().select_cell(9, 1))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="PageDown",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B10:B25")
  app.model.set(ExcelModel::with_demo_data().select_cell(20, 1))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="PageUp",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B6:B21")
}

///|
test "excel action commands dispatch shift arrow selection" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="ArrowRight",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B2:C2")
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B2:C3")
}

///|
test "excel action commands dispatch shift boundary selection" {
  let app = ExcelApp::new()
  let commands = action_commands(app)
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5).start_editing())
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="Home",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A6:F6")
  assert_false(app.model.get().editing)
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="End",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="F6:L6")
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="Home",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A1:F6")
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="End",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="F6:L30")
}

///|
test "excel action commands dispatch data edge navigation" {
  let app = ExcelApp::new()
  let commands = action_commands(app)
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="ArrowRight",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="F2")
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B6")
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="ArrowRight",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="B2:F2")
}

///|
test "excel action commands dispatch undo and redo shortcuts" {
  let app = ExcelApp::new()
  app.model.set(
    update(
      ExcelModel::with_demo_data().select_cell(1, 1),
      ExcelMsg::CellValueChanged("42"),
    ),
  )
  let commands = action_commands(app)
  let undo_event = @core.KeyboardEvent::new(
    key="z",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  inspect(
    command_intent_label(commands.dispatch_shortcut(undo_event)),
    content="Undo",
  )
  inspect(app.model.get().active_sheet().display_cell(1, 1), content="1200")
  let redo_event = @core.KeyboardEvent::new(
    key="z",
    modifiers=@core.KeyModifiers::new(meta=true, shift=true),
  )
  inspect(
    command_intent_label(commands.dispatch_shortcut(redo_event)),
    content="Redo",
  )
  inspect(app.model.get().active_sheet().display_cell(1, 1), content="42")
  let control_undo_event = @core.KeyboardEvent::new(
    key="z",
    modifiers=@core.KeyModifiers::new(control=true),
  )
  inspect(
    command_intent_label(commands.dispatch_shortcut(control_undo_event)),
    content="Undo",
  )
  inspect(app.model.get().active_sheet().display_cell(1, 1), content="1200")
  let control_redo_event = @core.KeyboardEvent::new(
    key="y",
    modifiers=@core.KeyModifiers::new(control=true),
  )
  inspect(
    command_intent_label(commands.dispatch_shortcut(control_redo_event)),
    content="Redo",
  )
  inspect(app.model.get().active_sheet().display_cell(1, 1), content="42")
}

///|
test "excel action commands dispatch format shortcuts" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  assert_true(app.model.get().selected_format().bold)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    )
    is Some(_),
  )
  assert_true(app.model.get().selected_format().italic)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="u",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  assert_true(app.model.get().selected_format().underline)
}

///|
test "excel action commands dispatch fill shortcuts" {
  let app = ExcelApp::new()
  let sheet = @sheet.Sheet::new("Fill", row_count=4, col_count=4)
    .set_raw_no_undo(0, 0, "10")
    .set_raw_no_undo(1, 0, "20")
    .set_raw_no_undo(0, 1, "=A1")
    .set_raw_no_undo(3, 0, "5")
    .set_raw_no_undo(3, 1, "6")
    .set_raw_no_undo(2, 0, "=A4")
    .recalc()
  app.model.set(
    ExcelModel::from_workbook(
      @sheet.Workbook::from_sheets([sheet]).select_range(0, 1, 1, 1),
      file_name="Fill.xlsx",
      status="Ready",
    ),
  )
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().active_sheet().safe_raw(1, 1), content="=A2")
  inspect(app.model.get().active_sheet().display_cell(1, 1), content="20")
  app.model.set(
    ExcelModel::from_workbook(
      app.model.get().workbook.select_range(2, 0, 2, 1),
      file_name="Fill.xlsx",
      status="Ready",
    ),
  )
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="r",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().active_sheet().safe_raw(2, 1), content="=B4")
  inspect(app.model.get().active_sheet().display_cell(2, 1), content="6")
}

///|
test "excel action commands dispatch select all shortcuts" {
  let app = ExcelApp::new()
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let commands = action_commands(app)
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A1:L30")
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A1:L30")
}

///|
test "excel action commands dispatch row and column selection shortcuts" {
  let app = ExcelApp::new()
  let commands = action_commands(app)
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5).start_editing())
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key=" ",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="A6:L6")
  assert_false(app.model.get().editing)
  app.model.set(ExcelModel::with_demo_data().select_cell(5, 5))
  assert_true(
    commands.dispatch_shortcut(
      @core.KeyboardEvent::new(
        key=" ",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    )
    is Some(_),
  )
  inspect(app.model.get().selected_ref(), content="F1:F30")
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn command_intent_label(intent : @core.CommandIntent?) -> String {
  match intent {
    Some(value) => value.display_label()
    None => ""
  }
}

///|
struct ExcelTestCommands {
  app : ExcelApp
}

///|
fn action_commands(app : ExcelApp) -> ExcelTestCommands {
  { app, }
}

///|
fn ExcelTestCommands::commands(
  self : ExcelTestCommands,
) -> Array[@core.ActionCommand] {
  excel_test_runtime(self.app).action_commands()
}

///|
fn ExcelTestCommands::dispatch_shortcut(
  self : ExcelTestCommands,
  event : @core.KeyboardEvent,
) -> @core.CommandIntent? {
  let runtime = excel_test_runtime(self.app)
  let mut matched : @core.CommandIntent? = None
  for command in runtime.action_commands() {
    if command.matches(event) {
      matched = Some(command.intent)
      break
    }
  }
  runtime.dispatch_event(@core.AppEvent::Keyboard(event))
  matched
}

///|
fn excel_test_runtime(app : ExcelApp) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=app.program(),
    width=shell_width,
    height=shell_height,
  )
}

///|
fn excel_dispatch_message(
  app : ExcelApp,
  services : @services.AppServices,
  message : ExcelMsg,
) -> @runtime.AppRuntime {
  let program = app
    .program(environment=@services.AppEnvironment::new(services~))
    .with_commands(commands=_ => {
      [
        @moui.ProgramCommand::new(
          command=@core.ActionCommand::new(intent=@core.CommandIntent::Activate),
          message~,
        ),
      ]
    })
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=shell_width,
    height=shell_height,
  )
  ignore(runtime.dispatch_command(@core.CommandIntent::Activate))
  runtime
}

///|
fn clipboard_services(clipboard : Ref[String]) -> @services.AppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::WriteText(text)
        ) => {
          clipboard.val = text
          @host.HostServiceResponse::ClipboardWritten
        }
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => @host.HostServiceResponse::ClipboardText(clipboard.val)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @backend_common.app_services(bridge~)
}
