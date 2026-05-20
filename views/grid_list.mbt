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
    child: list(virtual_children, spacing~),
  })
}
