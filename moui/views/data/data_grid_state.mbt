///|
pub struct DataGridCell {
  row : Int
  column : Int
} derive(Eq, Debug, ToJson)

///|
pub fn data_grid_cell(row~ : Int, column~ : Int) -> DataGridCell {
  { row: row.max(0), column: column.max(0) }
}

///|
pub fn DataGridCell::row(self : DataGridCell) -> Int {
  self.row
}

///|
pub fn DataGridCell::column(self : DataGridCell) -> Int {
  self.column
}

///|
pub fn data_grid_cell_key(row_key : String, column_key : String) -> String {
  "r\{row_key.length()}:\{row_key}c\{column_key.length()}:\{column_key}"
}

///|
pub struct DataGridSelectionRange {
  first : DataGridCell
  last : DataGridCell
} derive(Eq, Debug, ToJson)

///|
fn data_grid_selection_range(
  anchor : DataGridCell,
  focus : DataGridCell,
) -> DataGridSelectionRange {
  {
    first: data_grid_cell(
      row=anchor.row.min(focus.row),
      column=anchor.column.min(focus.column),
    ),
    last: data_grid_cell(
      row=anchor.row.max(focus.row),
      column=anchor.column.max(focus.column),
    ),
  }
}

///|
pub fn DataGridSelectionRange::first(
  self : DataGridSelectionRange,
) -> DataGridCell {
  self.first
}

///|
pub fn DataGridSelectionRange::last(
  self : DataGridSelectionRange,
) -> DataGridCell {
  self.last
}

///|
pub fn DataGridSelectionRange::contains(
  self : DataGridSelectionRange,
  cell : DataGridCell,
) -> Bool {
  cell.row >= self.first.row &&
  cell.row <= self.last.row &&
  cell.column >= self.first.column &&
  cell.column <= self.last.column
}

///|
pub fn DataGridSelectionRange::cell_count(self : DataGridSelectionRange) -> Int {
  (self.last.row - self.first.row + 1) *
  (self.last.column - self.first.column + 1)
}

///|
pub struct DataGridSelectionState {
  anchor : DataGridCell
  focus : DataGridCell
} derive(Eq, Debug, ToJson)

///|
pub fn DataGridSelectionState::new(
  row? : Int = 0,
  column? : Int = 0,
) -> DataGridSelectionState {
  let cell = data_grid_cell(row~, column~)
  { anchor: cell, focus: cell }
}

///|
pub fn DataGridSelectionState::anchor(
  self : DataGridSelectionState,
) -> DataGridCell {
  self.anchor
}

///|
pub fn DataGridSelectionState::focus(
  self : DataGridSelectionState,
) -> DataGridCell {
  self.focus
}

///|
pub fn DataGridSelectionState::range(
  self : DataGridSelectionState,
) -> DataGridSelectionRange {
  data_grid_selection_range(self.anchor, self.focus)
}

///|
pub fn DataGridSelectionState::select(
  self : DataGridSelectionState,
  cell : DataGridCell,
  extending? : Bool = false,
) -> DataGridSelectionState {
  if extending {
    { ..self, focus: cell }
  } else {
    { anchor: cell, focus: cell }
  }
}

///|
fn data_grid_clamp_cell(
  row : Int,
  column : Int,
  row_count : Int,
  column_count : Int,
) -> DataGridCell {
  data_grid_cell(
    row=row.max(0).min((row_count - 1).max(0)),
    column=column.max(0).min((column_count - 1).max(0)),
  )
}

///|
pub fn DataGridSelectionState::move_by(
  self : DataGridSelectionState,
  row_delta~ : Int,
  column_delta~ : Int,
  row_count~ : Int,
  column_count~ : Int,
  extending? : Bool = false,
) -> DataGridSelectionState {
  let next = data_grid_clamp_cell(
    self.focus.row + row_delta,
    self.focus.column + column_delta,
    row_count,
    column_count,
  )
  self.select(next, extending~)
}

///|
/// Applies spreadsheet-style Arrow/Home/End/PageUp/PageDown movement. Shift
/// extends from the stable anchor; Control/Meta + Home/End targets the first
/// or last cell in the data region.
pub fn DataGridSelectionState::handle_key(
  self : DataGridSelectionState,
  event : @core.KeyboardEvent,
  row_count~ : Int,
  column_count~ : Int,
  page_rows? : Int = 10,
) -> DataGridSelectionState {
  if !event.pressed || row_count <= 0 || column_count <= 0 {
    return self
  }
  let extending = event.modifiers.shift
  let command = event.modifiers.control || event.modifiers.meta
  let target = match event.key {
    "ArrowUp" => Some((self.focus.row - 1, self.focus.column))
    "ArrowDown" => Some((self.focus.row + 1, self.focus.column))
    "ArrowLeft" => Some((self.focus.row, self.focus.column - 1))
    "ArrowRight" => Some((self.focus.row, self.focus.column + 1))
    "PageUp" => Some((self.focus.row - page_rows.max(1), self.focus.column))
    "PageDown" => Some((self.focus.row + page_rows.max(1), self.focus.column))
    "Home" => if command { Some((0, 0)) } else { Some((self.focus.row, 0)) }
    "End" =>
      if command {
        Some((row_count - 1, column_count - 1))
      } else {
        Some((self.focus.row, column_count - 1))
      }
    _ => None
  }
  match target {
    Some((row, column)) =>
      self.select(
        data_grid_clamp_cell(row, column, row_count, column_count),
        extending~,
      )
    None => self
  }
}
