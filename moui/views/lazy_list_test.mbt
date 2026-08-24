///|
/// Helper: builds `count` string items.
fn lazy_test_items(count : Int) -> Array[String] {
  let items : Array[String] = []
  for i in 0..<count {
    items.push("item-\{i}")
  }
  items
}

///|
/// Helper: a text row for a string item.
fn lazy_test_row(item : String) -> @core.View[Unit] {
  @views.text(item)
}

///|
/// Helper: a fixed-height text row matching the item stride used below.
fn lazy_test_row_fixed(item : String) -> @core.View[Unit] {
  @views.text(item, height=44.0)
}

///|
/// Layouts a single view in a loose box, measuring children recursively the
/// way the runtime layout pass does (parent layout consumes child sizes).
fn lazy_layout_height(view : @core.View[Unit]) -> Double {
  lazy_measure(
    view,
    @core.Constraints::loose(@core.Size::new(width=10000.0, height=10000.0)),
  ).height
}

///|
fn lazy_measure(
  view : @core.View[Unit],
  constraints : @core.Constraints,
) -> @core.Size {
  let child_constraints = view.child_constraints(constraints)
  let children = view.children()
  let result = view.layout({
    constraints,
    child_sizes: children.map(child => lazy_measure(child, child_constraints)),
    child_flex_weights: children.map(child => child.flex_weight()),
    anchor_frames: [],
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  })
  constraints.constrain(result.size)
}

///|

///|
/// Unwraps the scroll_view -> list wrapper to reach the windowed row children.
fn lazy_list_rows(view : @core.View[Unit]) -> Array[@core.View[Unit]] {
  view.children()[0].children()
}

///|
test "lazy_list windows to visible rows only" {
  // stride = 46 (44 + 2); viewport 240 shows rows 0..6 with overscan 1.
  // Window (0, 6): no before spacer, 7 rows, after spacer -> 8 children.
  let view : @core.View[Unit] = @views.lazy_list(
    lazy_test_items(100),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    offset=@core.Point::new(x=0.0, y=0.0),
    on_scroll=_ => (),
  )
  let children = lazy_list_rows(view)
  inspect(children.length(), content="8")
  inspect(children[0].identity().kind, content="Text")
  inspect(children[7].identity().kind, content="Spacer")
}

///|
test "lazy_list mid-scroll window pads both sides" {
  // offset.y = 460 = row 10 top; window (9, 16) with overscan 1:
  // before spacer + 8 rows + after spacer -> 10 children.
  let view : @core.View[Unit] = @views.lazy_list(
    lazy_test_items(100),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=_ => (),
  )
  let children = lazy_list_rows(view)
  inspect(children.length(), content="10")
  inspect(children[0].identity().kind, content="Spacer")
  inspect(children[1].identity().kind, content="Text")
  inspect(children[8].identity().kind, content="Text")
  inspect(children[9].identity().kind, content="Spacer")
  // Rows carry the application-provided keys so reconcile can reuse elements.
  match children[1].identity().key {
    Some(_) => ()
    None => fail("expected a key on windowed rows")
  }
}

///|
test "lazy_list at the very end collapses onto last rows" {
  // Far-past-end scroll collapses the window onto the last row: before
  // spacer + 1 row + no after spacer -> 2 children.
  let view : @core.View[Unit] = @views.lazy_list(
    lazy_test_items(100),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    offset=@core.Point::new(x=0.0, y=10000.0),
    on_scroll=_ => (),
  )
  let children = lazy_list_rows(view)
  inspect(children.length(), content="2")
  inspect(children[0].identity().kind, content="Spacer")
  inspect(children[1].identity().kind, content="Text")
}

///|
test "lazy_list empty items produce an empty list" {
  let view : @core.View[Unit] = @views.lazy_list(
    lazy_test_items(0),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    offset=@core.Point::new(x=0.0, y=0.0),
    on_scroll=_ => (),
  )
  let children = view.children()
  inspect(children.length(), content="1")
  inspect(children[0].children().length(), content="0")
}

///|
test "virtual_list overscan widens the window" {
  let base : @core.View[Unit] = @views.virtual_list(
    lazy_test_items(100),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    overscan=1,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=_ => (),
  )
  let wide : @core.View[Unit] = @views.virtual_list(
    lazy_test_items(100),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    overscan=3,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=_ => (),
  )
  // overscan 1 -> (9, 16): 1 + 8 + 1 = 10; overscan 3 -> (7, 18): 1 + 12 + 1 = 14.
  inspect(lazy_list_rows(base).length(), content="10")
  inspect(lazy_list_rows(wide).length(), content="14")
}

///|
test "lazy_list spacers compensate list inter-child spacing" {
  // stride = 46 (44 + 2); offset.y = 460 = row 10 top -> window (9, 16) with
  // overscan 1: before spacer + 8 fixed-height rows + after spacer.
  // Spacer heights must subtract one `spacing` because `list` inserts the
  // gap between the spacer and the adjacent row: before = 9*46 - 2 = 412,
  // after = 83*46 - 2 = 3816, so the total layout height equals the full
  // content height 100*44 + 99*2 = 4598.
  let view : @core.View[Unit] = @views.lazy_list(
    lazy_test_items(100),
    item => item,
    lazy_test_row_fixed,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    offset=@core.Point::new(x=0.0, y=460.0),
    on_scroll=_ => (),
  )
  let children = lazy_list_rows(view)
  inspect(children.length(), content="10")
  inspect(lazy_layout_height(children[0]).to_int(), content="412")
  inspect(lazy_layout_height(children[1]).to_int(), content="44")
  inspect(lazy_layout_height(children[8]).to_int(), content="44")
  inspect(lazy_layout_height(children[9]).to_int(), content="3816")
  // Total = spacers + rows + 9 inter-child gaps.
  let total = 412.0 + 8.0 * 44.0 + 3816.0 + 9.0 * 2.0
  inspect(total.to_int(), content="4598")
}

///|
test "virtual_list empty state" {
  let with_empty : @core.View[Unit] = @views.virtual_list(
    lazy_test_items(0),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    overscan=1,
    empty=Some(@views.text("nothing here")),
    offset=@core.Point::new(x=0.0, y=0.0),
    on_scroll=_ => (),
  )
  let empty_children = with_empty.children()
  inspect(empty_children.length(), content="1")
  inspect(empty_children[0].identity().kind, content="Text")

  let without : @core.View[Unit] = @views.virtual_list(
    lazy_test_items(0),
    item => item,
    lazy_test_row,
    item_height=44.0,
    viewport_height=240.0,
    spacing=2.0,
    overscan=1,
    offset=@core.Point::new(x=0.0, y=0.0),
    on_scroll=_ => (),
  )
  let none_children = without.children()
  inspect(none_children.length(), content="1")
  inspect(none_children[0].children().length(), content="0")
}
