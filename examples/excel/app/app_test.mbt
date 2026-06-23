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
test "excel model supports row column and sheet operations" {
  let model = ExcelModel::with_demo_data()
  let with_row = update(
    model,
    ExcelMsg::ContextMenuAction(ContextMenuAction::InsertRowBelow),
  )
  inspect(with_row.active_sheet().row_count.to_string(), content="31")
  let with_col = update(
    model,
    ExcelMsg::ContextMenuAction(ContextMenuAction::InsertColumnRight),
  )
  inspect(with_col.active_sheet().col_count.to_string(), content="13")
  let added = update(model, ExcelMsg::AddSheet)
  inspect(added.workbook.sheets.length().to_string(), content="3")
  let deleted = update(added, ExcelMsg::DeleteSheet(2))
  inspect(deleted.workbook.sheets.length().to_string(), content="2")
}

///|
test "excel model supports go to cell and autocomplete" {
  let model = ExcelModel::with_demo_data()
  let navigated = update(model, ExcelMsg::GoToCell("C3"))
  inspect(navigated.cell_ref_input, content="C3")
  let suggested = update(navigated, ExcelMsg::CellValueChanged("=S"))
  assert_true(suggested.autocomplete_suggestions.length() > 0)
  let selected = update(suggested, ExcelMsg::AutocompleteSelect(0))
  assert_true(selected.edit_value.length() > 2)
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
  let app = ExcelApp::new(@host.HostAppServices::unavailable())
  app.model.set(ExcelModel::with_demo_data().select_cell(1, 1))
  let runtime = @runtime.new_program_with_dimensions(
    program=program_with_services(app, @host.HostAppServices::unavailable()),
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
  let app = ExcelApp::new(@host.HostAppServices::unavailable())
  app.model.set(ExcelModel::with_demo_data())
  let runtime = @runtime.new_program_with_dimensions(
    program=program_with_services(app, @host.HostAppServices::unavailable()),
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
test "excel action command map is available" {
  let app = ExcelApp::new(@host.HostAppServices::unavailable())
  let commands = action_commands(app)
  inspect(commands.commands().length().to_string(), content="14")
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
