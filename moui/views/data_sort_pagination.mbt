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
