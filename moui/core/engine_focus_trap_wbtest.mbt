///|
test "focus trap constrains tab traversal to trapped subtree" {
  let outside = State::new("")
  let first = State::new("")
  let second = State::new("")
  let after = State::new("")
  let trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_text_field(first.binding()),
      test_text_field(second.binding()),
    ],
  }).focus_trap()
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(outside.binding()),
        trap,
        test_text_field(after.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=220.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="c", text=Some("c"))))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="Tab", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="d", text=Some("d"))))
  inspect(outside.get(), content="")
  inspect(first.get(), content="ac")
  inspect(second.get(), content="bd")
  inspect(after.get(), content="")
}

///|
test "focus key targets keyed focusable elements" {
  let first = State::new("")
  let second = State::new("")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(first.binding()).key("first"),
        test_text_field(second.binding()).key("second"),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  assert_true(runtime.focus_key("second"))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("b")))
  assert_true(runtime.focus_key("first"))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("a")))
  inspect(first.get(), content="a")
  inspect(second.get(), content="b")
}

///|
test "focus key respects active focus trap" {
  let outside = State::new("")
  let trapped = State::new("")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(outside.binding()).key("outside"),
        ViewSpec::FlexSpec({
          key: None,
          axis: Axis::Vertical,
          spacing: 8.0,
          main_axis_alignment: MainStart,
          cross_axis_alignment: CrossStretch,
          children: [test_text_field(trapped.binding()).key("trapped")],
        }).focus_trap(),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  assert_true(runtime.focus_key("trapped"))
  assert_false(runtime.focus_key("outside"))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("x")))
  inspect(outside.get(), content="")
  inspect(trapped.get(), content="x")
}

///|
test "focus trap overrides tab accepting focus outside trapped subtree" {
  let outside = State::new("")
  let trapped = State::new("")
  let root_without_trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_tab_accepting_rich_text_editor(outside.binding()),
      test_text_field(trapped.binding()),
    ],
  })
  let root_with_trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_tab_accepting_rich_text_editor(outside.binding()),
      test_text_field(trapped.binding()).focus_trap(),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root=root_without_trap,
    size=Size::new(width=180.0, height=140.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("x")))
  runtime.set_root_spec(root_with_trap)
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("a")))
  inspect(outside.get(), content="x")
  inspect(trapped.get(), content="a")
}

///|
test "focus trap constrains pointer focus to trapped subtree" {
  let outside = State::new("")
  let first = State::new("")
  let second = State::new("")
  let after = State::new("")
  let trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_text_field(first.binding()),
      test_text_field(second.binding()),
    ],
  }).focus_trap()
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(outside.binding()),
        trap,
        test_text_field(after.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=160.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("a")))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("b")))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=104.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("c")))
  inspect(outside.get(), content="")
  inspect(first.get(), content="ab")
  inspect(second.get(), content="c")
  inspect(after.get(), content="")
}
