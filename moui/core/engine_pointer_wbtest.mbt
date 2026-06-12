///|
test "tap recognizer activates only pressed pointer up inside" {
  let down = recognize_button_tap(Normal, true, Down)
  assert_true(down.next_state == Pressed)
  inspect(down.activated, content="false")
  let move_inside = recognize_button_tap(Pressed, true, Move)
  assert_true(move_inside.next_state == Pressed)
  inspect(move_inside.activated, content="false")
  let up = recognize_button_tap(Pressed, true, Up)
  assert_true(up.next_state == Hovered)
  inspect(up.activated, content="true")
  let cancel = recognize_button_tap(Pressed, false, Cancel)
  assert_true(cancel.next_state == Normal)
  inspect(cancel.activated, content="false")
}

///|
test "runtime dynamic button activates after press-preserving move inside" {
  let clicks = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(_ctx => {
      ViewSpec::ButtonSpec({
        key: None,
        text: "Tap \{clicks.val}",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: Some(() => clicks.val = clicks.val + 1),
      })
    }),
    size=Size::new(width=100.0, height=40.0),
  )
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
        phase=PointerPhase::Move,
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
}

///|
test "active pointer capture handles no-op move without falling through siblings" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::ButtonSpec({
        key: None,
        text: "Bottom",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
      ViewSpec::ButtonSpec({
        key: None,
        text: "Top",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
    ],
  })
  let element = mount_view_spec(spec)
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=84.0))
  element.children[0].control.button_state = Pressed
  element.children[1].control.button_state = Pressed
  let result = element.dispatch_pointer(
    PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Move),
    render,
  )
  inspect(result.changed, content="false")
  assert_true(element.children[1].control.button_state == Pressed)
  assert_true(element.children[0].control.button_state == Pressed)
}

///|
test "runtime caches active pointer capture between down and up" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::ButtonSpec({
        key: None,
        text: "Bottom",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
      ViewSpec::ButtonSpec({
        key: None,
        text: "Top",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=100.0, height=84.0),
  )
  let top_id = runtime.element_tree.root.children[1].id
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Down)),
  )
  assert_true(runtime.active_pointer_capture == Some(top_id))
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Move)),
  )
  assert_true(runtime.active_pointer_capture == Some(top_id))
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Up)),
  )
  assert_true(runtime.active_pointer_capture is None)
}

///|
test "runtime pointer move without cached capture does not scan stale siblings" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::ButtonSpec({
        key: None,
        text: "Bottom",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
      ViewSpec::ButtonSpec({
        key: None,
        text: "Top",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=100.0, height=84.0),
  )
  runtime.element_tree.root.children[0].control.button_state = Pressed
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Move)),
  )
  assert_true(
    runtime.element_tree.root.children[0].control.button_state == Pressed,
  )
}

///|
test "button pressed paint keeps configured foreground" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Ghost",
      size: Size::new(width=100.0, height=40.0),
      font: FontSpec::new(size=16.0, weight=600),
      foreground: Color::black(),
      background: Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
      hovered_background: Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
      pressed_background: Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: None,
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  guard runtime.build_draw_commands()
    is [_, _, DrawText({ text: "Ghost", color, .. })] else {
    fail("expected pressed button text")
  }
  assert_true(color == Color::black())
}

///|
test "runtime dynamic builder rebuilds on draw frame flush after activated pointer" {
  let clicks = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(_ctx => {
      ViewSpec::ButtonSpec({
        key: None,
        text: "Tap \{clicks.val}",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: Some(() => clicks.val = clicks.val + 1),
      })
    }),
    size=Size::new(width=100.0, height=40.0),
  )
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
  guard runtime.build_draw_commands() is [_, _, DrawText({ text: "Tap 1", .. })] else {
    fail("expected rebuilt button label")
  }
  inspect(runtime.needs_rebuild, content="false")
}

///|
test "hit test path records root to topmost leaf" {
  let root = ViewSpec::StackSpec({
    key: None,
    children: [test_label("Bottom", key="bottom"), test_label("Top", key="top")],
  })
  let element = mount_view_spec(root)
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=40.0))
  let path = element.hit_test_path(Point::new(x=10.0, y=10.0), render).path
  inspect(path.length(), content="2")
  assert_true(path[0].element_id == element.id)
  assert_true(path[1].element_id == element.children[1].id)
  inspect(path[1].local_position.x, content="10")
}
