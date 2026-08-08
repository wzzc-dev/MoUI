///|
test "transport projects owner surface epochs and mints session generations" {
  let transport = HostSessionTransport::new(initial_generation=11)
  assert_true(transport.attach(surface_epoch=7))
  inspect(transport.surface_epoch(), content="7")
  inspect(transport.session_generation(), content="11")

  assert_false(transport.attach(surface_epoch=7))
  inspect(transport.session_generation(), content="11")
  assert_true(transport.detach())

  assert_false(transport.attach(surface_epoch=6))
  inspect(transport.session_generation(), content="11")
  assert_true(transport.attach(surface_epoch=42))
  inspect(transport.surface_epoch(), content="42")
  inspect(transport.session_generation(), content="12")
}
