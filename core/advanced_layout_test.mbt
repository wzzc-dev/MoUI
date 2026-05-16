///|
test "stack lays children over the same frame in paint order" {
  let stack = ViewSpec::StackSpec({
    key: None,
    children: [
      ViewSpec::TextSpec({
        key: None,
        text: "A",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
      ViewSpec::TextSpec({
        key: None,
        text: "B",
        size: Size::new(width=20.0, height=10.0),
        font: FontSpec::new(),
        color: Color::blue(),
      }),
    ],
  })
  let layout = layout_spec(
    stack,
    Rect::new(x=0.0, y=0.0, width=100.0, height=80.0),
  )
  inspect(layout.children.length(), content="2")
  assert_true(layout.children[0].frame == layout.frame)
  assert_true(layout.children[1].frame == layout.frame)
}

///|
test "scroll view emits clip and offsets child frame" {
  let scroll = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=12.0),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    child: ViewSpec::TextSpec({
      key: None,
      text: "Scrolled",
      size: Size::new(width=120.0, height=80.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let render = mount_view_spec(scroll).render(
    Rect::new(x=5.0, y=6.0, width=80.0, height=40.0),
  )
  guard render.paint_commands is [PushClip(_), PopClip] else {
    fail("expected scroll clip commands")
  }
  inspect(render.children[0].frame.origin.y, content="-6")
}
