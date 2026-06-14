///|
pub struct TableColumn {
  id : String
  label : String
  width : Double
}

///|
pub struct ColumnVisibilityState {
  visible : Array[String]
  locked : Array[String]
}

///|
pub struct ColumnWidthState {
  widths : Array[TableColumn]
  min_width : Double
  max_width : Double
}

///|
pub struct ColumnOrderState {
  order : Array[String]
}

///|
pub fn table_column(
  id~ : String,
  label~ : String,
  width? : Double = 120.0,
) -> TableColumn {
  { id, label, width }
}

///|
pub fn TableColumn::id(self : TableColumn) -> String {
  self.id
}

///|
pub fn TableColumn::width(self : TableColumn) -> Double {
  self.width
}

///|
pub fn ColumnVisibilityState::new(
  visible~ : Array[String],
  locked? : Array[String] = [],
) -> ColumnVisibilityState {
  { visible: visible.copy(), locked: locked.copy() }
}

///|
pub fn ColumnVisibilityState::visible(
  self : ColumnVisibilityState,
) -> Array[String] {
  self.visible.copy()
}

///|
pub fn ColumnVisibilityState::locked(
  self : ColumnVisibilityState,
) -> Array[String] {
  self.locked.copy()
}

///|
pub fn ColumnVisibilityState::is_visible(
  self : ColumnVisibilityState,
  id : String,
) -> Bool {
  string_array_contains(self.visible, id)
}

///|
fn ColumnVisibilityState::is_locked(
  self : ColumnVisibilityState,
  id : String,
) -> Bool {
  string_array_contains(self.locked, id)
}

///|
pub fn ColumnVisibilityState::set_visible(
  self : ColumnVisibilityState,
  id : String,
  visible : Bool,
) -> ColumnVisibilityState {
  if self.is_locked(id) {
    self
  } else {
    { ..self, visible: set_string_selected(self.visible, id, visible) }
  }
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
    max_width: views_max_double(min_width, max_width),
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
  let clamped = views_clamp_double(width, self.min_width, self.max_width)
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

///|
pub fn ColumnOrderState::new(order? : Array[String] = []) -> ColumnOrderState {
  { order: order.copy() }
}

///|
pub fn ColumnOrderState::ordered_columns(
  self : ColumnOrderState,
  columns : Array[TableColumn],
) -> Array[TableColumn] {
  let ordered : Array[TableColumn] = []
  for id in self.order {
    for column in columns {
      if column.id == id && !table_columns_contain(ordered, id) {
        ordered.push(column)
      }
    }
  }
  for column in columns {
    if !table_columns_contain(ordered, column.id) {
      ordered.push(column)
    }
  }
  ordered
}

///|
pub fn ColumnOrderState::move_before(
  self : ColumnOrderState,
  id : String,
  before : String,
) -> ColumnOrderState {
  let remaining = self.order.filter(item => item != id)
  let next : Array[String] = []
  let mut inserted = false
  for item in remaining {
    if item == before && !inserted {
      next.push(id)
      inserted = true
    }
    next.push(item)
  }
  if !inserted {
    next.push(id)
  }
  { order: next }
}

///|
fn table_columns_contain(columns : Array[TableColumn], id : String) -> Bool {
  for column in columns {
    if column.id == id {
      return true
    }
  }
  false
}

///|
fn views_clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
