///|
test "nested layout and hit test" {
  let child = ViewSpec::TextSpec({
    key: None,
    text: "a",
    size: Size::new(width=20.0, height=10.0),
    font: FontSpec::new(size=16.0, weight=500),
    color: Color::gray(),
  })
  let root = ViewSpec::PaddingSpec({ key: None, insets: Insets::all(5.0), child })
  let layout = layout_spec(
    root,
    Rect::new(x=0.0, y=0.0, width=100.0, height=50.0),
  )
  inspect(hit_test(layout, Point::new(x=10.0, y=10.0)), content="true")
  inspect(hit_test(layout, Point::new(x=101.0, y=10.0)), content="false")
  inspect(layout.children.length(), content="1")
}

///|
test "runtime event marks redraw" {
  let root = ViewSpec::EmptySpec
  let runtime = RuntimeState::new_spec(
    root~,
    size=Size::new(width=1.0, height=1.0),
  )
  runtime.dispatch_event(Redraw(Initial))
  inspect(runtime.needs_redraw, content="false")
  runtime.dispatch_event(Resize(Size::new(width=10.0, height=20.0)))
  inspect(runtime.needs_redraw, content="true")
  assert_true(runtime.size == Size::new(width=10.0, height=20.0))
}

///|
test "button click requires press then release inside" {
  let clicks = Ref(0)
  let root = ViewSpec::ButtonSpec({
    key: None,
    text: "tap",
    size: Size::new(width=100.0, height=40.0),
    font: FontSpec::new(size=16.0, weight=600),
    foreground: Color::black(),
    background: Brush::solid(Color::gray()),
    hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
    pressed_background: Brush::solid(Color::blue()),
    border: None,
    border_width: 0.0,
    shadow: None,
    corner_radius: 0.0,
    on_click: Some(() => clicks.val = clicks.val + 1),
  })
  let runtime = RuntimeState::new_spec(
    root~,
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="0")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="1")
  inspect(runtime.needs_rebuild, content="true")
}
