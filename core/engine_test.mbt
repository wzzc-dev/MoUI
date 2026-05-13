///|
fn test_label(text : String, key? : String) -> ViewNode {
  let node = ViewNode::Label({
    text,
    size: Size::new(width=80.0, height=20.0),
    color: Color::black(),
  })
  match key {
    Some(key) => node.key(key)
    None => node
  }
}

///|
test "engine mounts view spec into element and render trees" {
  let spec = ViewNode::Flex({
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [test_label("A"), test_label("B")],
  }).to_spec()
  let element = mount_view_spec(spec)
  inspect(element.children.length(), content="2")
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=80.0))
  inspect(render.children.length(), content="2")
  inspect(render.children[1].frame.origin.y, content="24")
}

///|
test "engine applies flex main and cross axis alignment" {
  let spec = ViewNode::Flex({
    axis: Axis::Vertical,
    spacing: 0.0,
    main_axis_alignment: MainCenter,
    cross_axis_alignment: CrossEnd,
    children: [test_label("A")],
  }).to_spec()
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
  )
  inspect(render.children[0].frame.origin.x, content="20")
  inspect(render.children[0].frame.origin.y, content="40")
  inspect(render.children[0].frame.size.width, content="80")
  inspect(render.children[0].frame.size.height, content="20")
}

///|
test "engine reconciles keyed children by identity" {
  let old = mount_view_spec(
    ViewNode::Flex({
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("A", key="a"), test_label("B", key="b")],
    }).to_spec(),
  )
  let old_a = old.children[0].id
  let old_b = old.children[1].id
  let next = reconcile_element(
    old,
    ViewNode::Flex({
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("B", key="b"), test_label("A", key="a")],
    }).to_spec(),
  )
  assert_true(next.children[0].id == old_b)
  assert_true(next.children[1].id == old_a)
}

///|
test "runtime exposes mount rebuild layout and paint passes" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A").to_spec(),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.mount(test_label("B").to_spec())
  guard runtime.paint_pass() is [_, DrawText({ text: "B", .. })] else {
    fail("expected mounted label")
  }
  runtime.root_spec = test_label("C").to_spec()
  runtime.needs_rebuild = true
  runtime.rebuild()
  guard runtime.paint_pass() is [_, DrawText({ text: "C", .. })] else {
    fail("expected rebuilt label")
  }
  runtime.dispatch_event(Resize(Size::new(width=120.0, height=60.0)))
  inspect(runtime.needs_layout, content="true")
  runtime.layout_pass()
  inspect(runtime.needs_layout, content="false")
}

///|
test "state slot version increments on set and update" {
  let slot = StateSlot::new(1)
  inspect(slot.version, content="0")
  slot.set(2)
  inspect(slot.get(), content="2")
  inspect(slot.version, content="1")
  slot.update(value => value + 1)
  inspect(slot.get(), content="3")
  inspect(slot.version, content="2")
}

///|
test "runtime dynamic builder rebuilds after activated pointer" {
  let clicks = Ref::new(0)
  let runtime = RuntimeState::new_dynamic(
    root=() => {
      ViewNode::Button({
        text: "Tap \{clicks.val}",
        size: Size::new(width=100.0, height=40.0),
        state: ButtonState::Normal,
        on_click: Some(() => clicks.val = clicks.val + 1),
      })
    },
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
  inspect(runtime.needs_rebuild, content="false")
  guard runtime.build_draw_commands() is [_, _, DrawText({ text: "Tap 1", .. })] else {
    fail("expected rebuilt button label")
  }
}
