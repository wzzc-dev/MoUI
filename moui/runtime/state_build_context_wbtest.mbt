///|
test "build context watch rebuilds and replaces old subscription" {
  let state = State::new(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      ViewSpec::TextSpec({
        key: None,
        text: "Value: \{ctx.watch(state)}",
        size: Size::new(width=100.0, height=24.0),
        font: FontSpec::new(size=16.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  state.set(1)
  inspect(runtime.needs_rebuild, content="true")
  guard runtime.build_draw_commands() is [_, DrawText({ text: "Value: 1", .. })] else {
    fail("expected rebuilt text")
  }
  state.set(2)
  guard runtime.build_draw_commands() is [_, DrawText({ text: "Value: 2", .. })] else {
    fail("expected rebuilt text after second state change")
  }
}

///|
test "build context binding subscribes control state" {
  let state = State::new("")
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      ViewSpec::TextFieldSpec({
        key: None,
        value: ctx.binding(state),
        placeholder: "",
        size: Size::new(width=120.0, height=32.0),
        font: FontSpec::new(size=16.0, weight=400),
        foreground: Color::black(),
        placeholder_color: Color::gray(),
        background: Brush::solid(Color::white()),
        border: Some(
          BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0),
        ),
        focused_border: Some(
          BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
        ),
        cursor_color: Color::blue(),
        corner_radius: 0.0,
        on_submit: None,
      })
    }),
    size=Size::new(width=160.0, height=60.0),
  )
  state.set("typed")
  inspect(runtime.needs_rebuild, content="true")
  ignore(runtime.build_draw_commands())
}

///|
test "build context binding drives text field input and dependent label" {
  let draft = State::new("")
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      ViewSpec::FlexSpec({
        key: None,
        axis: Axis::Vertical,
        spacing: 4.0,
        main_axis_alignment: MainStart,
        cross_axis_alignment: CrossStart,
        children: [
          ViewSpec::TextSpec({
            key: None,
            text: "Draft: \{ctx.watch(draft)}",
            size: Size::new(width=160.0, height=24.0),
            font: FontSpec::new(size=16.0, weight=400),
            color: Color::black(),
          }),
          ViewSpec::TextFieldSpec({
            key: None,
            value: ctx.binding(draft),
            placeholder: "Type",
            size: Size::new(width=160.0, height=32.0),
            font: FontSpec::new(size=16.0, weight=400),
            foreground: Color::black(),
            placeholder_color: Color::gray(),
            background: Brush::solid(Color::white()),
            border: Some(
              BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0),
            ),
            focused_border: Some(
              BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
            ),
            cursor_color: Color::blue(),
            corner_radius: 0.0,
            on_submit: None,
          }),
        ],
      })
    }),
    size=Size::new(width=200.0, height=80.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=34.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("Hi")))
  inspect(draft.get(), content="Hi")
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => command is DrawText({ text: "Draft: Hi", .. })),
  )
}

///|
test "derived state recomputes through build context subscriptions" {
  let left = State::new(1)
  let right = State::new(2)
  let total = DerivedState::combine(left, right, (a, b) => a + b)
  let builds = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      builds.val = builds.val + 1
      ViewSpec::TextSpec({
        key: None,
        text: "Total \{ctx.watch_derived(total)}",
        size: Size::new(width=120.0, height=24.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=24.0),
  )
  let first = runtime.build_draw_commands()
  guard first[1] is DrawText({ text: "Total 3", .. }) else {
    fail("expected initial derived value")
  }
  left.set(4)
  let second = runtime.build_draw_commands()
  guard second[1] is DrawText({ text: "Total 6", .. }) else {
    fail("expected derived value after left update")
  }
  right.set(10)
  let third = runtime.build_draw_commands()
  guard third[1] is DrawText({ text: "Total 14", .. }) else {
    fail("expected derived value after right update")
  }
  assert_true(builds.val >= 3)
}
