///|
fn[T, Msg] variable_virtual_rows(
  items : Array[T],
  metrics : VariableListMetrics,
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  range : VariableListRange,
) -> Array[@core.View[Msg]] {
  let children : Array[@core.View[Msg]] = []
  if range.before_extent > 0.0 {
    children.push(
      @container.spacer(min_length=range.before_extent, weight=0.0).key(
        "variable-list-before",
      ),
    )
  }
  let last = range.last_index.min(items.length() - 1)
  for index in range.first_index..<=last {
    let item = items[index]
    let height = metrics.height_at(index).unwrap_or(0.0)
    children.push(@layout.frame(row(item), height~).key(key(item)))
  }
  if range.after_extent > 0.0 {
    children.push(
      @container.spacer(min_length=range.after_extent, weight=0.0).key(
        "variable-list-after",
      ),
    )
  }
  children
}

///|
/// Variable-height windowed list. `metrics` must be built from the same keyed
/// item order; keep it in application state when row measurement or data
/// changes need stable-anchor offset restoration.
pub fn[T, Msg] variable_virtual_list(
  items : Array[T],
  metrics~ : VariableListMetrics,
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  viewport_height? : Double = 240.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
  offset~ : @core.Point,
  on_scroll~ : (@core.Point) -> Msg,
  request? : @core.ScrollRequest,
) -> @core.View[Msg] {
  if items.is_empty() || metrics.count() == 0 {
    @controls.scroll_view(
      empty.unwrap_or(@layout.list([])),
      height=viewport_height,
      offset~,
      on_scroll=Some(on_scroll),
      request?,
    )
  } else {
    let range = metrics
      .visible_range(offset_y=offset.y, viewport_height~, overscan~)
      .unwrap()
    @controls.scroll_view(
      @layout.list(
        variable_virtual_rows(items, metrics, key, row, range),
        spacing=metrics.spacing,
      ),
      height=viewport_height,
      offset~,
      on_scroll=Some(on_scroll),
      request?,
    )
  }
}

///|
pub fn scroll_to_key(
  request_id~ : Int,
  metrics~ : VariableListMetrics,
  key~ : String,
  inset? : Double = 0.0,
) -> @core.ScrollRequest? {
  match metrics.offset_for_key(key) {
    Some(offset) =>
      Some(
        @core.ScrollRequest::new(
          id=request_id,
          offset=@core.Point::new(x=0.0, y=(offset + inset).max(0.0)),
        ),
      )
    None => None
  }
}
