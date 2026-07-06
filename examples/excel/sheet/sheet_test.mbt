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
  let row_undone = with_row.undo()
  inspect(row_undone.active().row_count.to_string(), content="30")
  let row_redone = row_undone.redo()
  inspect(row_redone.active().row_count.to_string(), content="31")
  let without_row = row_redone.delete_row(2)
  inspect(without_row.active().row_count.to_string(), content="30")
  let with_col = without_row.insert_column(1)
  inspect(with_col.active().col_count.to_string(), content="13")
  let col_undone = with_col.undo()
  inspect(col_undone.active().col_count.to_string(), content="12")
  let col_redone = col_undone.redo()
  inspect(col_redone.active().col_count.to_string(), content="13")
  let without_col = col_redone.delete_column(1)
  inspect(without_col.active().col_count.to_string(), content="12")
}

///|
test "workbook copies and pastes rectangular ranges" {
  let sheet = Sheet::new("Range", row_count=4, col_count=4)
    .set_raw_no_undo(0, 0, "A")
    .set_raw_no_undo(0, 1, "B")
    .set_raw_no_undo(1, 0, "C")
    .set_raw_no_undo(1, 1, "D")
    .recalc()
  let pasted = Workbook::from_sheets([sheet])
    .copy_range(0, 0, 1, 1)
    .select_cell(2, 2)
    .paste_selected()
  inspect(pasted.active().display_cell(2, 2), content="A")
  inspect(pasted.active().display_cell(2, 3), content="B")
  inspect(pasted.active().display_cell(3, 2), content="C")
  inspect(pasted.active().display_cell(3, 3), content="D")
  inspect(pasted.selected_ref(), content="C3:D4")
  let undone = pasted.undo()
  inspect(undone.active().display_cell(2, 2), content="")
  inspect(undone.active().display_cell(3, 3), content="")
  let redone = undone.redo()
  inspect(redone.active().display_cell(2, 2), content="A")
  inspect(redone.active().display_cell(3, 3), content="D")
}

///|
test "workbook exports clipboard TSV and pastes external TSV" {
  let sheet = Sheet::new("TSV", row_count=5, col_count=5)
    .set_raw_no_undo(0, 0, "A")
    .set_raw_no_undo(0, 1, "B")
    .set_raw_no_undo(1, 0, "C")
    .set_raw_no_undo(1, 1, "D")
    .set_format_no_undo(3, 3, {
      ..@cell.CellFormat::default(),
      num_format: @cell.NumFormat::Currency,
    })
    .recalc()
  let copied = Workbook::from_sheets([sheet]).copy_range(0, 0, 1, 1)
  assert_true(copied.has_clipboard())
  inspect(copied.clipboard_tsv(), content="A\tB\nC\tD")
  let pasted = copied.select_cell(2, 2).paste_tsv("1\t2\r\n3\t4\n")
  inspect(pasted.active().display_cell(2, 2), content="1")
  inspect(pasted.active().display_cell(2, 3), content="2")
  inspect(pasted.active().display_cell(3, 2), content="3")
  inspect(pasted.active().display_cell(3, 3), content="$4.00")
  inspect(pasted.selected_ref(), content="C3:D4")
  let undone = pasted.undo()
  inspect(undone.active().display_cell(2, 2), content="")
  inspect(undone.active().display_cell(3, 3), content="")
  let redone = undone.redo()
  inspect(redone.active().display_cell(3, 3), content="$4.00")
}

