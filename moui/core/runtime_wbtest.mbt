///|
test "app runtime dispatches events and draws" {
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Click",
      size: Size::new(width=100.0, height=50.0),
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
    size=Size::new(width=120.0, height=80.0),
  )
  inspect(runtime.draw_commands().length(), content="3")
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  assert_true(runtime.size() == Size::new(width=240.0, height=160.0))
  inspect(runtime.dirty_count(), content="1")
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
      ),
    ),
  )
  inspect(runtime.needs_redraw(), content="true")
  ignore(runtime.draw_commands())
  inspect(runtime.dirty_count(), content="0")
}

///|
test "app runtime component watches state through public API" {
  let count = State::new(0)
  let runtime = AppRuntime::new_component(
    root=Component::new(ctx => {
      ViewSpec::TextSpec({
        key: None,
        text: "Count \{ctx.watch(count)}",
        size: Size::new(width=100.0, height=24.0),
        font: FontSpec::new(size=16.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  guard runtime.draw_commands() is [_, DrawText({ text: "Count 0", .. })] else {
    fail("expected initial component text")
  }
  count.set(1)
  inspect(runtime.needs_rebuild(), content="true")
  guard runtime.draw_commands() is [_, DrawText({ text: "Count 1", .. })] else {
    fail("expected rebuilt component text")
  }
  inspect(count.slot.listeners.length(), content="1")
}

///|
test "build context viewport size updates after resize" {
  let runtime = AppRuntime::new_component(
    root=Component::new(ctx => {
      let size = ctx.viewport_size()
      ViewSpec::TextSpec({
        key: None,
        text: "\{size.width}x\{size.height}",
        size: Size::new(width=140.0, height=24.0),
        font: FontSpec::new(size=16.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  guard runtime.draw_commands() is [_, DrawText({ text: "120x40", .. })] else {
    fail("expected initial viewport text")
  }
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  guard runtime.draw_commands() is [_, DrawText({ text: "240x160", .. })] else {
    fail("expected resized viewport text")
  }
}

///|
test "searchbar paints vector icons instead of font fallback glyphs" {
  let query = State::new("abc")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::SearchBarSpec({
      key: None,
      query: query.binding(),
      placeholder: "Search",
      font: FontSpec::new(size=14.0, weight=400),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: Brush::solid(Color::white()),
      border: None,
      focused_border: None,
      cursor_color: Color::blue(),
      corner_radius: 8.0,
      on_submit: None,
      on_clear: None,
    }),
    size=Size::new(width=240.0, height=44.0),
  )
  let commands = runtime.draw_commands()
  assert_false(has_draw_text(commands, "?"))
  assert_true(commands.any(command => command is DrawCommand::DrawPath(_)))
  assert_true(
    commands.any(command => command is DrawCommand::StrokeRoundedRect(_, _, _)),
  )
}

///|
test "app runtime updates root and environment through public API" {
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::TextSpec({
      key: None,
      text: "A",
      size: Size::new(width=40.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  runtime.set_root_spec(
    ViewSpec::TextSpec({
      key: None,
      text: "B",
      size: Size::new(width=40.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
  )
  guard runtime.draw_commands() is [_, DrawText({ text: "B", .. })] else {
    fail("expected replacement root text")
  }
  let environment = Environment::default()
    .with_text_scale(1.25)
    .with_locale("zh-CN")
  runtime.set_environment(environment)
  inspect(runtime.environment().text_scale, content="1.25")
  inspect(runtime.environment().locale, content="zh-CN")
  inspect(runtime.needs_redraw(), content="true")
}

///|
fn has_draw_text(commands : Array[DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
enum ProgramSimpleMsg {
  ProgramSimpleIncrement
}

///|
test "program simple updates model and rebuilds view" {
  let program = Program::simple(
    init=0,
    update=(model, message) => {
      match message {
        ProgramSimpleIncrement => model + 1
      }
    },
    view=model => {
      View::button(
        text="Count \{model}",
        size=Size::new(width=120.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramSimpleIncrement),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 0"))
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 1"))
}
