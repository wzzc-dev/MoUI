///|
test "direct pointer input reports scroll consumption at boundaries" {
  let state = @core.ScrollState::new()
  let root : @core.View[Unit] = @views.scroll_view(
    runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
    width=20.0,
    height=40.0,
    state=Some(state),
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
  )
  ignore(runtime.layout())
  let consumed = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=5.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=-12.0),
    ),
  )
  if consumed.host_flags() != 1 {
    fail("expected a moved scroll view to consume the wheel")
  }
  state.scroll_to(x=0.0, y=160.0)
  let edge = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=5.0),
      phase=@core.PointerPhase::Move,
      wheel_delta=@core.Point::new(x=0.0, y=-12.0),
    ),
  )
  if edge.host_flags() != 0 {
    fail("expected a scroll boundary to retain the browser default")
  }
}

///|
test "direct pointer input keeps a button target from down through up" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let position = @core.Point::new(x=8.0, y=8.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Move),
    ),
  )
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
  )
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
  )
  inspect(down.host_flags(), content="3")
  inspect(up.host_flags(), content="5")
  inspect(received.join(","), content="clicked")
}

///|
test "direct pointer input keeps a button target across a redraw" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let position = @core.Point::new(x=8.0, y=8.0)
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
  )
  ignore(runtime.draw_frame())
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
  )
  inspect(down.host_flags(), content="3")
  inspect(up.host_flags(), content="5")
  inspect(received.join(","), content="clicked")
}

///|
fn[Msg] runtime_pointer_capture_probe(message : Msg) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PointerCaptureProbe"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=40.0, height=24.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, @core.Color::blue()),
      ])
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          match event.phase {
            @core.PointerPhase::Down =>
              {
                ..@core.ViewEventResult::ignored(),
                captured: true,
                state: Some({ ..ctx.state, pressed: true }),
                dirty: @core.ViewDirtyHint::ViewPaintDirty,
              }
            @core.PointerPhase::Up =>
              if ctx.state.pressed {
                {
                  ..@core.ViewEventResult::message(message),
                  state: Some({ ..ctx.state, pressed: false }),
                }
              } else {
                @core.ViewEventResult::ignored()
              }
            _ => @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
test "direct pointer input retains a captured non-focusable target" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=runtime_pointer_capture_probe("clicked"),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=8.0, y=8.0),
      phase=@core.PointerPhase::Down,
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=72.0, y=8.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=72.0, y=8.0),
      phase=@core.PointerPhase::Up,
    ),
  )
  inspect(down.host_flags(), content="3")
  inspect(up.host_flags(), content="5")
  inspect(received.join(","), content="clicked")
}
