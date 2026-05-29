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
pub fn[T, Msg] virtual_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  state? : @core.ScrollState = @core.ScrollState::new(),
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
) -> @core.View[Msg] {
  if items.length() == 0 {
    match empty {
      Some(view) => scroll_view(view, state=Some(state), width=0.0, height=viewport_height)
      None => lazy_list(items, key, row, state~, item_height~, viewport_height~, spacing~)
    }
  } else {
    virtual_list_window(
      items,
      key,
      row,
      state,
      item_height,
      viewport_height,
      spacing,
      overscan,
    )
  }
}

///|
pub fn[T, Msg] sectioned_list(
  sections : Array[SectionListSection[T]],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  state? : @core.ScrollState = @core.ScrollState::new(),
  header? : (SectionListSection[T]) -> @core.View[Msg] = section => text(section.title),
  item_height? : Double = 44.0,
  header_height? : Double = 30.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
) -> @core.View[Msg] {
  let entries = sectioned_list_entries(sections)
  if entries.length() == 0 {
    match empty {
      Some(view) => scroll_view(view, state=Some(state), width=0.0, height=viewport_height)
      None => scroll_view(@core.View::empty(), state=Some(state), width=0.0, height=viewport_height)
    }
  } else {
    let offset = state.offset().y
    let limit = offset + viewport_height
    let overscan = views_max_int(0, overscan)
    let children : Array[@core.View[Msg]] = []
    let mut cursor = 0.0
    let mut first_visible = -1
    let mut last_visible = -1
    for index, entry in entries {
      let height = sectioned_entry_height(entry, header_height, item_height)
      let top = cursor
      let bottom = top + height
      if bottom >= offset - overscan.to_double() * item_height &&
        top <= limit + overscan.to_double() * item_height {
        if first_visible < 0 {
          first_visible = index
        }
        last_visible = index
        children.push(sectioned_entry_view(entry, header, row, key).key(sectioned_entry_key(entry, key)))
      }
      cursor = cursor + height + spacing
    }
    let virtual_children : Array[@core.View[Msg]] = []
    if first_visible > 0 {
      virtual_children.push(
        @core.View::spacer(
          min_length=sectioned_entries_height(entries, 0, first_visible, header_height, item_height, spacing),
          weight=0.0,
        ).key("sectioned-list-before"),
      )
    }
    for child in children {
      virtual_children.push(child)
    }
    if last_visible + 1 < entries.length() {
      virtual_children.push(
        @core.View::spacer(
          min_length=sectioned_entries_height(entries, last_visible + 1, entries.length(), header_height, item_height, spacing),
          weight=0.0,
        ).key("sectioned-list-after"),
      )
    }
    @core.View::scroll(
      child=list(virtual_children, spacing~),
      offset=state.offset(),
      viewport=Some(@core.Size::new(width=0.0, height=viewport_height)),
      state=Some(state),
    )
  }
}

///|
pub fn scroll_to_index(
  state : @core.ScrollState,
  index~ : Int,
  item_height? : Double = 44.0,
  spacing? : Double = 0.0,
) -> ScrollToIndexIntent {
  let index = views_max_int(0, index)
  let offset = @core.Point::new(
    x=state.offset().x,
    y=index.to_double() * (item_height + spacing),
  )
  state.set_offset(offset)
  ScrollToIndexIntent::new(index~, offset~)
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
fn[T, Msg] virtual_list_window(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  state : @core.ScrollState,
  item_height : Double,
  viewport_height : Double,
  spacing : Double,
  overscan : Int,
) -> @core.View[Msg] {
  let offset = state.offset().y
  let limit = offset + viewport_height
  let stride = item_height + spacing
  let overscan = views_max_int(0, overscan)
  let overscan_distance = overscan.to_double() * stride
  let children : Array[@core.View[Msg]] = []
  let mut first_visible = -1
  let mut last_visible = -1
  for index, item in items {
    let top = index.to_double() * stride
    let bottom = top + item_height
    if bottom >= offset - overscan_distance && top <= limit + overscan_distance {
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
      ).key("virtual-list-before"),
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
      ).key("virtual-list-after"),
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
priv enum SectionedListEntry[T] {
  SectionHeader(SectionListSection[T])
  SectionItem(T)
}

///|
fn[T] sectioned_list_entries(
  sections : Array[SectionListSection[T]],
) -> Array[SectionedListEntry[T]] {
  let entries : Array[SectionedListEntry[T]] = []
  for section in sections {
    entries.push(SectionHeader(section))
    for item in section.items {
      entries.push(SectionItem(item))
    }
  }
  entries
}

///|
fn[T] sectioned_entry_height(
  entry : SectionedListEntry[T],
  header_height : Double,
  item_height : Double,
) -> Double {
  match entry {
    SectionHeader(_) => header_height
    SectionItem(_) => item_height
  }
}

///|
fn[T, Msg] sectioned_entry_view(
  entry : SectionedListEntry[T],
  header : (SectionListSection[T]) -> @core.View[Msg],
  row : (T) -> @core.View[Msg],
  _key : (T) -> String,
) -> @core.View[Msg] {
  match entry {
    SectionHeader(section) => header(section)
    SectionItem(item) => row(item)
  }
}

///|
fn[T] sectioned_entry_key(
  entry : SectionedListEntry[T],
  key : (T) -> String,
) -> String {
  match entry {
    SectionHeader(section) => "section-header-" + section.id
    SectionItem(item) => key(item)
  }
}

///|
fn[T] sectioned_entries_height(
  entries : Array[SectionedListEntry[T]],
  start : Int,
  end : Int,
  header_height : Double,
  item_height : Double,
  spacing : Double,
) -> Double {
  let mut total = 0.0
  let end = min_int(entries.length(), end)
  for index in start..<end {
    total = total + sectioned_entry_height(entries[index], header_height, item_height)
    if index + 1 < end {
      total = total + spacing
    }
  }
  total
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
