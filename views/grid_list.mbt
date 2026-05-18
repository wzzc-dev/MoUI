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
  for index, item in items {
    let top = index.to_double() * stride
    let bottom = top + item_height
    if bottom >= offset && top <= limit {
      children.push(row(item).key(key(item)))
    }
  }
  list(children, spacing~)
}
