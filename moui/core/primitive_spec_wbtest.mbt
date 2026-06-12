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
    runtime.element_tree.find_keyed("custom") == Some(runtime.element_tree.id()),
  )
}

///|
test "text layout measures size baseline and caret positions" {
  let layout = TextSystem::fallback().measure_text(
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
test "fallback text system uses deterministic fixed advances for caret positions" {
  let ascii = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text="a", font=FontSpec::new(size=20.0)),
  )
  let digit = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text="1234", font=FontSpec::new(size=20.0)),
  )
  let cjk = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text="你", font=FontSpec::new(size=20.0)),
  )
  inspect(ascii.caret_positions[1], content="10")
  inspect(digit.caret_positions[4], content="40")
  inspect(cjk.caret_positions[1], content="10")
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
