///|
pub fn[T, Msg] lazy_grid(
  items : Array[T],
  key : (T) -> String,
  cell : (T) -> @core.View[Msg],
  columns? : Int = 2,
  item_height? : Double = 96.0,
  viewport_width? : Double = 320.0,
  viewport_height? : Double = 240.0,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
  offset? : @core.Point,
  on_scroll? : ((@core.Point) -> Msg)? = None,
  request? : @core.ScrollRequest,
  shows_indicator? : Bool = false,
) -> @core.View[Msg] {
  let resolved_columns = if columns > 0 { columns } else { 1 }
  let row_count = lazy_grid_row_count(items.length(), resolved_columns)
  let row_stride = item_height + row_spacing
  let scroll_y = offset.unwrap_or(@core.Point::new(x=0.0, y=0.0)).y
  let limit = scroll_y + viewport_height
  let rows : Array[@core.View[Msg]] = []
  let mut first_visible_row = -1
  let mut last_visible_row = -1
  for row_index in 0..<row_count {
    let top = row_index.to_double() * row_stride
    let bottom = top + item_height
    if bottom >= scroll_y - row_stride && top <= limit + row_stride {
      if first_visible_row < 0 {
        first_visible_row = row_index
      }
      last_visible_row = row_index
      let row_children : Array[@core.View[Msg]] = []
      let start = row_index * resolved_columns
      let end = items.length().min(start + resolved_columns)
      for item_index in start..<end {
        let item = items[item_index]
        row_children.push(cell(item).key(key(item)))
      }
      rows.push(
        @layout.grid(
          row_children,
          columns=resolved_columns,
          row_spacing=0.0,
          column_spacing~,
        ).key("lazy-grid-row-\{row_index}"),
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
    width=viewport_width,
    height=viewport_height,
    offset?,
    on_scroll~,
    request?,
    shows_indicator~,
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
