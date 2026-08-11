///|
/// Helper: unwraps the scroll_view -> list wrapper to reach the windowed rows.
fn lazy_grid_rows(view : @core.View[Unit]) -> Array[@core.View[Unit]] {
  view.children()[0].children()
}

///|
/// Helper: a fixed-height grid cell matching the item stride used below.
fn lazy_grid_test_cell(item : String) -> @core.View[Unit] {
  @views.text(item, height=96.0)
}

///|
test "lazy_grid top window renders every row" {
  // 7 items in 2 columns -> 4 rows; stride = 100 (96 + 4); viewport 240
  // shows rows 0..2, overscan 1 widens to (0, 3): all rows, no spacers.
  let view : @core.View[Unit] = @views.lazy_grid(
    lazy_test_items(7),
    item => item,
    lazy_grid_test_cell,
    columns=2,
    item_height=96.0,
    viewport_height=240.0,
    row_spacing=4.0,
    overscan=1,
    offset=@core.Point::new(x=0.0, y=0.0),
    on_scroll=Some(_ => ()),
  )
  let children = lazy_grid_rows(view)
  inspect(children.length(), content="4")
  inspect(children[0].identity().kind, content="Grid")
  // Rows are key-wrapped, so cells live one level deeper.
  inspect(children[0].children()[0].children().length(), content="2")
  // Last row has the remaining item only.
  inspect(children[3].children()[0].children().length(), content="1")
}

///|
test "lazy_grid mid-scroll window pads both sides" {
  // 50 items in 2 columns -> 25 rows; stride = 100; offset.y = 460
  // -> window (3, 8) with overscan 1: before spacer + 6 rows + after spacer.
  // Spacer heights subtract one `row_spacing` for the list inter-child gap:
  // before = 3*100 - 4 = 296, after = 16*100 - 4 = 1596, and the total
  // layout height equals 25*96 + 24*4 = 2496.
  let view : @core.View[Unit] = @views.lazy_grid(
    lazy_test_items(50),
    item => item,
    lazy_grid_test_cell,
    columns=2,
    item_height=96.0,
    viewport_height=240.0,
    row_spacing=4.0,
    overscan=1,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=Some(_ => ()),
  )
  let children = lazy_grid_rows(view)
  inspect(children.length(), content="8")
  inspect(children[0].identity().kind, content="Spacer")
  inspect(children[1].identity().kind, content="Grid")
  inspect(children[6].identity().kind, content="Grid")
  inspect(children[7].identity().kind, content="Spacer")
  inspect(lazy_layout_height(children[0]).to_int(), content="296")
  inspect(lazy_layout_height(children[1]).to_int(), content="96")
  inspect(lazy_layout_height(children[7]).to_int(), content="1596")
  let total = 296.0 + 6.0 * 96.0 + 1596.0 + 7.0 * 4.0
  inspect(total.to_int(), content="2496")
}

///|
test "lazy_grid overscan widens the window" {
  let base : @core.View[Unit] = @views.lazy_grid(
    lazy_test_items(50),
    item => item,
    lazy_grid_test_cell,
    columns=2,
    item_height=96.0,
    viewport_height=240.0,
    row_spacing=4.0,
    overscan=1,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=Some(_ => ()),
  )
  let wide : @core.View[Unit] = @views.lazy_grid(
    lazy_test_items(50),
    item => item,
    lazy_grid_test_cell,
    columns=2,
    item_height=96.0,
    viewport_height=240.0,
    row_spacing=4.0,
    overscan=3,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=Some(_ => ()),
  )
  // overscan 1 -> (3, 8): 1 + 6 + 1 = 8; overscan 3 -> (1, 10): 1 + 10 + 1 = 12.
  inspect(lazy_grid_rows(base).length(), content="8")
  inspect(lazy_grid_rows(wide).length(), content="12")
}

///|
test "lazy_grid empty items produce an empty list" {
  let view : @core.View[Unit] = @views.lazy_grid(
    lazy_test_items(0),
    item => item,
    lazy_grid_test_cell,
    columns=2,
    item_height=96.0,
    viewport_height=240.0,
    row_spacing=4.0,
    overscan=1,
    offset=@core.Point::new(x=0.0, y=0.0),
    on_scroll=Some(_ => ()),
  )
  let children = lazy_grid_rows(view)
  inspect(children.length(), content="0")
}
