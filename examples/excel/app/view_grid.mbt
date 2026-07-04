///|
fn build_grid(model : ExcelModel, theme : @moui.Theme) -> @moui.View[ExcelMsg] {
  let sheet = model.active_sheet()
  let heat_range = if model.heat_map { heat_map_range(sheet) } else { None }
  let rows : Array[@moui.View[ExcelMsg]] = []
  rows.push(build_header_row(sheet, theme))
  for row in 0..<sheet.row_count {
    rows.push(build_data_row(model, row, heat_range, theme))
  }
  let content_width = row_header_width +
    sheet.col_count.to_double() * (cell_width + cell_gap)
  @views.container(
    @views.scroll_view(
      @views.column(rows, spacing=cell_gap, align=@views.CrossAlign::Start),
      width=content_width,
      height=grid_height,
    ),
    width=grid_width,
    height=grid_height,
    background=theme.palette.outline_variant,
    theme~,
    padding=0.0,
  )
}

///|
fn build_header_row(
  sheet : @sheet.Sheet,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  let cells : Array[@moui.View[ExcelMsg]] = [
    header_cell("", row_header_width, col_header_height, theme),
  ]
  for col in 0..<sheet.col_count {
    cells.push(
      header_cell(@cell.column_label(col), cell_width, col_header_height, theme),
    )
  }
  @views.row(cells, spacing=cell_gap, align=@views.CrossAlign::Center)
}

///|
fn build_data_row(
  model : ExcelModel,
  row : Int,
  heat_range : (Double, Double)?,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  let sheet = model.active_sheet()
  let cells : Array[@moui.View[ExcelMsg]] = [
    header_cell((row + 1).to_string(), row_header_width, cell_height, theme),
  ]
  for col in 0..<sheet.col_count {
    cells.push(build_cell(model, row, col, heat_range, theme))
  }
  @views.row(cells, spacing=cell_gap, align=@views.CrossAlign::Center)
}

///|
fn header_cell(
  label : String,
  width : Double,
  height : Double,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  @views.container(
    @views.align(
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=width - 4.0,
        height=height - 4.0,
      ),
      alignment=@geometry.Alignment::center(),
    ),
    width~,
    height~,
    background=theme.palette.surface_variant,
    theme~,
    padding=2.0,
  )
}

///|
fn build_cell(
  model : ExcelModel,
  row : Int,
  col : Int,
  heat_range : (Double, Double)?,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  let sheet = model.active_sheet()
  let cell = sheet.get_cell(row, col)
  let selected = match model.workbook.selection {
    Some(sel) => sel.row == row && sel.col == col
    None => false
  }
  let editing = selected && model.editing
  let bg = cell_background(model, cell, row, col, heat_range, theme)
  let border = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if selected {
        theme.palette.primary
      } else {
        theme.palette.outline_variant
      },
    ),
    width=if selected { 2.0 } else { 1.0 },
  )
  let content : @moui.View[ExcelMsg] = if editing {
    @views.text_field(
      model.edit_value,
      on_input=fn(v) { ExcelMsg::CellRawChanged(row, col, v) },
      on_submit=Some(ExcelMsg::CellEditCommitted),
      variant=@views.TextFieldVariant::Plain,
      theme~,
      width=cell_width - 8.0,
      height=cell_height - 8.0,
    ).key("excel-cell-editor-" + @cell.make_key(row, col))
  } else {
    cell_display_content(model, cell, row, col, theme)
  }
  @views.container(
    content,
    width=cell_width,
    height=cell_height,
    background=bg,
    theme~,
    padding=3.0,
  )
  .border(border)
  .on_tap(ExcelMsg::CellSelected(row, col))
  .on_double_tap(ExcelMsg::CellEditStarted)
}

