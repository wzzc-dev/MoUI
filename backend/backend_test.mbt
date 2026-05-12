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
