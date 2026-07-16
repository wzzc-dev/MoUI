///|
test "layout constructors expose stable public identities" {
  let leaf : @core.View[Unit] = text("leaf")
  let row_view : @core.View[Unit] = row(
    [leaf, spacer(min_length=8.0)],
    spacing=4.0,
  )
  let column_view : @core.View[Unit] = column(
    [text("a"), text("b")],
    spacing=6.0,
  )
  let stack_view : @core.View[Unit] = stack([text("base"), text("overlay")])
  let spacer_view : @core.View[Unit] = spacer()
  let title : @core.View[Unit] = text("title")
  inspect(row_view.identity().kind, content="Flex")
  inspect(column_view.identity().kind, content="Flex")
  inspect(stack_view.identity().kind, content="Stack")
  inspect(spacer_view.identity().kind, content="Spacer")
  inspect(title.identity().kind, content="Text")
  assert_true(row_view.children().length() == 2)
  assert_true(column_view.children().length() == 2)
  assert_true(stack_view.children().length() == 2)
}

///|
test "scroll_to_index computes offset from item stride" {
  let state = @core.ScrollState::new()
  let intent = scroll_to_index(state, index=3, item_height=20.0, spacing=2.0)
  inspect(intent.offset.y, content="66")
  inspect(state.offset().y, content="66")
  let zero = scroll_to_index(state, index=0, item_height=44.0)
  inspect(zero.offset.y, content="0")
}
