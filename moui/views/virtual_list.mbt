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
  component(ctx => {
    let offset = ctx.watch_scroll(state).y
    lazy_list_window(
      items, key, row, state, item_height, viewport_height, spacing, offset,
    )
  })
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
    component(ctx => {
      let offset = ctx.watch_scroll(state).y
      virtual_list_window(
        items, key, row, state, item_height, viewport_height, spacing, overscan,
        offset,
      )
    })
  }
}

///|
pub fn scroll_to_index(
  state : @core.ScrollState,
  index~ : Int,
  item_height? : Double = 44.0,
  spacing? : Double = 0.0,
) -> ScrollToIndexIntent {
  let index = @common.view_max_int(0, index)
  let offset = @core.Point::new(
    x=state.offset().x,
    y=index.to_double() * (item_height + spacing),
  )
  state.set_offset(offset)
  { index, offset }
}
