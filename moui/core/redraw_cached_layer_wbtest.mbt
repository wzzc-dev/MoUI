///|
test "draw frame emits repaint boundary update then cached layer draw" {
  let root : View[Unit] = View::primitive_text_view(
    text="Cached",
    size=Size::new(width=80.0, height=24.0),
    font=FontSpec::new(size=12.0),
    color=Color::black(),
  ).repaint_boundary()
  let runtime = AppRuntime::new_view(
    root~,
    size=Size::new(width=120.0, height=60.0),
  )
  let first = runtime.draw_frame()
  assert_true(
    first.commands.any(command => command is DrawCommand::BeginCachedLayer(_)),
  )
  assert_true(first.damage is DamageRegion::FullSurface(_))
  let second = runtime.draw_frame()
  assert_true(
    second.commands.any(command => command is DrawCommand::DrawCachedLayer(_)),
  )
}

///|
test "program draw frame emits repaint boundary update then cached layer draw" {
  let program : Program[Unit, Unit] = Program::simple(
    init=(),
    update=(_model, _message) => (),
    view=_model => {
      View::primitive_text_view(
        text="Cached",
        size=Size::new(width=80.0, height=24.0),
        font=FontSpec::new(size=12.0),
        color=Color::black(),
      ).repaint_boundary()
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=120.0, height=60.0),
  )
  let first = runtime.draw_frame()
  assert_true(
    first.commands.any(command => command is DrawCommand::BeginCachedLayer(_)),
  )
  let second = runtime.draw_frame()
  assert_true(
    second.commands.any(command => command is DrawCommand::DrawCachedLayer(_)),
  )
}

///|
enum RetainedRedrawProgramMsg {
  RetainedRedrawIncrement
}

///|
fn count_begin_cached_layers(commands : Array[DrawCommand]) -> Int {
  commands
  .filter(command => command is DrawCommand::BeginCachedLayer(_))
  .length()
}

///|
fn count_draw_cached_layers(commands : Array[DrawCommand]) -> Int {
  commands
  .filter(command => command is DrawCommand::DrawCachedLayer(_))
  .length()
}

///|
fn first_begin_cached_layer_spec(
  commands : Array[DrawCommand],
) -> CachedLayerSpec? {
  for command in commands {
    match command {
      DrawCommand::BeginCachedLayer(spec) => return Some(spec)
      _ => ()
    }
  }
  None
}

///|
fn retained_redraw_text_spec(text : String) -> ViewSpec {
  ModifiedSpec({
    key: None,
    modifier: RepaintBoundaryModifier,
    child: TextSpec({
      key: None,
      text,
      size: Size::new(width=80.0, height=24.0),
      font: FontSpec::new(size=12.0),
      color: Color::black(),
    }),
  })
}

///|
test "repaint boundary cache key stays stable across content revisions" {
  let runtime = AppRuntime::new_spec(
    root=retained_redraw_text_spec("One"),
    size=Size::new(width=120.0, height=60.0),
  )
  let first = first_begin_cached_layer_spec(runtime.draw_frame().commands)
  runtime.set_root_spec(retained_redraw_text_spec("Two"))
  let updated = first_begin_cached_layer_spec(runtime.draw_frame().commands)
  match (first, updated) {
    (Some(first), Some(updated)) => {
      inspect(updated.key, content=first.key)
      assert_true(updated.content_revision > first.content_revision)
    }
    _ => fail("expected cached layer updates")
  }
}

///|
fn retained_redraw_button(text : String) -> View[RetainedRedrawProgramMsg] {
  View::primitive_button_view(
    text~,
    size=Size::new(width=80.0, height=32.0),
    font=FontSpec::new(size=12.0),
    foreground=Color::black(),
    background=Brush::solid(Color::gray()),
    hovered_background=Brush::solid(Color::gray()),
    pressed_background=Brush::solid(Color::blue()),
    on_click=Some(RetainedRedrawIncrement),
  )
}

///|
fn retained_redraw_label(text : String) -> View[RetainedRedrawProgramMsg] {
  View::primitive_text_view(
    text~,
    size=Size::new(width=80.0, height=32.0),
    font=FontSpec::new(size=12.0),
    color=Color::black(),
  )
}

///|
fn dispatch_retained_redraw_click(runtime : AppRuntime) -> Unit {
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
}

///|
test "program update preserves clean sibling repaint boundary cache" {
  let program : Program[Int, RetainedRedrawProgramMsg] = Program::simple(
    init=0,
    update=(model, message) => {
      match message {
        RetainedRedrawIncrement => model + 1
      }
    },
    view=model => {
      View::primitive_flex_view(axis=Axis::Horizontal, spacing=8.0, children=[
        retained_redraw_button("Left \{model}").key("left").repaint_boundary(),
        retained_redraw_label("Right").key("right").repaint_boundary(),
      ])
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=200.0, height=60.0),
  )
  inspect(count_begin_cached_layers(runtime.draw_frame().commands), content="2")
  inspect(count_draw_cached_layers(runtime.draw_frame().commands), content="2")
  dispatch_retained_redraw_click(runtime)
  ignore(runtime.draw_frame())
  inspect(count_draw_cached_layers(runtime.draw_frame().commands), content="2")
  dispatch_retained_redraw_click(runtime)
  let updated = runtime.draw_frame()
  inspect(count_begin_cached_layers(updated.commands), content="1")
  inspect(count_draw_cached_layers(updated.commands), content="1")
}

///|
test "paint only sibling boundary hover reports local damage rect" {
  let root = View::primitive_flex_view(axis=Axis::Horizontal, spacing=8.0, children=[
    retained_redraw_button("Left").key("left").repaint_boundary(),
    retained_redraw_label("Right").key("right").repaint_boundary(),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=Size::new(width=200.0, height=60.0),
  )
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Move,
      ),
    ),
  )
  match runtime.draw_frame().damage {
    Rects(rects) => {
      assert_true(rects.length() > 0)
      assert_true(rects.length() <= 2)
      assert_true(rects[0].size.width <= 90.0)
    }
    _ => fail("expected local repaint boundary damage")
  }
}
