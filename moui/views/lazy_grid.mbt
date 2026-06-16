///|
pub fn[T, Msg] lazy_grid(
  items : Array[T],
  key : (T) -> String,
  cell : (T) -> @core.View[Msg],
  state? : @core.ScrollState = @core.ScrollState::new(),
  columns? : Int = 2,
  item_height? : Double = 96.0,
  viewport_width? : Double = 320.0,
  viewport_height? : Double = 240.0,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.View[Msg] {
  let columns = if columns > 0 { columns } else { 1 }
  let offset = state.offset().y
  let limit = offset + viewport_height
  let row_stride = item_height + row_spacing
  let row_count = lazy_grid_row_count(items.length(), columns)
  let rows : Array[@core.View[Msg]] = []
  let mut first_visible_row = -1
  let mut last_visible_row = -1
  for row_index in 0..<row_count {
    let top = row_index.to_double() * row_stride
    let bottom = top + item_height
    if bottom >= offset && top <= limit {
      if first_visible_row < 0 {
        first_visible_row = row_index
      }
      last_visible_row = row_index
      let row_children : Array[@core.View[Msg]] = []
      let start = row_index * columns
      let end = views_min_int(items.length(), start + columns)
      for item_index in start..<end {
        let item = items[item_index]
        row_children.push(cell(item).key(key(item)))
      }
      rows.push(
        grid(row_children, columns~, row_spacing=0.0, column_spacing~).key(
          "lazy-grid-row-\{row_index}",
        ),
      )
    }
  }
  let virtual_rows : Array[@core.View[Msg]] = []
  if first_visible_row > 0 {
    virtual_rows.push(
      spacer(min_length=first_visible_row.to_double() * row_stride, weight=0.0).key(
        "lazy-grid-before",
      ),
    )
  }
  for row in rows {
    virtual_rows.push(row)
  }
  let hidden_after = if last_visible_row >= 0 {
    row_count - last_visible_row - 1
  } else {
    row_count
  }
  if hidden_after > 0 {
    virtual_rows.push(
      spacer(min_length=hidden_after.to_double() * row_stride, weight=0.0).key(
        "lazy-grid-after",
      ),
    )
  }
  scroll_view(
    list(virtual_rows, spacing=row_spacing),
    offset=state.offset(),
    width=viewport_width,
    height=viewport_height,
    state=Some(state),
  )
}

///|
fn lazy_grid_row_count(item_count : Int, columns : Int) -> Int {
  if item_count == 0 {
    0
  } else {
    (item_count + columns - 1) / columns
  }
}
