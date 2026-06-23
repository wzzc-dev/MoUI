///|
pub fn load_workbook(bytes : Bytes) -> Result[@sheet.Workbook, String] {
  let workbook = @mbtexcel.read(bytes) catch {
    _ => return Err("Failed to parse workbook")
  }
  let names = workbook.get_sheet_list()
  if names.is_empty() {
    return Ok(@sheet.Workbook::new())
  }
  let sheets : Array[@sheet.Sheet] = []
  for name in names {
    sheets.push(load_sheet(workbook, name))
  }
  Ok(@sheet.Workbook::from_sheets(sheets))
}

///|
pub fn write_workbook(
  workbook : @sheet.Workbook,
  filename : String,
) -> Result[Bytes, String] {
  ignore(filename)
  let output = @mbtexcel.new_workbook()
  for source_sheet in workbook.sheets {
    ignore(try! output.add_sheet(source_sheet.name))
    for key, cell in source_sheet.cells {
      if !cell.raw.is_empty() {
        ignore(
          output.set_cell(source_sheet.name, key, cell.raw) catch {
            _ => ()
          },
        )
      }
    }
  }
  let bytes = @mbtexcel.write(output) catch {
    _ => return Err("Failed to write workbook")
  }
  Ok(bytes)
}

///|
pub fn new_workbook() -> @sheet.Workbook {
  @sheet.Workbook::new()
}

///|
pub fn demo_workbook() -> @sheet.Workbook {
  @sheet.Workbook::demo()
}

///|
fn load_sheet(
  workbook : @mbtexcel_xlsx.Workbook,
  name : String,
) -> @sheet.Sheet {
  match workbook.sheet(name) {
    None => @sheet.Sheet::new(name)
    Some(source) => {
      let rows = source.get_rows()
      if rows.is_empty() {
        @sheet.Sheet::new(name)
      } else {
        let mut result = @sheet.Sheet::new(
          name,
          row_count=rows.length(),
          col_count=max_row_width(rows),
        )
        for row, values in rows {
          for col, raw in values {
            result = result.set_raw_no_undo(row, col, raw)
          }
        }
        result.recalc()
      }
    }
  }
}

///|
fn max_row_width(rows : Array[Array[String]]) -> Int {
  let mut width = @sheet.default_col_count
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  width
}
