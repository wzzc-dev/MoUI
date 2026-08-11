///|
/// Windowed-row range: the inclusive row interval a windowing list must
/// instantiate so that [first_row, last_row] covers the visible viewport
/// plus `overscan` extra rows on each side.
pub struct WindowedRowRange {
  first_row : Int
  last_row : Int
}

///|
/// Number of rows needed to lay out `item_count` items in `columns` columns.
/// Mirrors the historical `lazy_grid_row_count`; kept here so list and grid
/// windowing share one row model.
pub fn windowed_row_count(item_count~ : Int, columns~ : Int) -> Int {
  if item_count == 0 {
    0
  } else {
    let columns = if columns > 0 { columns } else { 1 }
    (item_count + columns - 1) / columns
  }
}

///|
/// Computes the row window a virtualized list/grid must instantiate:
///
/// ```text
/// stride          = row_extent + row_spacing
/// first_row       = floor(scroll_y / stride) - overscan
/// last_row        = floor((scroll_y + viewport_extent) / stride) + overscan
/// ```
///
/// both clamped to `[0, row_count)`. Rows that merely intersect the viewport
/// count as visible, so `overscan = 0` still renders every partially visible
/// row; `overscan = 1` (the `virtual_list` default) adds one full extra row on
/// each side to absorb remount churn while scrolling.
///
/// Returns `None` when there is nothing to render (empty list or a degenerate
/// non-positive stride).
pub fn visible_row_window(
  row_count~ : Int,
  scroll_y~ : Double,
  viewport_extent~ : Double,
  row_extent~ : Double,
  row_spacing~ : Double,
  overscan~ : Int,
) -> WindowedRowRange? {
  if row_count <= 0 {
    return None
  }
  let stride = row_extent + row_spacing
  if stride <= 0.0 {
    // Degenerate stride: no meaningful windowing; fall back to the full list.
    return Some({ first_row: 0, last_row: row_count - 1 })
  }
  let scan = if overscan > 0 { overscan } else { 0 }
  let first = (scroll_y / stride).floor().to_int() - scan
  let first = if first < 0 { 0 } else { first }
  let last = ((scroll_y + viewport_extent) / stride).floor().to_int() + scan
  let last = if last >= row_count { row_count - 1 } else { last }
  // Scroll past the content end (transient during request/overscroll):
  // collapse the window onto the last rows instead of returning an empty range.
  let first = if first > last { last } else { first }
  Some({ first_row: first, last_row: last })
}