///|
test "workbook round trips quoted TSV clipboard cells" {
  let sheet = Sheet::new("QuotedTSV", row_count=2, col_count=3)
    .set_raw_no_undo(0, 0, "A\tB")
    .set_raw_no_undo(0, 1, "He said \"yes\"")
    .set_raw_no_undo(0, 2, "Line\nBreak")
    .recalc()
  let copied = Workbook::from_sheets([sheet]).copy_range(0, 0, 0, 2)
  let exported = copied.clipboard_tsv()
  inspect(
    exported,
    content="\"A\tB\"\t\"He said \"\"yes\"\"\"\t\"Line\nBreak\"",
  )
  let pasted = Workbook::from_sheets([
      Sheet::new("PasteQuoted", row_count=2, col_count=3),
    ])
    .select_cell(0, 0)
    .paste_tsv(exported)
  inspect(pasted.active().safe_raw(0, 0), content="A\tB")
  inspect(pasted.active().safe_raw(0, 1), content="He said \"yes\"")
  inspect(pasted.active().safe_raw(0, 2), content="Line\nBreak")
  inspect(pasted.selected_ref(), content="A1:C1")
}

///|
test "workbook clears rectangular ranges with undo redo" {
  let sheet = Sheet::new("Clear", row_count=4, col_count=4)
    .set_raw_no_undo(0, 0, "A")
    .set_raw_no_undo(0, 1, "B")
    .set_raw_no_undo(1, 0, "C")
    .set_raw_no_undo(1, 1, "D")
    .set_raw_no_undo(2, 2, "Keep")
    .recalc()
  let cleared = Workbook::from_sheets([sheet]).clear_range(0, 0, 1, 1)
  inspect(cleared.active().display_cell(0, 0), content="")
  inspect(cleared.active().display_cell(1, 1), content="")
  inspect(cleared.active().display_cell(2, 2), content="Keep")
  let undone = cleared.undo()
  inspect(undone.active().display_cell(0, 0), content="A")
  inspect(undone.active().display_cell(1, 1), content="D")
  let redone = undone.redo()
  inspect(redone.active().display_cell(0, 0), content="")
  inspect(redone.active().display_cell(1, 1), content="")
}

///|
test "workbook range selection drives copy and clear" {
  let sheet = Sheet::new("SelectedRange", row_count=5, col_count=5)
    .set_raw_no_undo(0, 0, "A")
    .set_raw_no_undo(0, 1, "B")
    .set_raw_no_undo(1, 0, "C")
    .set_raw_no_undo(1, 1, "D")
    .recalc()
  let selected = Workbook::from_sheets([sheet]).select_range(0, 0, 1, 1)
  inspect(selected.selected_ref(), content="A1:B2")
  inspect(selected.cell_is_selected(1, 1).to_string(), content="true")
  inspect(selected.cell_is_selected(2, 2).to_string(), content="false")
  let pasted = selected.copy_selected().select_cell(3, 3).paste_selected()
  inspect(pasted.active().display_cell(3, 3), content="A")
  inspect(pasted.active().display_cell(4, 4), content="D")
  let cleared = selected.clear_selected()
  inspect(cleared.active().display_cell(0, 0), content="")
  inspect(cleared.active().display_cell(1, 1), content="")
  let restored = cleared.undo()
  inspect(restored.active().display_cell(0, 0), content="A")
  inspect(restored.active().display_cell(1, 1), content="D")
}

///|
test "workbook extends selected ranges from keyboard anchor" {
  let workbook = Workbook::from_sheets([
    Sheet::new("Extend", row_count=5, col_count=5),
  ]).select_cell(1, 1)
  let right = workbook.extend_selection(0, 1)
  inspect(right.selected_ref(), content="B2:C2")
  inspect(right.cell_is_selected(1, 1).to_string(), content="true")
  inspect(right.cell_is_selected(1, 2).to_string(), content="true")
  let down = right.extend_selection(1, 0)
  inspect(down.selected_ref(), content="B2:C3")
  inspect(down.cell_is_selected(2, 2).to_string(), content="true")
  let shrunk = down.extend_selection(0, -1)
  inspect(shrunk.selected_ref(), content="B2:B3")
  inspect(shrunk.cell_is_selected(2, 2).to_string(), content="false")
  let reverse = workbook.select_cell(2, 2).extend_selection(-1, -1)
  inspect(reverse.selected_ref(), content="B2:C3")
  inspect(reverse.cell_is_selected(1, 1).to_string(), content="true")
  inspect(reverse.cell_is_selected(2, 2).to_string(), content="true")
  let row_start = workbook.extend_selection_to(1, 0)
  inspect(row_start.selected_ref(), content="A2:B2")
  let row_end = workbook.extend_selection_to(1, 4)
  inspect(row_end.selected_ref(), content="B2:E2")
  let top_left = workbook.extend_selection_to(0, 0)
  inspect(top_left.selected_ref(), content="A1:B2")
}

