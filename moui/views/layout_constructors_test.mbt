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
