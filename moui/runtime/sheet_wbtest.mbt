///|
fn sheet_test_spec(on_dismiss? : (() -> Unit)? = None) -> ViewSpec {
  ViewSpec::SheetSpec({
    key: None,
    content: test_label("Sheet").frame(width=120.0, height=40.0),
    presentation_mode: SheetPresentationMode::BottomSheet,
    background: Brush::solid(Color::white()),
    corner_radius: 12.0,
    shadow: None,
    on_dismiss,
  })
}

///|
test "bottom sheet positions content against bottom inset" {
  let layout = layout_spec(
    sheet_test_spec(),
    Rect::new(x=0.0, y=0.0, width=200.0, height=160.0),
  )
  inspect(layout.children.length(), content="1")
  inspect(layout.children[0].frame.origin.x, content="16")
  inspect(layout.children[0].frame.origin.y, content="104")
  inspect(layout.children[0].frame.size.width, content="168")
  inspect(layout.children[0].frame.size.height, content="40")
}

///|
test "sheet dismisses only when pointer up is outside content" {
  let dismiss_count = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=sheet_test_spec(
      on_dismiss=Some(() => dismiss_count.val = dismiss_count.val + 1),
    ),
    size=Size::new(width=200.0, height=160.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=120.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=120.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(dismiss_count.val, content="0")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(dismiss_count.val, content="1")
}

///|
test "sheet consumes inert content clicks before scrim" {
  let scrim_count = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::StackSpec({
      key: None,
      children: [
        ViewSpec::EmptySpec
        .background(Color::black())
        .on_tap(() => scrim_count.val = scrim_count.val + 1),
        sheet_test_spec(),
      ],
    }),
    size=Size::new(width=200.0, height=160.0),
  )
  let position = Point::new(x=40.0, y=120.0)
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position~, phase=PointerPhase::Down)),
  )
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position~, phase=PointerPhase::Up)),
  )
  inspect(scrim_count.val, content="0")
}
