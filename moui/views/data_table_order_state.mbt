///|
pub struct ColumnOrderState {
  order : Array[String]
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
