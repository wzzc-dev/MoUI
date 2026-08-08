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
  ignore(item_height)
  let rows : Array[@core.View[Msg]] = []
  let resolved_columns = if columns > 0 { columns } else { 1 }
  let row_count = lazy_grid_row_count(items.length(), resolved_columns)
  for row_index in 0..<row_count {
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
  scroll_view(
    @layout.list(rows, spacing=row_spacing),
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
