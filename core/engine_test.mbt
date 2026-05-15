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
fn test_text_field(
  value : Binding[String],
  on_submit? : (() -> Unit)? = None,
) -> ViewNode {
  ViewNode::TextField({
    value,
    placeholder: "Type",
    size: Size::new(width=120.0, height=40.0),
    on_submit,
  })
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
test "engine allocates remaining flex space to spacers" {
  let spec = ViewNode::Flex({
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_label("A"),
      ViewNode::Spacer({ min_length: 0.0 }),
      test_label("B"),
    ],
  }).to_spec()
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=240.0, height=40.0),
  )
  inspect(render.children[1].frame.size.width, content="80")
  inspect(render.children[2].frame.origin.x, content="160")
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
test "state and binding share updates" {
  let state = State::new(1)
  let binding = state.binding()
  binding.set(2)
  inspect(state.get(), content="2")
  binding.update(value => value + 3)
  inspect(state.get(), content="5")
  inspect(state.version(), content="2")
}

///|
test "dirty queue records and clears runtime work" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A").to_spec(),
    size=Size::new(width=100.0, height=40.0),
  )
  inspect(runtime.dirty_count(), content="0")
  runtime.mark_dirty(runtime.element_tree.id)
  runtime.mark_dirty(runtime.element_tree.id)
  inspect(runtime.dirty_count(), content="1")
  ignore(runtime.build_draw_commands())
  inspect(runtime.dirty_count(), content="0")
}

///|
test "tap recognizer activates only pressed pointer up inside" {
  let down = recognize_button_tap(Normal, true, Down)
  assert_true(down.next_state == Pressed)
  inspect(down.activated, content="false")
  let up = recognize_button_tap(Pressed, true, Up)
  assert_true(up.next_state == Hovered)
  inspect(up.activated, content="true")
  let cancel = recognize_button_tap(Pressed, false, Cancel)
  assert_true(cancel.next_state == Normal)
  inspect(cancel.activated, content="false")
}

///|
test "runtime dynamic builder rebuilds after activated pointer" {
  let clicks = Ref(0)
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

///|
test "runtime focuses text field and keyboard edits binding" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()).to_spec(),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  inspect(state.get(), content="")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  inspect(state.get(), content="ab")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="a")
}

///|
test "text field submit is triggered by enter" {
  let state = State::new("Task")
  let submits = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=test_text_field(
      state.binding(),
      on_submit=Some(() => submits.val = submits.val + 1),
    ).to_spec(),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  inspect(submits.val, content="1")
  inspect(state.get(), content="Task")
}

///|
test "clicking outside text field clears focus" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewNode::Flex({
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(state.binding()),
        ViewNode::Button({
          text: "Outside",
          size: Size::new(width=120.0, height=40.0),
          state: ButtonState::Normal,
          on_click: None,
        }),
      ],
    }).to_spec(),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=58.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  inspect(state.get(), content="a")
}
