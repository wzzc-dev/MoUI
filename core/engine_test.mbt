///|
fn test_label(text : String, key? : String) -> ViewSpec {
  let spec = ViewSpec::TextSpec({
    key: None,
    text,
    size: Size::new(width=80.0, height=20.0),
    font: FontSpec::new(size=16.0, weight=500),
    color: Color::black(),
  })
  match key {
    Some(key) => spec.key(key)
    None => spec
  }
}

///|
fn test_text_field(
  value : Binding[String],
  on_submit? : (() -> Unit)? = None,
) -> ViewSpec {
  ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder: "Type",
    size: Size::new(width=120.0, height=40.0),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_submit,
  })
}

///|
test "engine mounts view spec into element and render trees" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [test_label("A"), test_label("B")],
  })
  let element = mount_view_spec(spec)
  inspect(element.children.length(), content="2")
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=80.0))
  inspect(render.children.length(), content="2")
  inspect(render.children[1].frame.origin.y, content="24")
}

///|
test "engine applies flex main and cross axis alignment" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 0.0,
    main_axis_alignment: MainCenter,
    cross_axis_alignment: CrossEnd,
    children: [test_label("A")],
  })
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
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_label("A"),
      ViewSpec::SpacerSpec({ key: None, min_length: 0.0, weight: 1.0 }),
      test_label("B"),
    ],
  })
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=240.0, height=40.0),
  )
  inspect(render.children[1].frame.size.width, content="80")
  inspect(render.children[2].frame.origin.x, content="160")
}

///|
test "engine allocates flex spacer space by weight" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      ViewSpec::SpacerSpec({ key: None, min_length: 0.0, weight: 1.0 }),
      ViewSpec::SpacerSpec({ key: None, min_length: 0.0, weight: 3.0 }),
    ],
  })
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=200.0, height=20.0),
  )
  inspect(render.children[0].frame.size.width, content="50")
  inspect(render.children[1].frame.origin.x, content="50")
  inspect(render.children[1].frame.size.width, content="150")
}

///|
test "frame spec constrains child layout" {
  let spec = test_label("A").frame(width=90.0, height=30.0)
  let layout = layout_spec(
    spec,
    Rect::new(x=0.0, y=0.0, width=200.0, height=100.0),
  )
  inspect(layout.children[0].frame.size.width, content="90")
  inspect(layout.children[0].frame.size.height, content="30")
}

///|
test "engine reconciles keyed children by identity" {
  let old = mount_view_spec(
    ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("A", key="a"), test_label("B", key="b")],
    }),
  )
  let old_a = old.children[0].id
  let old_b = old.children[1].id
  let next = reconcile_element(
    old,
    ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("B", key="b"), test_label("A", key="a")],
    }),
  )
  assert_true(next.children[0].id == old_b)
  assert_true(next.children[1].id == old_a)
}

///|
test "runtime exposes mount rebuild layout and paint passes" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.mount(test_label("B"))
  guard runtime.paint_pass() is [_, DrawText({ text: "B", .. })] else {
    fail("expected mounted label")
  }
  runtime.root_spec = test_label("C")
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
test "custom binding delegates get and set" {
  let value = Ref(false)
  let binding = Binding::new(get=() => value.val, set=next => value.val = next)
  inspect(binding.get(), content="false")
  binding.set(true)
  inspect(value.val, content="true")
  binding.update(current => !current)
  inspect(value.val, content="false")
}

///|
test "image spec emits draw image command" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ImageSpec({
      key: None,
      source: "logo.png",
      size: Some(Size::new(width=48.0, height=32.0)),
      opacity: 0.75,
      corner_radius: 0.0,
      fit: ImageFit::Contain,
    }),
    size=Size::new(width=100.0, height=80.0),
  )
  guard runtime.build_draw_commands()
    is [
      _,
      DrawImage(
        {
          source: "logo.png",
          opacity: 0.75,
          fit: ImageFit::Contain,
          frame: { size: { width: 48.0, height: 32.0 }, .. },
        }
      ),
    ] else {
    fail("expected image draw command")
  }
}

