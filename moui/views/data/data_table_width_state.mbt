///|
pub struct ColumnWidthState {
  widths : Array[TableColumn]
  min_width : Double
  max_width : Double
}

///|
pub fn ColumnWidthState::new(
  widths? : Array[TableColumn] = [],
  min_width? : Double = 72.0,
  max_width? : Double = 360.0,
) -> ColumnWidthState {
  {
    widths: widths.copy(),
    min_width,
    max_width: @common.view_max_double(min_width, max_width),
  }
}

///|
pub fn ColumnWidthState::width_for(
  self : ColumnWidthState,
  id : String,
  fallback : Double,
) -> Double {
  for column in self.widths {
    if column.id == id {
      return column.width
    }
  }
  fallback
}

///|
pub fn ColumnWidthState::resize(
  self : ColumnWidthState,
  id : String,
  width : Double,
) -> ColumnWidthState {
  let next = self.widths.copy()
  let clamped = @common.clamp_view_double(width, self.min_width, self.max_width)
  for index, column in next {
    if column.id == id {
      next[index] = { ..column, width: clamped }
      return { ..self, widths: next }
    }
  }
  next.push(table_column(id~, label=id, width=clamped))
  { ..self, widths: next }
}

///|
pub fn ColumnWidthState::apply(
  self : ColumnWidthState,
  columns : Array[TableColumn],
) -> Array[TableColumn] {
  columns.map(column => {
    ..column,
    width: self.width_for(column.id, column.width),
  })
}
