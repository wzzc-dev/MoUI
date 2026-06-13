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
test "damage region coalesces adjacent rects before full promotion" {
  let surface = Rect::new(x=0.0, y=0.0, width=200.0, height=80.0)
  let adjacent : Array[Rect] = []
  for index in 0..<9 {
    adjacent.push(
      Rect::new(x=index.to_double() * 10.0, y=8.0, width=10.0, height=12.0),
    )
  }
  match DamageRegion::from_rects(adjacent, surface) {
    Rects(rects) => {
      inspect(rects.length(), content="1")
      inspect(rects[0].size.width, content="90")
    }
    _ => fail("expected coalesced rect damage")
  }
  let separated : Array[Rect] = []
  for index in 0..<9 {
    separated.push(
      Rect::new(x=index.to_double() * 20.0, y=40.0, width=4.0, height=4.0),
    )
  }
  match DamageRegion::from_rects(separated, surface) {
    FullSurface(reason) => inspect(reason, content="too many dirty rects")
    _ => fail("expected full promotion for separated rects")
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
    ).bounds() {
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
    ).bounds() {
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
test "state backed scroll reports local damage rect" {
  let scroll = ScrollState::new()
  let root : View[Unit] = View::flex(axis=Axis::Horizontal, spacing=8.0, children=[
    View::scroll(
      child=View::text(
        text="Scrolled",
        size=Size::new(width=120.0, height=80.0),
        font=FontSpec::new(size=12.0),
        color=Color::black(),
      ),
      viewport=Some(Size::new(width=80.0, height=40.0)),
      state=Some(scroll),
    ),
    View::text(
      text="Still",
      size=Size::new(width=80.0, height=32.0),
      font=FontSpec::new(size=12.0),
      color=Color::black(),
    ).repaint_boundary(),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=Size::new(width=220.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Move,
        wheel_delta=Point::new(x=0.0, y=-12.0),
      ),
    ),
  )
  match runtime.draw_frame().damage {
    Rects(rects) => {
      assert_true(rects.length() > 0)
      assert_true(rects[0].size.width < 220.0)
    }
    FullSurface(reason) =>
      fail("expected local layout damage, got full damage: \{reason}")
    Empty => fail("expected local layout damage")
  }
}

///|
test "layout dirty child reports local damage rect" {
  let root : View[Unit] = View::flex(axis=Axis::Horizontal, spacing=8.0, children=[
    View::frame(
      View::text(
        text="Layout",
        size=Size::new(width=80.0, height=24.0),
        font=FontSpec::new(size=12.0),
        color=Color::black(),
      ),
      width=90.0,
      height=40.0,
    ),
    View::text(
      text="Still",
      size=Size::new(width=80.0, height=32.0),
      font=FontSpec::new(size=12.0),
      color=Color::black(),
    ).repaint_boundary(),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=Size::new(width=220.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  let child = runtime.state.element_tree.root.children[0]
  child.dirty.mark_layout()
  child.clear_cached_layout_and_paint()
  runtime.state.mark_layout_dirty(child.id)
  match runtime.draw_frame().damage {
    Rects(rects) => {
      assert_true(rects.length() > 0)
      assert_true(rects[0].size.width < 220.0)
    }
    FullSurface(reason) =>
      fail("expected local layout damage, got full damage: \{reason}")
    Empty => fail("expected local layout damage")
  }
}

///|
test "dirty redraw without bounds falls back to full damage" {
  let root : View[Unit] = View::text(
    text="Fallback",
    size=Size::new(width=80.0, height=32.0),
    font=FontSpec::new(size=12.0),
    color=Color::black(),
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=Size::new(width=120.0, height=60.0),
  )
  ignore(runtime.draw_frame())
  runtime.state.needs_paint = true
  runtime.state.needs_redraw = true
  runtime.state.clear_dirty_queue()
  match runtime.draw_frame().damage {
    FullSurface(reason) => inspect(reason, content="dirty bounds unavailable")
    _ => fail("expected full damage when dirty bounds are unavailable")
  }
}
