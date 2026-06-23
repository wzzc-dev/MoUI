///|
test "xlsx adapter writes and reloads workbook" {
  let workbook = @sheet.Workbook::demo()
  let bytes_result = write_workbook(workbook, "demo.xlsx")
  guard bytes_result is Ok(bytes) else { fail("expected xlsx bytes") }
  assert_true(bytes.length() > 0)
  let loaded_result = load_workbook(bytes)
  guard loaded_result is Ok(loaded) else { fail("expected loaded workbook") }
  inspect(loaded.sheets.length().to_string(), content="2")
  inspect(loaded.active().safe_raw(1, 0), content="Widget A")
}

///|
test "xlsx adapter creates empty workbook" {
  let workbook = new_workbook()
  inspect(workbook.sheets.length().to_string(), content="1")
  inspect(workbook.active().name, content="Sheet1")
}
