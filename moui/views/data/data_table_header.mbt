///|
fn table_header_label(
  column : TableColumn,
  sorted~ : Bool,
  sort_ascending~ : Bool,
) -> String {
  if sorted {
    let marker = if sort_ascending { " ^" } else { " v" }
    column.label + marker
  } else {
    column.label
  }
}

///|
fn table_header_accessibility_label(
  column : TableColumn,
  sorted~ : Bool,
  sort_ascending~ : Bool,
) -> String {
  if sorted {
    let suffix = if sort_ascending {
      ", sorted ascending"
    } else {
      ", sorted descending"
    }
    column.label + suffix
  } else {
    "Sort by " + column.label
  }
}

///|
fn table_column_is_sortable(
  column : TableColumn,
  sortable_columns : Array[String],
) -> Bool {
  sortable_columns.length() == 0 ||
  @controls.string_array_contains(sortable_columns, column.id)
}