///|
fn cell_display_content(
  model : ExcelModel,
  cell : @cell.Cell,
  row : Int,
  col : Int,
  theme : @moui.Theme,
) -> @moui.View[ExcelMsg] {
  let selected = match model.workbook.selection {
    Some(sel) => sel.row == row && sel.col == col
    None => false
  }
  if selected {
    @views.text_field(
      cell.raw,
      on_input=fn(v) { ExcelMsg::CellRawChanged(row, col, v) },
      on_submit=Some(ExcelMsg::CellEditCommitted),
      variant=@views.TextFieldVariant::Plain,
      theme~,
      width=cell_width - 8.0,
      height=cell_height - 8.0,
    ).key("excel-cell-input-" + @cell.make_key(row, col))
  } else {
    @views.text_field(
      cell.display(),
      on_input=fn(v) { ExcelMsg::CellRawChanged(row, col, v) },
      on_submit=Some(ExcelMsg::CellEditCommitted),
      variant=@views.TextFieldVariant::Plain,
      theme~,
      width=cell_width - 8.0,
      height=cell_height - 8.0,
    ).key("excel-cell-input-" + @cell.make_key(row, col))
  }
}

///|
fn cell_background(
  model : ExcelModel,
  cell : @cell.Cell,
  row : Int,
  col : Int,
  heat_range : (Double, Double)?,
  theme : @moui.Theme,
) -> @graphics.Color {
  if cell.format.bg_color.length() >= 6 {
    parse_hex_color(cell.format.bg_color).unwrap_or(theme.palette.surface)
  } else {
    let selected = match model.workbook.selection {
      Some(sel) => sel.row == row && sel.col == col
      None => false
    }
    if selected {
      theme.palette.primary_container
    } else if model.heat_map {
      match (cell.value, heat_range) {
        (@cell.CellValue::Number(n), Some((min_value, max_value))) =>
          heat_color(n, min_value, max_value)
        _ => theme.palette.surface
      }
    } else {
      theme.palette.surface
    }
  }
}

///|
fn heat_map_range(sheet : @sheet.Sheet) -> (Double, Double)? {
  let mut found = false
  let mut min_value = 1.0e18
  let mut max_value = -1.0e18
  for _, cell in sheet.cells {
    match cell.value {
      @cell.CellValue::Number(n) => {
        found = true
        if n < min_value {
          min_value = n
        }
        if n > max_value {
          max_value = n
        }
      }
      _ => ()
    }
  }
  if found {
    Some((min_value, max_value))
  } else {
    None
  }
}

///|
fn heat_color(
  value : Double,
  min_value : Double,
  max_value : Double,
) -> @graphics.Color {
  if max_value <= min_value {
    return @graphics.Color::rgba(r=0.89, g=0.95, b=1.0, a=1.0)
  }
  let t = (value - min_value) / (max_value - min_value)
  let red = 0.89 + (0.99 - 0.89) * t
  let green = 0.96 + (0.89 - 0.96) * t
  let blue = 1.0 + (0.82 - 1.0) * t
  @graphics.Color::rgba(r=red, g=green, b=blue, a=1.0)
}

///|
fn parse_hex_color(hex : String) -> @graphics.Color? {
  let start = if hex.length() >= 1 && hex[0] == '#' { 1 } else { 0 }
  if hex.length() < start + 6 {
    return None
  }
  match
    (hex_pair(hex, start), hex_pair(hex, start + 2), hex_pair(hex, start + 4)) {
    (Some(red), Some(green), Some(blue)) =>
      Some(
        @graphics.Color::rgba(
          r=red.to_double() / 255.0,
          g=green.to_double() / 255.0,
          b=blue.to_double() / 255.0,
          a=1.0,
        ),
      )
    _ => None
  }
}

///|
fn hex_pair(hex : String, index : Int) -> Int? {
  match (hex_digit(hex[index]), hex_digit(hex[index + 1])) {
    (Some(hi), Some(lo)) => Some(hi * 16 + lo)
    _ => None
  }
}

///|
fn hex_digit(c : UInt16) -> Int? {
  match c {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    'a' | 'A' => Some(10)
    'b' | 'B' => Some(11)
    'c' | 'C' => Some(12)
    'd' | 'D' => Some(13)
    'e' | 'E' => Some(14)
    'f' | 'F' => Some(15)
    _ => None
  }
}
