///|
pub struct TableColumn {
  id : String
  label : String
  width : Double
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