///|
test "workbook navigates to contiguous data edges" {
  let workbook = Workbook::demo()
  let right = workbook.select_cell(1, 1).navigate_to_data_edge(0, 1)
  inspect(right.selected_ref(), content="F2")
  let down = workbook.select_cell(1, 1).navigate_to_data_edge(1, 0)
  inspect(down.selected_ref(), content="B6")
  let up = down.navigate_to_data_edge(-1, 0)
  inspect(up.selected_ref(), content="B1")
  let blank_boundary = right.navigate_to_data_edge(0, 1)
  inspect(blank_boundary.selected_ref(), content="L2")
  let blank_to_data = workbook.select_cell(1, 6).navigate_to_data_edge(0, -1)
  inspect(blank_to_data.selected_ref(), content="F2")
  let extended = workbook.select_cell(1, 1).extend_selection_to_data_edge(0, 1)
  inspect(extended.selected_ref(), content="B2:F2")
}

///|
test "workbook applies formats to selected ranges" {
  let sheet = Sheet::new("Formats", row_count=3, col_count=3)
    .set_raw_no_undo(0, 0, "A")
    .set_raw_no_undo(0, 1, "B")
    .set_raw_no_undo(1, 0, "C")
    .set_raw_no_undo(1, 1, "D")
    .recalc()
  let formatted = Workbook::from_sheets([sheet])
    .select_range(0, 0, 1, 1)
    .set_selected_format(fmt => { ..fmt, bold: true })
  inspect(
    formatted.active().get_cell(0, 0).format.bold.to_string(),
    content="true",
  )
  inspect(
    formatted.active().get_cell(1, 1).format.bold.to_string(),
    content="true",
  )
  inspect(
    formatted.active().get_cell(2, 2).format.bold.to_string(),
    content="false",
  )
  let undone = formatted.undo()
  inspect(
    undone.active().get_cell(0, 0).format.bold.to_string(),
    content="false",
  )
  let redone = undone.redo()
  inspect(
    redone.active().get_cell(1, 1).format.bold.to_string(),
    content="true",
  )
}

///|
test "workbook fills selected ranges down and right" {
  let sheet = Sheet::new("Fill", row_count=4, col_count=4)
    .set_raw_no_undo(0, 0, "10")
    .set_raw_no_undo(1, 0, "20")
    .set_raw_no_undo(2, 0, "30")
    .set_raw_no_undo(0, 1, "=A1")
    .set_raw_no_undo(3, 0, "5")
    .set_raw_no_undo(3, 1, "6")
    .set_raw_no_undo(3, 2, "7")
    .set_raw_no_undo(2, 0, "=A4")
    .recalc()
  let down = Workbook::from_sheets([sheet])
    .select_range(0, 1, 2, 1)
    .fill_down_selected()
  inspect(down.active().safe_raw(1, 1), content="=A2")
  inspect(down.active().display_cell(1, 1), content="20")
  inspect(down.active().safe_raw(2, 1), content="=A3")
  let down_undone = down.undo()
  inspect(down_undone.active().safe_raw(1, 1), content="")
  let right = down_undone.select_range(2, 0, 2, 2).fill_right_selected()
  inspect(right.active().safe_raw(2, 1), content="=B4")
  inspect(right.active().display_cell(2, 1), content="6")
  inspect(right.active().safe_raw(2, 2), content="=C4")
  inspect(right.active().display_cell(2, 2), content="7")
}

