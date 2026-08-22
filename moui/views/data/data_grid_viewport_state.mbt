///|
pub struct DataGridFreezePanes {
  rows : Int
  columns : Int
} derive(Eq, Debug, ToJson)

///|
pub fn data_grid_freeze_panes(
  rows? : Int = 0,
  columns? : Int = 0,
) -> DataGridFreezePanes {
  { rows: rows.max(0), columns: columns.max(0) }
}

///|
pub fn DataGridFreezePanes::rows(self : DataGridFreezePanes) -> Int {
  self.rows
}

///|
pub fn DataGridFreezePanes::columns(self : DataGridFreezePanes) -> Int {
  self.columns
}

///|
pub struct DataGridViewport {
  first_row : Int
  last_row : Int
  first_column : Int
  last_column : Int
  row_count : Int
  column_count : Int
  freeze : DataGridFreezePanes
} derive(Eq, Debug, ToJson)

///|
pub fn data_grid_viewport(
  first_row~ : Int,
  last_row~ : Int,
  first_column~ : Int,
  last_column~ : Int,
  row_count~ : Int,
  column_count~ : Int,
  overscan_rows? : Int = 0,
  overscan_columns? : Int = 0,
  freeze? : DataGridFreezePanes,
) -> DataGridViewport {
  let rows = row_count.max(0)
  let columns = column_count.max(0)
  let resolved_freeze = freeze.unwrap_or(data_grid_freeze_panes())
  let row_max = (rows - 1).max(-1)
  let column_max = (columns - 1).max(-1)
  {
    first_row: (first_row - overscan_rows.max(0)).max(0).min(row_max.max(0)),
    last_row: (last_row + overscan_rows.max(0)).max(-1).min(row_max),
    first_column: (first_column - overscan_columns.max(0))
    .max(0)
    .min(column_max.max(0)),
    last_column: (last_column + overscan_columns.max(0)).max(-1).min(column_max),
    row_count: rows,
    column_count: columns,
    freeze: data_grid_freeze_panes(
      rows=resolved_freeze.rows.min(rows),
      columns=resolved_freeze.columns.min(columns),
    ),
  }
}

///|
pub fn DataGridViewport::contains(
  self : DataGridViewport,
  cell : DataGridCell,
) -> Bool {
  if cell.row < 0 ||
    cell.row >= self.row_count ||
    cell.column < 0 ||
    cell.column >= self.column_count {
    return false
  }
  let row_visible = cell.row < self.freeze.rows ||
    (cell.row >= self.first_row && cell.row <= self.last_row)
  let column_visible = cell.column < self.freeze.columns ||
    (cell.column >= self.first_column && cell.column <= self.last_column)
  row_visible && column_visible
}

///|
pub fn DataGridViewport::cells(self : DataGridViewport) -> Array[DataGridCell] {
  let rows : Array[Int] = []
  for row in 0..<self.freeze.rows {
    rows.push(row)
  }
  let scroll_row_start = self.first_row.max(self.freeze.rows)
  if scroll_row_start <= self.last_row {
    for row in scroll_row_start..<=self.last_row {
      rows.push(row)
    }
  }
  let columns : Array[Int] = []
  for column in 0..<self.freeze.columns {
    columns.push(column)
  }
  let scroll_column_start = self.first_column.max(self.freeze.columns)
  if scroll_column_start <= self.last_column {
    for column in scroll_column_start..<=self.last_column {
      columns.push(column)
    }
  }
  let cells : Array[DataGridCell] = []
  for row in rows {
    for column in columns {
      cells.push(data_grid_cell(row~, column~))
    }
  }
  cells
}
