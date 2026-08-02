///|
fn[T, Msg] lazy_grid_window(
  items : Array[T],
  key : (T) -> String,
  cell : (T) -> @core.View[Msg],
  state : @core.ScrollState,
  columns : Int,
  item_height : Double,
  viewport_width : Double,
  viewport_height : Double,
  row_spacing : Double,
  column_spacing : Double,
  shows_indicator : Bool,
  offset : Double,
) -> @core.View[Msg] {
  let columns = if columns > 0 { columns } else { 1 }
  let limit = offset + viewport_height
  let row_stride = item_height + row_spacing
  let row_count = lazy_grid_row_count(items.length(), columns)
  let rows : Array[@core.View[Msg]] = []
  let mut first_visible_row = -1
  let mut last_visible_row = -1
  for row_index in 0..<row_count {
    let top = row_index.to_double() * row_stride
    let bottom = top + item_height
    if bottom >= offset - row_stride && top <= limit + row_stride {
      if first_visible_row < 0 {
        first_visible_row = row_index
      }
      last_visible_row = row_index
      let row_children : Array[@core.View[Msg]] = []
      let start = row_index * columns
      let end = items.length().min(start + columns)
      for item_index in start..<end {
        let item = items[item_index]
        row_children.push(cell(item).key(key(item)))
      }
      rows.push(
        @layout.grid(row_children, columns~, row_spacing=0.0, column_spacing~).key(
          "lazy-grid-row-\{row_index}",
        ),
      )
    }
  }
  let virtual_rows : Array[@core.View[Msg]] = []
  if first_visible_row > 0 {
    virtual_rows.push(
      @container.spacer(
        min_length=first_visible_row.to_double() * row_stride,
        weight=0.0,
      ).key("lazy-grid-before"),
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
      @container.spacer(
        min_length=hidden_after.to_double() * row_stride,
        weight=0.0,
      ).key("lazy-grid-after"),
    )
  }
  scroll_view(
    @layout.list(virtual_rows, spacing=row_spacing),
    offset=state.offset(),
    width=viewport_width,
    height=viewport_height,
    state=Some(state),
    shows_indicator~,
  )
}
