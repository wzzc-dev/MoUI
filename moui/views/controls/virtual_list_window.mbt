///|
fn[T, Msg] lazy_list_window(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  state : @core.ScrollState,
  item_height : Double,
  viewport_height : Double,
  spacing : Double,
  offset : Double,
) -> @core.View[Msg] {
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
      @container.spacer(
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
      @container.spacer(
        min_length=hidden_after.to_double() * stride,
        weight=0.0,
      ).key("lazy-list-after"),
    )
  }
  scroll_view(
    @layout.list(virtual_children, spacing~),
    offset=state.offset(),
    width=0.0,
    height=viewport_height,
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
  offset : Double,
) -> @core.View[Msg] {
  let limit = offset + viewport_height
  let stride = item_height + spacing
  let overscan = @common.view_max_int(0, overscan)
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
      @container.spacer(
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
      @container.spacer(
        min_length=hidden_after.to_double() * stride,
        weight=0.0,
      ).key("virtual-list-after"),
    )
  }
  scroll_view(
    @layout.list(virtual_children, spacing~),
    offset=state.offset(),
    width=0.0,
    height=viewport_height,
    state=Some(state),
  )
}
