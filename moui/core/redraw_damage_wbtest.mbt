///|
test "damage region clips rects and promotes large coverage" {
  let surface = Rect::new(x=0.0, y=0.0, width=100.0, height=100.0)
  let clipped = DamageRegion::from_rects(
    [Rect::new(x=90.0, y=90.0, width=40.0, height=40.0)],
    surface,
  )
  match clipped {
    Rects(rects) => {
      inspect(rects.length(), content="1")
      inspect(rects[0].size.width, content="10")
      inspect(rects[0].size.height, content="10")
    }
    _ => fail("expected clipped rect damage")
  }
  let large = DamageRegion::from_rects(
    [Rect::new(x=0.0, y=0.0, width=90.0, height=90.0)],
    surface,
  )
  match large {
    FullSurface(reason) =>
      inspect(reason, content="dirty region covers most of the surface")
    _ => fail("expected full-surface promotion")
  }
}

///|
test "draw command bounds cover common paint commands" {
  match
    DrawCommand::DrawText(
      TextRun::new(
        text="Hello",
        frame=Rect::new(x=10.0, y=12.0, width=30.0, height=14.0),
        font=FontSpec::new(size=12.0),
        color=Color::black(),
      ),
    )
    .bounds() {
    Some(bounds) => {
      inspect(bounds.origin.x, content="9")
      inspect(bounds.origin.y, content="11")
      inspect(bounds.size.width, content="32")
      inspect(bounds.size.height, content="16")
    }
    None => fail("expected text bounds")
  }
  match
    DrawCommand::StrokeRect(
      Rect::new(x=4.0, y=5.0, width=6.0, height=7.0),
      Color::black(),
      2.0,
    )
    .bounds() {
    Some(bounds) => {
      inspect(bounds.origin.x, content="2")
      inspect(bounds.origin.y, content="3")
      inspect(bounds.size.width, content="10")
      inspect(bounds.size.height, content="11")
    }
    None => fail("expected stroke bounds")
  }
}

///|
test "draw frame emits repaint boundary update then cached layer draw" {
  let root : View[Unit] = View::text(
    text="Cached",
    size=Size::new(width=80.0, height=24.0),
    font=FontSpec::new(size=12.0),
    color=Color::black(),
  )
  .repaint_boundary()
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
      View::text(
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
