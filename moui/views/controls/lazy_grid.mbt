///|
pub fn[T, Msg] lazy_grid(
  items : Array[T],
  key : (T) -> String,
  cell : (T) -> @core.View[Msg],
  columns? : Int = 2,
  item_height? : Double = 96.0,
  viewport_width? : Double = 320.0,
  viewport_height? : Double = 240.0,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
  overscan? : Int = 1,
  offset? : @core.Point,
  on_scroll? : ((@core.Point) -> Msg)? = None,
  request? : @core.ScrollRequest,
  shows_indicator? : Bool = false,
) -> @core.View[Msg] {
  let resolved_columns = if columns > 0 { columns } else { 1 }
  let row_count = @common.windowed_row_count(
    item_count=items.length(),
    columns=resolved_columns,
  )
  let row_stride = item_height + row_spacing
  let scroll_y = offset.unwrap_or(@core.Point::new(x=0.0, y=0.0)).y
  let range = @common.visible_row_window(
    row_count~,
    scroll_y~,
    viewport_extent=viewport_height,
    row_extent=item_height,
    row_spacing~,
    overscan~,
  )
  let virtual_rows : Array[@core.View[Msg]] = []
  match range {
    None => ()
    Some({ first_row, last_row }) => {
      if first_row > 0 {
        virtual_rows.push(
          @container.spacer(
            min_length=first_row.to_double() * row_stride - row_spacing,
            weight=0.0,
          ).key("lazy-grid-before"),
        )
      }
      let mut row_index = first_row
      while row_index <= last_row {
        let row_children : Array[@core.View[Msg]] = []
        let start = row_index * resolved_columns
        let end = items.length().min(start + resolved_columns)
        for item_index in start..<end {
          let item = items[item_index]
          row_children.push(cell(item).key(key(item)))
        }
        virtual_rows.push(
          @layout.grid(
            row_children,
            columns=resolved_columns,
            row_spacing=0.0,
            column_spacing~,
          ).key("lazy-grid-row-\{row_index}"),
        )
        row_index = row_index + 1
      }
      let hidden_after = row_count - last_row - 1
      if hidden_after > 0 {
        virtual_rows.push(
          @container.spacer(
            min_length=hidden_after.to_double() * row_stride - row_spacing,
            weight=0.0,
          ).key("lazy-grid-after"),
        )
      }
    }
  }
  scroll_view(
    @layout.list(virtual_rows, spacing=row_spacing),
    width=viewport_width,
    height=viewport_height,
    offset?,
    on_scroll~,
    request?,
    shows_indicator~,
  )
}
