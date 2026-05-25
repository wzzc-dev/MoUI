///|
pub fn grid(
  children : Array[@core.ViewSpec],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.ViewSpec {
  @core.ViewSpec::GridSpec({
    key: None,
    columns,
    row_spacing,
    column_spacing,
    children,
  })
}

///|
pub fn list(
  children : Array[@core.ViewSpec],
  spacing? : Double = 0.0,
) -> @core.ViewSpec {
  @core.ViewSpec::ListSpec({ key: None, spacing, children })
}

///|
pub fn[T] lazy_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.ViewSpec,
  state? : @core.ScrollState = @core.ScrollState::new(),
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
) -> @core.ViewSpec {
  let offset = state.offset().y
  let limit = offset + viewport_height
  let stride = item_height + spacing
  let children : Array[@core.ViewSpec] = []
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
  let virtual_children : Array[@core.ViewSpec] = []
  if first_visible > 0 {
    virtual_children.push(
      @core.ViewSpec::SpacerSpec({
        key: Some(@core.Key::new("lazy-list-before")),
        min_length: first_visible.to_double() * stride,
        weight: 0.0,
      }),
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
      @core.ViewSpec::SpacerSpec({
        key: Some(@core.Key::new("lazy-list-after")),
        min_length: hidden_after.to_double() * stride,
        weight: 0.0,
      }),
    )
  }
  @core.ViewSpec::ScrollSpec({
    key: None,
    offset: state.offset(),
    viewport: Some(@core.Size::new(width=0.0, height=viewport_height)),
    on_scroll: Some(delta => {
      state.scroll_to(
        x=0.0,
        y=max_lazy_scroll_offset(0.0, state.offset().y - delta.y),
      )
    }),
    child: list(virtual_children, spacing~),
  })
}

///|
pub fn[T] lazy_grid(
  items : Array[T],
  key : (T) -> String,
  cell : (T) -> @core.ViewSpec,
  state? : @core.ScrollState = @core.ScrollState::new(),
  columns? : Int = 2,
  item_height? : Double = 96.0,
  viewport_width? : Double = 320.0,
  viewport_height? : Double = 240.0,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.ViewSpec {
  let columns = if columns > 0 { columns } else { 1 }
  let offset = state.offset().y
  let limit = offset + viewport_height
  let row_stride = item_height + row_spacing
  let row_count = lazy_grid_row_count(items.length(), columns)
  let rows : Array[@core.ViewSpec] = []
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
      let row_children : Array[@core.ViewSpec] = []
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
  let virtual_rows : Array[@core.ViewSpec] = []
  if first_visible_row > 0 {
    virtual_rows.push(
      @core.ViewSpec::SpacerSpec({
        key: Some(@core.Key::new("lazy-grid-before")),
        min_length: first_visible_row.to_double() * row_stride,
        weight: 0.0,
      }),
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
      @core.ViewSpec::SpacerSpec({
        key: Some(@core.Key::new("lazy-grid-after")),
        min_length: hidden_after.to_double() * row_stride,
        weight: 0.0,
      }),
    )
  }
  @core.ViewSpec::ScrollSpec({
    key: None,
    offset: state.offset(),
    viewport: Some(
      @core.Size::new(width=viewport_width, height=viewport_height),
    ),
    on_scroll: Some(delta => {
      state.scroll_to(
        x=0.0,
        y=max_lazy_scroll_offset(0.0, state.offset().y - delta.y),
      )
    }),
    child: list(virtual_rows, spacing=row_spacing),
  })
}

///|
fn max_lazy_scroll_offset(min : Double, value : Double) -> Double {
  if value < min {
    min
  } else {
    value
  }
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
