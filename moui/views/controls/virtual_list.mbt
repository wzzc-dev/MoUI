///|
pub fn[T, Msg] lazy_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  request? : @core.ScrollRequest,
) -> @core.View[Msg] {
  ignore(item_height)
  let children = items.map(item => row(item).key(key(item)))
  scroll_view(
    @layout.list(children, spacing~),
    height=viewport_height,
    request?,
  )
}

///|
pub fn[T, Msg] virtual_list(
  items : Array[T],
  key : (T) -> String,
  row : (T) -> @core.View[Msg],
  item_height? : Double = 44.0,
  viewport_height? : Double = 240.0,
  spacing? : Double = 0.0,
  overscan? : Int = 1,
  empty? : @core.View[Msg]? = None,
  request? : @core.ScrollRequest,
) -> @core.View[Msg] {
  ignore(overscan)
  if items.length() == 0 {
    match empty {
      Some(view) => scroll_view(view, height=viewport_height, request?)
      None =>
        lazy_list(
          items,
          key,
          row,
          item_height~,
          viewport_height~,
          spacing~,
          request?,
        )
    }
  } else {
    lazy_list(
      items,
      key,
      row,
      item_height~,
      viewport_height~,
      spacing~,
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
