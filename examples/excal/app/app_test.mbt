///|
test "excal model loads demo data" {
  let model = ExcalModel::with_demo_data()
  inspect(model.sheet_names.length(), content="2")
  inspect(model.sheet_names[0], content="Sales")
  inspect(model.sheet_names[1], content="Inventory")
  inspect(model.headers.length(), content="6")
  inspect(model.headers[0], content="Product")
  inspect(model.rows.length(), content="5")
  inspect(model.rows[0][0], content="Widget A")
}

///|
test "excal model switches sheets" {
  let model = ExcalModel::with_demo_data()
  let switched = model.switch_sheet(1)
  inspect(switched.active_sheet, content="1")
  inspect(switched.headers[0], content="Product")
  inspect(switched.headers.length(), content="4")
  inspect(switched.rows.length(), content="5")
  assert_true(switched.selected_cell is None)
}

///|
test "excal model selects and edits cells" {
  let model = ExcalModel::with_demo_data()
  let selected = model.select_cell(0, 1)
  assert_true(selected.selected_cell is Some((0, 1)))
  inspect(selected.edit_value, content="1200")
  let editing = selected.start_editing()
  assert_true(editing.editing)
  let changed = { ..editing, edit_value: "9999" }
  let committed = changed.commit_edit()
  assert_false(committed.editing)
  inspect(committed.rows[0][1], content="9999")
}

///|
test "excal model cancels edit" {
  let model = ExcalModel::with_demo_data()
  let selected = model.select_cell(0, 0)
  let editing = selected.start_editing()
  let cancelled = editing.cancel_edit()
  assert_false(cancelled.editing)
  inspect(cancelled.rows[0][0], content="Widget A")
}

///|
test "excal update dispatches messages" {
  let model = ExcalModel::with_demo_data()
  let switched = update(model, SheetSelected(1))
  inspect(switched.active_sheet, content="1")
  let selected = update(model, CellSelected(2, 3))
  assert_true(selected.selected_cell is Some((2, 3)))
  let new_model = update(model, NewWorkbook)
  inspect(new_model.sheet_names.length(), content="1")
  inspect(new_model.sheet_names[0], content="Sheet1")
}

///|
test "excal loads and exports workbook" {
  let wb = @mbtexcel.new_workbook()
  ignore(try! wb.add_sheet("Test"))
  try! wb.set_cell("Test", "A1", "A")
  try! wb.set_cell("Test", "B1", "B")
  try! wb.set_cell("Test", "C1", "C")
  try! wb.set_cell("Test", "A2", "1")
  try! wb.set_cell("Test", "B2", "2")
  try! wb.set_cell("Test", "C2", "3")
  let names = sheet_names_of(wb)
  inspect(names.length(), content="1")
  inspect(names[0], content="Test")
  let data = load_sheet_data(wb, "Test")
  inspect(data.0.length(), content="3")
  inspect(data.0[0], content="A")
  inspect(data.1.length(), content="1")
  inspect(data.1[0][2], content="3")
  // Edit and verify - set_cell_rc is 1-indexed: row=2 col=2 = B2 (first data row, second col)
  let _ = try! wb.set_cell_rc("Test", 2, 2, "99")
  let updated = load_sheet_data(wb, "Test")
  inspect(updated.1[0][1], content="99")
  // Export
  let bytes = @mbtexcel.write(wb)
  assert_true(bytes.length() > 0)
}

///|
test "excal runtime draws demo shell" {
  let commands = @runtime.new_program_with_dimensions(
    program=program(),
    width=1000.0,
    height=700.0,
  ).draw_commands()
  assert_true(has_text(commands, "Excal - Demo.xlsx"))
  assert_true(has_text(commands, "Sales"))
  assert_true(has_text(commands, "Inventory"))
  assert_true(has_text(commands, "Product"))
  assert_true(has_text(commands, "Widget A"))
  assert_true(has_text(commands, "Load Demo"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
