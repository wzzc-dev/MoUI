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

///|
test "grid lays children into fixed columns" {
  let grid = ViewSpec::GridSpec({
    key: None,
    columns: 2,
    row_spacing: 4.0,
    column_spacing: 8.0,
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
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
      ViewSpec::TextSpec({
        key: None,
        text: "C",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
    ],
  })
  let layout = layout_spec(
    grid,
    Rect::new(x=0.0, y=0.0, width=108.0, height=80.0),
  )
  inspect(layout.children.length(), content="3")
  inspect(layout.children[0].frame.size.width, content="50")
  inspect(layout.children[1].frame.origin.x, content="58")
  inspect(layout.children[2].frame.origin.y, content="24")
}

///|
test "list lays out keyed rows and reconcile preserves keyed identity" {
  let first = ViewSpec::TextSpec({
    key: None,
    text: "First",
    size: Size::new(width=40.0, height=20.0),
    font: FontSpec::new(),
    color: Color::black(),
  }).key("first")
  let second = ViewSpec::TextSpec({
    key: None,
    text: "Second",
    size: Size::new(width=40.0, height=30.0),
    font: FontSpec::new(),
    color: Color::black(),
  }).key("second")
  let old = mount_view_spec(
    ViewSpec::ListSpec({ key: None, spacing: 6.0, children: [first, second] }),
  )
  let first_id = old.children[0].id
  let second_id = old.children[1].id
  let next = reconcile_element(
    old,
    ViewSpec::ListSpec({ key: None, spacing: 6.0, children: [second, first] }),
  )
  assert_true(next.children[0].id == second_id)
  assert_true(next.children[1].id == first_id)
  let layout = next.render(Rect::new(x=0.0, y=0.0, width=120.0, height=80.0))
    .to_layout_result()
  inspect(layout.children[1].frame.origin.y, content="36")
}
