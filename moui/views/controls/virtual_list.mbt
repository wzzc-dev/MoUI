///|
/// Builds the windowed row children for a virtualized list: only rows
/// intersecting the viewport (plus `overscan` rows on each side) are
/// instantiated; the gap before/after is padded with fixed-height spacers so
/// the scroll extent still matches the full item count.
///
/// Each spacer height is `rows * (item_height + spacing) - spacing`: the
/// trailing `- spacing` compensates for the inter-child gap `list` inserts
/// between the spacer and the first/last windowed row, so the total layout
/// height stays exactly `count * item_height + (count - 1) * spacing`.
fn[T, Msg] windowed_rows(
  items~ : Array[T],
  key~ : (T) -> String,
  row~ : (T) -> @core.View[Msg],
  item_height~ : Double,
  viewport_height~ : Double,
  spacing~ : Double,
  overscan~ : Int,
  offset~ : @core.Point,
  before_key~ : String,
  after_key~ : String,
) -> Array[@core.View[Msg]] {
  let row_stride = item_height + spacing
  let range = @common.visible_row_window(
    row_count=items.length(),
    scroll_y=offset.y,
    viewport_extent=viewport_height,
    row_extent=item_height,
    row_spacing=spacing,
    overscan~,
  )
  let children : Array[@core.View[Msg]] = []
  match range {
    None => ()
    Some({ first_row, last_row }) => {
      if first_row > 0 {
        children.push(
          @container.spacer(
            min_length=first_row.to_double() * row_stride - spacing,
            weight=0.0,
          ).key(before_key),
        )
      }
      let mut index = first_row
      while index <= last_row {
        let item = items[index]
        children.push(row(item).key(key(item)))
        index = index + 1
      }
      let hidden_after = items.length() - 1 - last_row
      if hidden_after > 0 {
        children.push(
          @container.spacer(
            min_length=hidden_after.to_double() * row_stride - spacing,
            weight=0.0,
          ).key(after_key),
        )
      }
    }
  }
  children
}

///|
/// Windowed list: instantiates only the rows intersecting `viewport_height`
/// around `offset.y` (plus one overscan row on each side) and pads the gap
/// with fixed-height spacers, so the scroll extent still matches the full
/// item count. The application owns the scroll offset: it must keep `offset`
/// in its model and feed new positions back through `on_scroll`, exactly like
/// `lazy_grid`. Items scrolled out of the window are remounted (their element
/// state is dropped); keep long-lived item state in the application model.
///
/// Rows use the fixed stride `item_height + spacing`; variable-height items
/// are not supported by the windowed path.
pub fn[T, Msg] lazy_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  offset~ : @core.Point,
  on_scroll~ : (@core.Point) -> Msg,
  request? : @core.ScrollRequest,
) -> @core.View[Msg] {
  let children = windowed_rows(
    items~,
    key~,
    row~,
    item_height~,
    viewport_height~,
    spacing~,
    overscan=1,
    offset~,
    before_key="lazy-list-before",
    after_key="lazy-list-after",
  )
  scroll_view(
    @layout.list(children, spacing~),
    height=viewport_height,
    offset~,
    on_scroll=Some(on_scroll),
    request?,
  )
}

///|
/// Windowed list with an application-controlled overscan and an optional
/// empty state. Identical semantics to `lazy_list`; `overscan` controls how
/// many extra full rows are instantiated above and below the visible window
/// (trading remount churn against node count), and `empty` replaces the
/// whole surface when `items` is empty.
pub fn[T, Msg] virtual_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
  offset~ : @core.Point,
  on_scroll~ : (@core.Point) -> Msg,
  request? : @core.ScrollRequest,
) -> @core.View[Msg] {
  if items.length() == 0 {
    match empty {
      Some(view) =>
        scroll_view(
          view,
          height=viewport_height,
          offset~,
          on_scroll=Some(on_scroll),
          request?,
        )
      None =>
        scroll_view(
          @layout.list([]),
          height=viewport_height,
          offset~,
          on_scroll=Some(on_scroll),
          request?,
        )
    }
  } else {
    let children = windowed_rows(
      items~,
      key~,
      row~,
      item_height~,
      viewport_height~,
      spacing~,
      overscan~,
      offset~,
      before_key="virtual-list-before",
      after_key="virtual-list-after",
    )
    scroll_view(
      @layout.list(children, spacing~),
      height=viewport_height,
      offset~,
      on_scroll=Some(on_scroll),
      request?,
    )
  }
}

///|
pub fn scroll_to_index(
  request_id~ : Int,
  index~ : Int,
  item_height? : Double = 44.0,
  spacing? : Double = 0.0,
) -> @core.ScrollRequest {
  let index = @common.view_max_int(0, index)
  let offset = @core.Point::new(
    x=0.0,
    y=index.to_double() * (item_height + spacing),
  )
  @core.ScrollRequest::new(id=request_id, offset~)
}
