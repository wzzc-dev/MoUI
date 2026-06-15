///|
test "scroll view emits clip and offsets child frame" {
  let scroll = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=12.0),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    on_scroll: None,
    scroll_state: None,
    scroll_activates: false,
    child: ViewSpec::TextSpec({
      key: None,
      text: "Scrolled",
      size: Size::new(width=120.0, height=80.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let render = mount_view_spec(scroll).render(
    Rect::new(x=5.0, y=6.0, width=80.0, height=40.0),
  )
  guard render.paint_commands is [PushClip(_)] else {
    fail("expected scroll clip commands")
  }
  guard render.post_paint_commands is [PopClip] else {
    fail("expected scroll pop clip after children")
  }
  inspect(render.children[0].frame.origin.y, content="-6")
}

///|
test "scroll view handles wheel delta through callback" {
  let offset = State::new(Point::new(x=0.0, y=0.0))
  let root = ViewSpec::ScrollSpec({
    key: None,
    offset: offset.get(),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    on_scroll: Some(delta => {
      offset.set(Point::new(x=0.0, y=offset.get().y - delta.y))
    }),
    scroll_state: None,
    scroll_activates: true,
    child: ViewSpec::TextSpec({
      key: None,
      text: "Scrolled",
      size: Size::new(width=120.0, height=80.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let runtime = RuntimeState::new_spec(
    root~,
    size=Size::new(width=80.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
        wheel_delta=Point::new(x=0.0, y=-12.0),
      ),
    ),
  )
  inspect(offset.get().y, content="12")
}

///|
test "state backed scroll repaints without activation rebuild or layout pass" {
  let scroll = ScrollState::new()
  let root : View[Unit] = View::primitive_scroll_view(
    child=View::primitive_text_view(
      text="Scrolled",
      size=Size::new(width=120.0, height=80.0),
      font=FontSpec::new(),
      color=Color::black(),
    ),
    viewport=Some(Size::new(width=80.0, height=40.0)),
    state=Some(scroll),
  )
  let runtime = RuntimeState::new_view(
    root~,
    size=Size::new(width=80.0, height=40.0),
  )
  let first_commands = runtime.draw_commands()
  match draw_text_frame(first_commands, "Scrolled") {
    Some(frame) => inspect(frame.origin.y, content="0")
    None => inspect("missing", content="0")
  }
  let layout_passes = runtime.layout_pass_count
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
        wheel_delta=Point::new(x=0.0, y=-12.0),
      ),
    ),
  )
  inspect(scroll.offset().y, content="12")
  inspect(runtime.needs_rebuild(), content="false")
  inspect(runtime.needs_layout(), content="false")
  inspect(runtime.needs_paint(), content="true")
  ignore(runtime.draw_frame())
  match draw_text_frame(runtime.draw_commands(), "Scrolled") {
    Some(frame) => inspect(frame.origin.y, content="-12")
    None => inspect("missing", content="-12")
  }
  inspect(runtime.layout_pass_count, content="\{layout_passes}")
}

///|
test "state backed scroll repositions repaint boundary child without layout" {
  let scroll = ScrollState::new()
  let root : View[Unit] = View::primitive_scroll_view(
    child=View::primitive_text_view(
      text="Cached child",
      size=Size::new(width=120.0, height=80.0),
      font=FontSpec::new(),
      color=Color::black(),
    ).repaint_boundary(),
    viewport=Some(Size::new(width=80.0, height=40.0)),
    state=Some(scroll),
  )
  let runtime = RuntimeState::new_view(
    root~,
    size=Size::new(width=80.0, height=40.0),
  )
  ignore(runtime.draw_commands())
  let layout_passes = runtime.layout_pass_count
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
        wheel_delta=Point::new(x=0.0, y=-12.0),
      ),
    ),
  )
  ignore(runtime.draw_frame())
  match draw_text_frame(runtime.draw_commands(), "Cached child") {
    Some(frame) => inspect(frame.origin.y, content="-12")
    None => inspect("missing", content="-12")
  }
  inspect(runtime.layout_pass_count, content="\{layout_passes}")
}

///|
test "scroll clip wraps child draw commands in collected paint order" {
  let scroll = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=0.0),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    on_scroll: None,
    scroll_state: None,
    scroll_activates: false,
    child: ViewSpec::ModifiedSpec({
      key: None,
      modifier: ClipModifier,
      child: ViewSpec::TextSpec({
        key: None,
        text: "Nested",
        size: Size::new(width=120.0, height=80.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
    }),
  })
  let commands : Array[DrawCommand] = []
  mount_view_spec(scroll)
  .render(Rect::new(x=0.0, y=0.0, width=80.0, height=40.0))
  .collect_draw_commands(commands)
  inspect(commands.length(), content="5")
  assert_true(commands[0] is PushClip(_))
  assert_true(commands[1] is PushClip(_))
  assert_true(commands[2] is DrawText(_))
  assert_true(commands[3] is PopClip)
  assert_true(commands[4] is PopClip)
}

///|
test "scroll hit testing reaches offset children" {
  let clicks = Ref("")
  let button = ViewSpec::ButtonSpec({
    key: None,
    text: "Second",
    size: Size::new(width=80.0, height=30.0),
    font: FontSpec::new(size=16.0, weight=600),
    foreground: Color::black(),
    background: Brush::solid(Color::gray()),
    hovered_background: Brush::solid(Color::gray()),
    pressed_background: Brush::solid(Color::blue()),
    border: None,
    shadow: None,
    corner_radius: 0.0,
    on_click: Some(() => clicks.val = "second"),
  })
  let root = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=34.0),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    on_scroll: None,
    scroll_state: None,
    scroll_activates: false,
    child: ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 4.0,
      main_axis_alignment: MainAxisAlignment::MainStart,
      cross_axis_alignment: CrossAxisAlignment::CrossStart,
      children: [
        ViewSpec::TextSpec({
          key: None,
          text: "First",
          size: Size::new(width=80.0, height=30.0),
          font: FontSpec::new(),
          color: Color::black(),
        }),
        button,
      ],
    }),
  })
  let runtime = RuntimeState::new_spec(
    root~,
    size=Size::new(width=80.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="second")
}