///|
test "workbook sorts selected ranges by first column" {
  let sheet = Sheet::new("Sort", row_count=6, col_count=3)
    .set_raw_no_undo(0, 0, "Name")
    .set_raw_no_undo(0, 1, "Score")
    .set_raw_no_undo(1, 0, "Gamma")
    .set_raw_no_undo(1, 1, "3")
    .set_raw_no_undo(1, 2, "g")
    .set_raw_no_undo(2, 0, "alpha")
    .set_raw_no_undo(2, 1, "1")
    .set_raw_no_undo(2, 2, "a")
    .set_raw_no_undo(3, 0, "")
    .set_raw_no_undo(3, 1, "9")
    .set_raw_no_undo(3, 2, "blank")
    .set_raw_no_undo(4, 0, "Beta")
    .set_raw_no_undo(4, 1, "2")
    .set_raw_no_undo(4, 2, "b")
    .recalc()
  let workbook = Workbook::from_sheets([sheet]).select_range(1, 0, 4, 2)
  let ascending = workbook.sort_selected_by_first_column(ascending=true)
  inspect(ascending.active().display_cell(1, 0), content="alpha")
  inspect(ascending.active().display_cell(1, 1), content="1")
  inspect(ascending.active().display_cell(2, 0), content="Beta")
  inspect(ascending.active().display_cell(3, 0), content="Gamma")
  inspect(ascending.active().display_cell(4, 2), content="blank")
  inspect(ascending.selected_ref(), content="A2:C5")
  let restored = ascending.undo()
  inspect(restored.active().display_cell(1, 0), content="Gamma")
  inspect(restored.active().display_cell(2, 0), content="alpha")
  inspect(restored.active().display_cell(3, 2), content="blank")
  let redone = restored.redo()
  inspect(redone.active().display_cell(1, 0), content="alpha")
  let descending = workbook.sort_selected_by_first_column(ascending=false)
  inspect(descending.active().display_cell(1, 0), content="Gamma")
  inspect(descending.active().display_cell(2, 0), content="Beta")
  inspect(descending.active().display_cell(3, 0), content="alpha")
  inspect(descending.active().display_cell(4, 2), content="blank")
}

///|
test "workbook translates formula references on pasted cells" {
  let sheet = Sheet::new("Formulas", row_count=4, col_count=4)
    .set_raw_no_undo(0, 0, "10")
    .set_raw_no_undo(1, 1, "5")
    .set_raw_no_undo(0, 1, "=A1+$A$1")
    .recalc()
  let pasted = Workbook::from_sheets([sheet])
    .copy_range(0, 1, 0, 1)
    .select_cell(1, 2)
    .paste_selected()
  inspect(pasted.active().safe_raw(1, 2), content="=B2+$A$1")
  inspect(pasted.active().display_cell(1, 2), content="15")
}

///|
test "workbook row column deletion is undoable" {
  let workbook = Workbook::demo()
  let row_deleted = workbook.delete_row(1)
  inspect(row_deleted.active().row_count.to_string(), content="29")
  inspect(row_deleted.active().display_cell(1, 0), content="Widget B")
  let row_restored = row_deleted.undo()
  inspect(row_restored.active().row_count.to_string(), content="30")
  inspect(row_restored.active().display_cell(1, 0), content="Widget A")
  let row_redone = row_restored.redo()
  inspect(row_redone.active().row_count.to_string(), content="29")
  inspect(row_redone.active().display_cell(1, 0), content="Widget B")
  let col_deleted = workbook.delete_column(1)
  inspect(col_deleted.active().col_count.to_string(), content="11")
  inspect(col_deleted.active().display_cell(1, 1), content="1350")
  let col_restored = col_deleted.undo()
  inspect(col_restored.active().col_count.to_string(), content="12")
  inspect(col_restored.active().display_cell(1, 1), content="1200")
  let col_redone = col_restored.redo()
  inspect(col_redone.active().col_count.to_string(), content="11")
  inspect(col_redone.active().display_cell(1, 1), content="1350")
}

