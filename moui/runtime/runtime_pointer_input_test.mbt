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
