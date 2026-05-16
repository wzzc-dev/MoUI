///|
test "build context watch rebuilds and replaces old subscription" {
  let state = State::new(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx =>
      ViewSpec::TextSpec({
        key: None,
        text: "Value: \{ctx.watch(state)}",
        size: Size::new(width=100.0, height=24.0),
        font: FontSpec::new(size=16.0, weight=400),
        color: Color::black(),
      })),
    size=Size::new(width=120.0, height=40.0),
  )
  inspect(state.slot.listeners.length(), content="1")
  state.set(1)
  inspect(runtime.needs_rebuild, content="true")
  guard runtime.build_draw_commands() is [_, DrawText({ text: "Value: 1", .. })] else {
    fail("expected rebuilt text")
  }
  inspect(state.slot.listeners.length(), content="1")
  state.set(2)
  guard runtime.build_draw_commands() is [_, DrawText({ text: "Value: 2", .. })] else {
    fail("expected rebuilt text after second state change")
  }
  inspect(state.slot.listeners.length(), content="1")
}

///|
test "build context binding subscribes control state" {
  let state = State::new("")
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx =>
      ViewSpec::TextFieldSpec({
        key: None,
        value: ctx.binding(state),
        placeholder: "",
        size: Size::new(width=120.0, height=32.0),
        font: FontSpec::new(size=16.0, weight=400),
        foreground: Color::black(),
        placeholder_color: Color::gray(),
        background: Color::white(),
        border_color: Color::gray(),
        focused_border_color: Color::blue(),
        cursor_color: Color::blue(),
        corner_radius: 0.0,
        on_submit: None,
      })),
    size=Size::new(width=160.0, height=60.0),
  )
  inspect(state.slot.listeners.length(), content="1")
  state.set("typed")
  inspect(runtime.needs_rebuild, content="true")
  ignore(runtime.build_draw_commands())
  inspect(state.slot.listeners.length(), content="1")
}
