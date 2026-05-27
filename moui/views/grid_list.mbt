///|
pub fn[Msg] grid(
  children : Array[@core.View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.View[Msg] {
  @core.View::grid(children~, columns~, row_spacing~, column_spacing~)
}

///|
pub fn[Msg] list(
  children : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
) -> @core.View[Msg] {
  @core.View::list(children~, spacing~)
}

///|
pub fn[T, Msg] lazy_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  state? : @core.ScrollState = @core.ScrollState::new(),
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
) -> @core.View[Msg] {
  let offset = state.offset().y
  let limit = offset + viewport_height
  let stride = item_height + spacing
  let children : Array[@core.View[Msg]] = []
  let mut first_visible = -1
  let mut last_visible = -1
  for index, item in items {
    let top = index.to_double() * stride
    let bottom = top + item_height
    if bottom >= offset && top <= limit {
      if first_visible < 0 {
        first_visible = index
      }
      last_visible = index
      children.push(row(item).key(key(item)))
    }
  }
  let virtual_children : Array[@core.View[Msg]] = []
  if first_visible > 0 {
    virtual_children.push(
      @core.View::spacer(
        min_length=first_visible.to_double() * stride,
        weight=0.0,
      ).key("lazy-list-before"),
    )
  }
  for child in children {
    virtual_children.push(child)
  }
  let hidden_after = if last_visible >= 0 {
    items.length() - last_visible - 1
  } else {
    items.length()
  }
  if hidden_after > 0 {
    virtual_children.push(
      @core.View::spacer(
        min_length=hidden_after.to_double() * stride,
        weight=0.0,
      ).key("lazy-list-after"),
    )
  }
  @core.View::scroll(
    child=list(virtual_children, spacing~),
    offset=state.offset(),
    viewport=Some(@core.Size::new(width=0.0, height=viewport_height)),
    state=Some(state),
  )
}

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
      let end = min_int(items.length(), start + columns)
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
      @core.View::spacer(
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
      @core.View::spacer(
        min_length=hidden_after.to_double() * row_stride,
        weight=0.0,
      ).key("lazy-grid-after"),
    )
  }
  @core.View::scroll(
    child=list(virtual_rows, spacing=row_spacing),
    offset=state.offset(),
    viewport=Some(@core.Size::new(width=viewport_width, height=viewport_height)),
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

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
