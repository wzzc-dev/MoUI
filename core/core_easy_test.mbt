///|
test "geometry and constraints" {
  let rect = Rect::new(x=10.0, y=20.0, width=100.0, height=50.0)
  inspect(rect.contains(Point::new(x=30.0, y=40.0)), content="true")
  inspect(rect.contains(Point::new(x=200.0, y=40.0)), content="false")
  let size = Size::new(width=200.0, height=5.0).clamp({
    min: Size::new(width=10.0, height=10.0),
    max: Size::new(width=120.0, height=80.0),
  })
  assert_true(size == Size::new(width=120.0, height=10.0))
}

///|
test "paint commands" {
  let root = ViewNode::Label({
    text: "box",
    size: Size::new(width=20.0, height=10.0),
    color: Color::blue(),
  })
  let runtime = RuntimeState::new(
    root~,
    size=Size::new(width=40.0, height=30.0),
  )
  inspect(runtime.build_draw_commands().length(), content="2")
}
