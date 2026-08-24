///|
test "host modal session drops stale and duplicate close" {
  let request = @backend_host.HostModalRequest::new(
    request_id=7,
    presentation_id="dialog",
    generation=3,
    bounds=@core.Rect::new(x=0.0, y=0.0, width=100.0, height=80.0),
  )
  let session = HostModalSession::new(request)
  assert_true(session.accept(7, 3) is Some(_))
  assert_true(session.attach_surface("surface", 3))
  assert_true(session.close(7, 2) is None)
  assert_true(session.close(7, 3) is Some(_))
  assert_true(session.close(7, 3) is None)
}

///|
test "host modal session transforms input coordinates" {
  let request = @backend_host.HostModalRequest::new(
    request_id=1,
    presentation_id="menu",
    generation=1,
    bounds=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
  )
  let session = HostModalSession::new(request)
  ignore(session.accept(1, 1))
  session.set_input_transform(
    offset=@core.Point::new(x=10.0, y=20.0),
    scale=@core.Point::new(x=2.0, y=4.0),
  )
  let point = session.transform_input(@core.Point::new(x=14.0, y=28.0))
  assert_true(point == @core.Point::new(x=2.0, y=2.0))
}

///|
test "host modal session accepts only the current generation and routes input" {
  let request = @backend_host.HostModalRequest::new(
    request_id=8,
    presentation_id="dialog",
    generation=4,
    bounds=@core.Rect::new(x=0.0, y=0.0, width=40.0, height=30.0),
  )
  let session = HostModalSession::new(request)
  assert_true(session.begin() is @backend_host.HostModalEvent::Pending(_, _, 4))
  assert_true(session.accept(8, 3) is None)
  assert_true(session.accept(8, 4) is Some(_))
  assert_true(session.is_native_only())
  assert_true(
    session.route_input(
      8,
      3,
      @core.PointerEvent::new(
        position=@core.Point::new(x=1.0, y=1.0),
        phase=@core.PointerPhase::Down,
      ),
    )
    is None,
  )
  assert_true(session.attach_surface("surface", 4))
  assert_true(
    session.route_input(
      8,
      4,
      @core.PointerEvent::new(
        position=@core.Point::new(x=1.0, y=1.0),
        phase=@core.PointerPhase::Down,
      ),
    )
    is Some(_),
  )
}

///|
test "host modal session treats rejection as a terminal fallback" {
  let request = @backend_host.HostModalRequest::new(
    request_id=9,
    presentation_id="required",
    generation=1,
    bounds=@core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
  )
  let session = HostModalSession::new(request)
  assert_true(session.reject(9, 1, "unsupported") is Some(_))
  assert_true(session.state() is HostModalSessionState::Rejected)
  assert_true(session.close(9, 1) is None)
  assert_true(session.accept(9, 1) is None)
}
