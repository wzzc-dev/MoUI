///|
test "scroll_edge places content and both fades" {
  let content : @core.View[Unit] = @views.column([])
  let view : @core.View[Unit] = @views.scroll_edge(
    content,
    width=200.0,
    height=100.0,
    fade_height=20.0,
  )
  inspect(view.identity().kind, content="Stage")
  inspect(view.children().length(), content="3")
}

///|
test "scroll_edge can keep only the top fade" {
  let content : @core.View[Unit] = @views.column([])
  let view : @core.View[Unit] = @views.scroll_edge(
    content,
    width=200.0,
    height=100.0,
    top=true,
    bottom=false,
  )
  inspect(view.children().length(), content="2")
}

///|
test "scroll_edge with no fades is the content alone" {
  let content : @core.View[Unit] = @views.column([])
  let view : @core.View[Unit] = @views.scroll_edge(
    content,
    width=200.0,
    height=100.0,
    top=false,
    bottom=false,
  )
  inspect(view.children().length(), content="1")
}
