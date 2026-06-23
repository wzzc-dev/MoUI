///|
test "workbook demo data and formulas" {
  let workbook = Workbook::demo()
  inspect(workbook.sheet_names().join(","), content="Sales,Inventory")
  let sales = workbook.active()
  inspect(sales.display_cell(1, 5), content="5550")
  inspect(sales.safe_raw(1, 5), content="=SUM(B2:E2)")
}

///|
test "workbook edits selection and undo redo" {
  let workbook = Workbook::demo().select_cell(1, 1)
  let edited = workbook.set_selected_raw("999")
  inspect(edited.active().display_cell(1, 1), content="999")
  let undone = edited.undo()
  inspect(undone.active().display_cell(1, 1), content="1200")
  let redone = undone.redo()
  inspect(redone.active().display_cell(1, 1), content="999")
}

///|
test "workbook copy cut paste and row column operations" {
  let workbook = Workbook::demo().select_cell(1, 0)
  let copied = workbook.copy_selected().select_cell(2, 1).paste_selected()
  inspect(copied.active().display_cell(2, 1), content="Widget A")
  let cut = copied.select_cell(1, 0).cut_selected()
  inspect(cut.active().display_cell(1, 0), content="")
  let with_row = cut.insert_row(2)
  inspect(with_row.active().row_count.to_string(), content="31")
  let without_row = with_row.delete_row(2)
  inspect(without_row.active().row_count.to_string(), content="30")
  let with_col = without_row.insert_column(1)
  inspect(with_col.active().col_count.to_string(), content="13")
  let without_col = with_col.delete_column(1)
  inspect(without_col.active().col_count.to_string(), content="12")
}

///|
test "workbook sheet switching and deletion" {
  let workbook = Workbook::demo()
  let switched = workbook.switch_sheet(1)
  inspect(switched.active().name, content="Inventory")
  let added = switched.add_sheet()
  inspect(added.sheets.length().to_string(), content="3")
  let deleted = added.delete_sheet(2)
  inspect(deleted.sheets.length().to_string(), content="2")
}
