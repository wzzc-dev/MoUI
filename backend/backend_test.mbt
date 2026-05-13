///|
test "backend event conversion" {
  let event = @backend.event_kind_to_core(
    @backend.BackendEventKind::Resize,
    size=@core.Size::new(width=10.0, height=20.0),
  )
  match event {
    @core.AppEvent::Resize(size) =>
      assert_true(size == @core.Size::new(width=10.0, height=20.0))
    _ => fail("expected resize event")
  }
}

///|
test "surface bridge info" {
  inspect(
    @backend.default_surface_bridge_info().uses_external_layer,
    content="false",
  )
}

///|
test "app runtime dispatches events and draws" {
  let runtime = @backend.AppRuntime::new(
    root=@core.ViewNode::Button({
      text: "Click",
      size: @core.Size::new(width=100.0, height=50.0),
      state: @core.ButtonState::Normal,
      on_click: None,
    }),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  inspect(runtime.draw_commands().length(), content="3")
  runtime.dispatch_event(
    @core.AppEvent::Resize(@core.Size::new(width=240.0, height=160.0)),
  )
  assert_true(runtime.size() == @core.Size::new(width=240.0, height=160.0))
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(runtime.needs_redraw(), content="true")
}
