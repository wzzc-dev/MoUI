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
  shows_indicator? : Bool = false,
) -> @core.View[Msg] {
  component(ctx => {
    let offset = ctx.watch_scroll(state).y
    lazy_grid_window(
      items, key, cell, state, columns, item_height, viewport_width, viewport_height,
      row_spacing, column_spacing, shows_indicator, offset,
    )
  })
}

///|
fn lazy_grid_row_count(item_count : Int, columns : Int) -> Int {
  if item_count == 0 {
    0
  } else {
    (item_count + columns - 1) / columns
  }
}
