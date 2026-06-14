///|
pub struct DescriptionItem {
  term : String
  detail : String
}

///|
pub struct TableColumn {
  id : String
  label : String
  width : Double
}

///|
pub struct DataSortState {
  column : String
  ascending : Bool
}

///|
pub struct PaginationState {
  page : Int
  page_size : Int
  total_count : Int
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
pub struct SelectionState {
  selected : Array[String]
}

///|
pub struct DataFilter[Msg] {
  id : String
  label : String
  selected : Bool
  message : Msg
  enabled : Bool
}

///|
pub struct SelectableListItem[Msg] {
  id : String
  title : String
  subtitle : String
  detail : String
  message : Msg
  enabled : Bool
}

///|
pub struct TreeItem {
  id : String
  label : String
  children : Array[TreeItem]
}

///|
pub fn description_item(term : String, detail : String) -> DescriptionItem {
  { term, detail }
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
pub fn DataSortState::new(
  column? : String = "",
  ascending? : Bool = true,
) -> DataSortState {
  { column, ascending }
}

///|
pub fn DataSortState::column(self : DataSortState) -> String {
  self.column
}

///|
pub fn DataSortState::ascending(self : DataSortState) -> Bool {
  self.ascending
}

///|
pub fn DataSortState::toggle(
  self : DataSortState,
  column : String,
) -> DataSortState {
  if self.column == column {
    { column, ascending: !self.ascending }
  } else {
    { column, ascending: true }
  }
}

///|
pub fn PaginationState::new(
  page? : Int = 0,
  page_size? : Int = 25,
  total_count? : Int = 0,
) -> PaginationState {
  {
    page: views_max_int(0, page),
    page_size: views_max_int(1, page_size),
    total_count: views_max_int(0, total_count),
  }
}

///|
pub fn PaginationState::page(self : PaginationState) -> Int {
  self.page
}

///|
pub fn PaginationState::page_size(self : PaginationState) -> Int {
  self.page_size
}

///|
pub fn PaginationState::page_count(self : PaginationState) -> Int {
  if self.total_count == 0 {
    1
  } else {
    (self.total_count + self.page_size - 1) / self.page_size
  }
}

///|
pub fn PaginationState::clamped(self : PaginationState) -> PaginationState {
  let page_count = self.page_count()
  { ..self, page: views_min_int(views_max_int(0, self.page), page_count - 1) }
}

///|
pub fn PaginationState::next(self : PaginationState) -> PaginationState {
  { ..self, page: views_min_int(self.page + 1, self.page_count() - 1) }
}

///|
pub fn PaginationState::previous(self : PaginationState) -> PaginationState {
  { ..self, page: views_max_int(0, self.page - 1) }
}

///|
pub fn PaginationState::start_index(self : PaginationState) -> Int {
  self.clamped().page * self.page_size
}

///|
pub fn PaginationState::end_index(self : PaginationState) -> Int {
  views_min_int(self.total_count, self.start_index() + self.page_size)
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
pub fn SelectionState::new(selected? : Array[String] = []) -> SelectionState {
  { selected: selected.copy() }
}

///|
pub fn SelectionState::contains(self : SelectionState, id : String) -> Bool {
  string_array_contains(self.selected, id)
}

///|
pub fn SelectionState::toggle(
  self : SelectionState,
  id : String,
) -> SelectionState {
  { selected: toggle_string_selected(self.selected, id) }
}

///|
pub fn SelectionState::count(self : SelectionState) -> Int {
  self.selected.length()
}

///|
pub fn[Msg] data_filter(
  id~ : String,
  label~ : String,
  selected~ : Bool,
  message~ : Msg,
  enabled? : Bool = true,
) -> DataFilter[Msg] {
  { id, label, selected, message, enabled }
}

///|
pub fn[Msg] SelectableListItem::new(
  id~ : String,
  title~ : String,
  message~ : Msg,
  subtitle? : String = "",
  detail? : String = "",
  enabled? : Bool = true,
) -> SelectableListItem[Msg] {
  { id, title, subtitle, detail, message, enabled }
}

///|
pub fn tree_item(
  id~ : String,
  label~ : String,
  children? : Array[TreeItem] = [],
) -> TreeItem {
  { id, label, children }
}

///|
fn set_string_selected(
  selected : Array[String],
  id : String,
  enabled : Bool,
) -> Array[String] {
  if enabled {
    if string_array_contains(selected, id) {
      selected.copy()
    } else {
      let next = selected.copy()
      next.push(id)
      next
    }
  } else {
    selected.filter(item => item != id)
  }
}

///|
fn toggle_string_selected(
  selected : Array[String],
  id : String,
) -> Array[String] {
  set_string_selected(selected, id, !string_array_contains(selected, id))
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
