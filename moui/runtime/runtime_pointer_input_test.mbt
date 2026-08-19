///|
test "direct pointer input reports scroll consumption at boundaries" {
  let root : @core.View[Unit] = @views.scroll_view(
    runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
    width=20.0,
    height=40.0,
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
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-1000.0),
      ),
    ),
  )
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
test "direct pointer input drags a scroll view" {
  let root : @core.View[Unit] = @views.scroll_view(
    runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
    width=20.0,
    height=40.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
  )
  ignore(runtime.layout())
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=30.0),
      phase=@core.PointerPhase::Down,
    ),
  )
  if down.host_flags() != 3 {
    fail("expected a scroll view to capture pointer down")
  }
  let move_result = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=10.0),
      phase=@core.PointerPhase::Move,
    ),
  )
  if move_result.host_flags() != 1 {
    fail("expected a scroll drag to be handled")
  }
  assert_true(runtime.layout().children[0].frame.origin.y == -20.0)
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=10.0),
      phase=@core.PointerPhase::Up,
    ),
  )
  if up.host_flags() != 5 {
    fail("expected a scroll view to release pointer capture")
  }
}

///|
test "direct pointer input drags a scroll view from a child control" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.scroll_view(
    @views.column(
      [
        @views.button("Tap", on_click="clicked", width=20.0, height=20.0),
        runtime_test_rect(width=20.0, height=180.0, color=@core.Color::blue()),
      ],
      spacing=0.0,
    ),
    width=20.0,
    height=40.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=0.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  assert_true(runtime.layout().children[0].frame.origin.y < 0.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=0.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  assert_true(received.is_empty())
}

///|
test "direct pointer input keeps a child click within scroll drag slop" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.scroll_view(
    @views.column(
      [
        @views.button("Tap", on_click="clicked", width=20.0, height=20.0),
        runtime_test_rect(width=20.0, height=180.0, color=@core.Color::blue()),
      ],
      spacing=0.0,
    ),
    width=20.0,
    height=40.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=6.0, y=11.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  assert_true(runtime.layout().children[0].frame.origin.y == 0.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=6.0, y=11.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(received.join(","), content="clicked")
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
/// A drag modifier commonly wraps a tap modifier in app controls.  A click
/// must clear the drag recognizer before the next hover Move; otherwise the
/// stale Pending state turns that Move into a drag and makes the control
/// follow the pointer.
test "drag modifier clears its state after a child tap consumes Up" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=40.0,
      height=40.0,
      padding=0.0,
    )
    .on_drag(event => "drag:" + event.phase.label())
    .on_tap("clicked")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=40.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  let center = @core.Point::new(x=20.0, y=20.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=@core.PointerPhase::Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=@core.PointerPhase::Up),
    ),
  )
  // This is an ordinary hover move after the click, not a button drag.
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=24.0, y=20.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(received.join(","), content="clicked")
}

///|
/// A drag nested inside a tap must still let the tap observe a short click,
/// while a real drag cancels the tap before its Up can activate.
test "captured gesture ancestors arbitrate tap versus drag" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=40.0,
      height=40.0,
      padding=0.0,
    )
    .on_drag(event => "drag:" + event.phase.label())
    .on_tap("clicked")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=40.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  let center = @core.Point::new(x=20.0, y=20.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=@core.PointerPhase::Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=@core.PointerPhase::Up),
    ),
  )
  inspect(received.join(","), content="clicked")

  received.clear()
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=@core.PointerPhase::Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=20.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(received.join(","), content="drag:Started,drag:Ended")
}

///|
fn runtime_damage_rebuild_program() -> @core.Program[Bool, Unit] {
  @core.Program::simple(init=false, update=(visible, _message) => !visible, view=visible => {
    if visible {
      @views.column(
        [
          @views.button("Open", on_click=(), width=60.0, height=24.0),
          runtime_test_rect(width=120.0, height=56.0, color=@core.Color::blue()),
        ],
        spacing=0.0,
      )
    } else {
      @views.column(
        [
          @views.button("Open", on_click=(), width=60.0, height=24.0),
          runtime_test_rect(
            width=120.0,
            height=56.0,
            color=@core.Color::rgba(r=0.86, g=0.12, b=0.12),
          ),
        ],
        spacing=0.0,
      )
    }
  })
}

///|
test "component rebuild requests full damage after replacing content" {
  let runtime = AppRuntime::new_program(
    program=runtime_damage_rebuild_program(),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  ignore(runtime.draw_frame())
  let position = @core.Point::new(x=8.0, y=8.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
    ),
  )
  let frame = runtime.draw_frame()
  assert_true(frame.damage is @core.DamageRegion::FullSurface(_))
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