///|
test "custom spec measures paints and exposes semantics" {
  let spec = ViewSpec::custom(
    measure=constraints => {
      constraints.constrain(Size::new(width=32.0, height=20.0))
    },
    paint=frame => {
      [
        DrawCommand::FillRoundedRectBrush(
          RoundedRect::new(rect=frame, radius=3.0),
          Brush::solid(Color::blue()),
        ),
      ]
    },
    semantics_role=SemanticsRole::Group,
    semantics_label="Custom swatch",
  ).key("custom")
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=80.0, height=60.0),
  )
  let measured = runtime.element_tree.measure(
    Constraints::loose(Size::new(width=40.0, height=30.0)),
  )
  inspect(measured.size.width, content="32")
  assert_true(
    runtime
    .build_draw_commands()
    .any(command => {
      command is DrawCommand::FillRoundedRectBrush(_, Brush::Solid(_))
    }),
  )
  let semantics = runtime.semantics()
  inspect(semantics.label, content="Custom swatch")
  assert_true(
    runtime.element_tree.find_keyed("custom") == Some(runtime.element_tree.id),
  )
}

///|
test "text layout measures size baseline and caret positions" {
  let layout = measure_text_layout(
    TextLayoutInput::new(
      text="abcd",
      font=FontSpec::new(size=20.0),
      max_width=30.0,
    ),
  )
  inspect(layout.size.width, content="30")
  inspect(layout.size.height, content="25")
  inspect(layout.baseline, content="16")
  inspect(layout.caret_positions.length(), content="5")
  inspect(layout.caret_positions[4], content="30")
}

///|
test "text layout uses cosmic glyph advances for caret positions" {
  let ascii = measure_text_layout(
    TextLayoutInput::new(text="a", font=FontSpec::new(size=20.0)),
  )
  let digit = measure_text_layout(
    TextLayoutInput::new(text="1234", font=FontSpec::new(size=20.0)),
  )
  let cjk = measure_text_layout(
    TextLayoutInput::new(text="你", font=FontSpec::new(size=20.0)),
  )
  inspect(ascii.caret_positions[1], content="20")
  inspect(digit.caret_positions[4], content="80")
  inspect(cjk.caret_positions[1], content="20")
}

///|
test "checkbox toggles binding and exposes semantics" {
  let checked = State::new(false)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::CheckboxSpec({
      key: None,
      label: "Buy milk",
      checked: checked.binding(),
      font: FontSpec::new(size=16.0, weight=400),
      foreground: Color::black(),
      check_color: Color::blue(),
      size: Size::new(width=20.0, height=32.0),
    }),
    size=Size::new(width=180.0, height=48.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(checked.get(), content="true")
  let semantics = runtime.semantics()
  assert_true(semantics.role == SemanticsRole::Checkbox)
  inspect(semantics.state.checked, content="true")
}

///|
test "dirty queue records and clears runtime work" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
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
test "runtime dynamic builder rebuilds after activated pointer" {
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
  inspect(runtime.needs_rebuild, content="false")
  guard runtime.build_draw_commands() is [_, _, DrawText({ text: "Tap 1", .. })] else {
    fail("expected rebuilt button label")
  }
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

///|
test "runtime focuses text field and keyboard edits binding" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
    ),
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
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(state.binding()),
        ViewSpec::ButtonSpec({
          key: None,
          text: "Outside",
          size: Size::new(width=120.0, height=40.0),
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
    }),
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

///|
test "pointer dispatch chooses topmost overlapping child" {
  let bottom_clicks = Ref(0)
  let top_clicks = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: -40.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStart,
      children: [
        ViewSpec::ButtonSpec({
          key: None,
          text: "Bottom",
          size: Size::new(width=120.0, height=60.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => bottom_clicks.val = bottom_clicks.val + 1),
        }),
        ViewSpec::ButtonSpec({
          key: None,
          text: "Top",
          size: Size::new(width=120.0, height=60.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => top_clicks.val = top_clicks.val + 1),
        }),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=30.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=30.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(bottom_clicks.val, content="0")
  inspect(top_clicks.val, content="1")
}

///|
test "tab traverses text field focus forward and backward" {
  let first = State::new("")
  let second = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(first.binding()),
        test_text_field(second.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="Tab", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="c", text=Some("c"))))
  inspect(first.get(), content="ac")
  inspect(second.get(), content="b")
}

///|
test "text input events edit at caret and support delete ranges" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(TextInput(InsertText("Z")))
  inspect(state.get(), content="abZc")
  runtime.dispatch_event(TextInput(DeleteRange(TextRange::new(start=1, end=2))))
  inspect(state.get(), content="aZc")
}

///|
test "text field keyboard selection replaces and deletes ranges" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("abcd")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
  match input.selection {
    Some(selection) => {
      inspect(selection.normalized().start, content="2")
      inspect(selection.normalized().end, content="4")
    }
    None => fail("expected selection")
  }
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abX")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="End", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="")
}

