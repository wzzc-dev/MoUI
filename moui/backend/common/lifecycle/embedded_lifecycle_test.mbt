///|
test "embedded host owns logical generation and primary routing" {
  let host = EmbeddedLifecycle::new()
  inspect(host.resumed().length(), content="1")
  inspect(host.resumed().length(), content="0")
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=50.0, height=100.0),
    scale_factor=2.0,
  )
  let first = host.attach_surface(11UL, metrics)
  inspect(host.surface_generation(), content="1")
  inspect(first.length(), content="2")
  let window = @backend_host.WindowId::new(7)
  host.register_window(window)
  assert_true(host.primary_window() == Some(window))
  let second = host.attach_surface(12UL, metrics)
  inspect(host.surface_generation(), content="3")
  inspect(second.length(), content="4")
  assert_true(host.surface().unwrap().handle == 12UL)
  host.unregister_window(window)
  assert_true(host.primary_window() is None)
  inspect(host.detach_surface().length(), content="2")
  inspect(host.surface_generation(), content="4")
}

///|
test "embedded host exit intent is explicit and terminal" {
  let host = EmbeddedLifecycle::new()
  match host.request_exit(23) {
    Exit(code) => inspect(code, content="23")
    _ => fail("expected exit action")
  }
  assert_true(host.exit_intent() == Some(23))
  inspect(host.resumed().length(), content="0")
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=1.0, height=1.0),
  )
  inspect(host.attach_surface(1UL, metrics).length(), content="0")
  assert_true(host.surface() is None)
}
