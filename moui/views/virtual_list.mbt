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
      @core.View::primitive_spacer_view(
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
      @core.View::primitive_spacer_view(
        min_length=hidden_after.to_double() * stride,
        weight=0.0,
      ).key("lazy-list-after"),
    )
  }
  @core.View::primitive_scroll_view(
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
      Some(view) =>
        scroll_view(view, state=Some(state), width=0.0, height=viewport_height)
      None =>
        lazy_list(
          items,
          key,
          row,
          state~,
          item_height~,
          viewport_height~,
          spacing~,
        )
    }
  } else {
    virtual_list_window(
      items, key, row, state, item_height, viewport_height, spacing, overscan,
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
      @core.View::primitive_spacer_view(
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
      @core.View::primitive_spacer_view(
        min_length=hidden_after.to_double() * stride,
        weight=0.0,
      ).key("virtual-list-after"),
    )
  }
  @core.View::primitive_scroll_view(
    child=list(virtual_children, spacing~),
    offset=state.offset(),
    viewport=Some(@core.Size::new(width=0.0, height=viewport_height)),
    state=Some(state),
  )
}