///|
test "text field select all shortcut replaces unicode text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("你好abc")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="5")
  match input.selection {
    Some(selection) => {
      inspect(selection.normalized().start, content="0")
      inspect(selection.normalized().end, content="5")
    }
    None => fail("expected select all range")
  }
  runtime.dispatch_event(TextInput(InsertText("done")))
  inspect(state.get(), content="done")
}

///|
test "text field command undo and redo restore edit history" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("a")))
  runtime.dispatch_event(TextInput(InsertText("b")))
  inspect(state.get(), content="ab")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(state.get(), content="a")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(state.get(), content="ab")
}

///|
test "text field keyboard undo and redo use edit history" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("ab")))
  runtime.dispatch_event(TextInput(InsertText("c")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="z", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  inspect(state.get(), content="ab")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="z",
        modifiers=KeyModifiers::new(shift=true, meta=true),
      ),
    ),
  )
  inspect(state.get(), content="abc")
}

///|
test "text field selection draws highlight before text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  guard commands[3] is FillRect(_, color) else {
    fail("expected selection highlight")
  }
  inspect(color.a, content="0.18")
  guard commands[4] is DrawText({ text: "abc", .. }) else {
    fail("expected text after highlight")
  }
}

///|
test "ime composition updates paint preview and commit into text field" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(CompositionUpdate(CompositionUpdate::new(text="ni", cursor=None))),
  )
  let preview = runtime.build_draw_commands()
  guard preview[3] is DrawText({ text: "ni", align: TextAlign::TextStart, .. }) else {
    fail("expected composition preview")
  }
  inspect(state.get(), content="")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="你")
  let committed = runtime.build_draw_commands()
  guard committed[3]
    is DrawText({ text: "你", align: TextAlign::TextStart, .. }) else {
    fail("expected committed text")
  }
}

///|
test "ime composition replaces selected text and undo restores selection edit" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abcd")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(CompositionUpdate::new(text="你", cursor=None)),
    ),
  )
  inspect(state.get(), content="abcd")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="ab你")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  inspect(state.get(), content="abcd")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  inspect(state.get(), content="ab你")
}

///|
test "text field aligns rendered text with caret origin" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("abc")))
  let commands = runtime.build_draw_commands()
  guard commands[3]
    is DrawText({ frame: text_frame, align: TextAlign::TextStart, .. }) else {
    fail("expected left-aligned text field text")
  }
  guard commands[4] is FillRect(cursor, _) else {
    fail("expected focused text field cursor")
  }
  let layout = measure_text_layout(
    TextLayoutInput::new(
      text="abc",
      font=FontSpec::new(size=16.0, weight=400),
      max_width=text_frame.size.width,
    ),
  )
  assert_true(text_frame.origin.x == 10.0)
  assert_true(
    cursor.origin.x == text_frame.origin.x + layout.caret_positions[3],
  )
}

///|
test "text field caret follows ime composition cursor" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="ni",
          cursor=Some(TextRange::new(start=1, end=1)),
        ),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  guard commands[4] is FillRect(cursor, _) else {
    fail("expected focused text field cursor")
  }
  let layout = measure_text_layout(
    TextLayoutInput::new(
      text="ni",
      font=FontSpec::new(size=16.0, weight=400),
      max_width=140.0,
    ),
  )
  inspect(cursor.origin.x, content="26")
  assert_true(cursor.origin.x == 10.0 + layout.caret_positions[1])
}

///|
test "runtime exposes focused text input state for hosts" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  inspect(runtime.focused_text_input().focused, content="false")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  inspect(input.text, content="abc")
  inspect(input.caret, content="2")
  assert_true(input.frame == Rect::new(x=0.0, y=0.0, width=160.0, height=60.0))
  assert_true(input.caret_rect.origin.x > input.frame.origin.x)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}

///|
test "focused text input caret rect follows ime composition cursor" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="你",
          cursor=Some(TextRange::new(start=1, end=1)),
        ),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="0")
  match input.composition_cursor {
    Some(cursor) => inspect(cursor.end, content="1")
    None => fail("expected composition cursor")
  }
  inspect(input.caret_rect.origin.x, content="26")
}

///|
test "buttons participate in focus traversal and keyboard activation" {
  let clicks = Ref(0)
  let value = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        ViewSpec::ButtonSpec({
          key: None,
          text: "Run",
          size: Size::new(width=120.0, height=40.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => clicks.val = clicks.val + 1),
        }),
        test_text_field(value.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  inspect(clicks.val, content="1")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="x", text=Some("x"))))
  inspect(value.get(), content="x")
}

///|
test "ime delete surrounding removes text around caret" {
  let state = State::new("abc")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(TextInput(DeleteSurrounding(1, 1)))
  inspect(state.get(), content="a")
}