///|
test "workbook structure edits update formula references" {
  let sheet = Sheet::new("Refs")
    .set_raw_no_undo(0, 0, "1")
    .set_raw_no_undo(1, 0, "2")
    .set_raw_no_undo(2, 0, "=SUM(A1:A2)")
    .set_raw_no_undo(2, 1, "=A$2")
    .set_raw_no_undo(0, 1, "4")
    .set_raw_no_undo(0, 2, "=A1+B1")
    .set_raw_no_undo(1, 2, "=$A$1+B$1")
    .recalc()
  let workbook = Workbook::from_sheets([sheet])
  let row_inserted = workbook.insert_row(1)
  inspect(row_inserted.active().safe_raw(3, 0), content="=SUM(A1:A3)")
  inspect(row_inserted.active().display_cell(3, 0), content="3")
  inspect(row_inserted.active().safe_raw(3, 1), content="=A$3")
  inspect(row_inserted.active().display_cell(3, 1), content="2")
  let row_restored = row_inserted.undo()
  inspect(row_restored.active().safe_raw(2, 0), content="=SUM(A1:A2)")
  inspect(row_restored.active().display_cell(2, 0), content="3")
  let col_inserted = workbook.insert_column(1)
  inspect(col_inserted.active().safe_raw(0, 3), content="=A1+C1")
  inspect(col_inserted.active().display_cell(0, 3), content="5")
  inspect(col_inserted.active().safe_raw(1, 3), content="=$A$1+C$1")
  inspect(col_inserted.active().display_cell(1, 3), content="5")
  let col_restored = col_inserted.undo()
  inspect(col_restored.active().safe_raw(0, 2), content="=A1+B1")
  inspect(col_restored.active().display_cell(0, 2), content="5")
}

///|
test "workbook structure deletion marks removed references" {
  let sheet = Sheet::new("Refs")
    .set_raw_no_undo(0, 0, "1")
    .set_raw_no_undo(1, 0, "2")
    .set_raw_no_undo(2, 0, "=A2")
    .set_raw_no_undo(0, 1, "4")
    .set_raw_no_undo(0, 2, "=B1")
    .recalc()
  let workbook = Workbook::from_sheets([sheet])
  let row_deleted = workbook.delete_row(1)
  inspect(row_deleted.active().safe_raw(1, 0), content="=#REF!")
  inspect(row_deleted.active().display_cell(1, 0), content="#REF!")
  let col_deleted = workbook.delete_column(1)
  inspect(col_deleted.active().safe_raw(0, 1), content="=#REF!")
  inspect(col_deleted.active().display_cell(0, 1), content="#REF!")
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

///|
test "workbook deletion preserves active sheet identity when possible" {
  let workbook = Workbook::from_sheets(
    [Sheet::new("One"), Sheet::new("Two"), Sheet::new("Three")],
    active_sheet=2,
  )
  let deleted_before_active = workbook.delete_sheet(1)
  inspect(deleted_before_active.active_sheet.to_string(), content="1")
  inspect(deleted_before_active.active().name, content="Three")
  let deleted_active_last = workbook.delete_sheet(2)
  inspect(deleted_active_last.active_sheet.to_string(), content="1")
  inspect(deleted_active_last.active().name, content="Two")
  let deleted_active_middle = workbook.switch_sheet(1).delete_sheet(1)
  inspect(deleted_active_middle.active_sheet.to_string(), content="1")
  inspect(deleted_active_middle.active().name, content="Three")
}

///|
test "workbook add sheet avoids duplicate names" {
  let workbook = Workbook::from_sheets([
    Sheet::new("Sheet 1"),
    Sheet::new("Sheet 2"),
    Sheet::new("Sheet 3"),
  ])
  let deleted = workbook.delete_sheet(1)
  inspect(deleted.sheet_names().join(","), content="Sheet 1,Sheet 3")
  let added = deleted.add_sheet()
  inspect(added.sheet_names().join(","), content="Sheet 1,Sheet 3,Sheet 4")
  inspect(added.active().name, content="Sheet 4")
}
