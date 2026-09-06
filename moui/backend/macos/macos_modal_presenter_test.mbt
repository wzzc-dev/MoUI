///|
test "macos modal presenter accepts and gates the session lifecycle" {
  let present_calls : Array[String] = []
  let close_calls : Array[String] = []
  let present = fn(request : @host.HostModalRequest) -> @host.HostModalResult {
    present_calls.push(request.presentation_id())
    @host.HostModalResult::Accepted
  }
  let close = fn(presentation_id : String) -> Unit {
    close_calls.push(presentation_id)
  }
  let presenter = MacosModalPresenter::with_hooks(
    hooks=MacosModalNativeHooks::new(present~, close~),
  )
  assert_true(presenter.capabilities().supports_native_modal())
  let request = @host.HostModalRequest::new(
    request_id=7,
    presentation_id="settings-dialog",
    generation=2,
    bounds=@core.Rect::new(x=10.0, y=10.0, width=300.0, height=200.0),
    modality=@host.HostModalModality::Modal,
  )
  let (session, events) = presenter.present(request)
  assert_eq(present_calls, ["settings-dialog"])
  assert_eq(events.length(), 2)
  assert_eq(session.state(), @host_modal.HostModalSessionState::Accepted)
  // Surface attach only succeeds at the current generation on an accepted
  // session; input routes through the transform while attached.
  assert_true(presenter.attach_surface(session, "modal-surface") is Some(_))
  assert_true(session.surface() is Some(_))
  let down = @core.PointerEvent::new(
    position=@core.Point::new(x=15.0, y=25.0),
    phase=@core.PointerPhase::Down,
  )
  assert_true(presenter.route_input(session, down) is Some(_))
  // Close emits exactly once and asks the native side to dismiss once.
  assert_true(presenter.close(session) is Some(_))
  assert_true(presenter.close(session) is None)
  assert_eq(close_calls, ["settings-dialog"])
  assert_eq(session.state(), @host_modal.HostModalSessionState::Closed)
  // Input after close is dropped.
  assert_true(presenter.route_input(session, down) is None)
}

///|
test "macos modal presenter rejection falls back to the view surface" {
  let present = fn(_request : @host.HostModalRequest) -> @host.HostModalResult {
    @host.HostModalResult::Rejected("no native host window")
  }
  let close = fn(_presentation_id : String) -> Unit {
    ignore(_presentation_id)
  }
  let presenter = MacosModalPresenter::with_hooks(
    hooks=MacosModalNativeHooks::new(present~, close~),
  )
  let request = @host.HostModalRequest::new(
    request_id=1,
    presentation_id="palette",
    generation=0,
    bounds=@core.Rect::new(x=0.0, y=0.0, width=100.0, height=80.0),
  )
  let (session, events) = presenter.present(request)
  assert_eq(events.length(), 2)
  assert_eq(session.state(), @host_modal.HostModalSessionState::Rejected)
  // A rejected session never attaches a surface, and rejection is already a
  // terminal state: no further close event can be emitted.
  assert_true(presenter.attach_surface(session, "modal-surface") is None)
  assert_true(session.close(1, 0) is None)
}

///|
test "macos modal presenter drops stale close and detached input" {
  let close_calls : Array[String] = []
  let present = fn(_request : @host.HostModalRequest) -> @host.HostModalResult {
    @host.HostModalResult::Accepted
  }
  let close = fn(presentation_id : String) -> Unit {
    close_calls.push(presentation_id)
  }
  let presenter = MacosModalPresenter::with_hooks(
    hooks=MacosModalNativeHooks::new(present~, close~),
  )
  let request = @host.HostModalRequest::new(
    request_id=5,
    presentation_id="sheet",
    generation=3,
    bounds=@core.Rect::new(x=0.0, y=0.0, width=100.0, height=80.0),
  )
  let (session, _events) = presenter.present(request)
  assert_true(presenter.attach_surface(session, "sheet-surface") is Some(_))
  assert_true(presenter.detach_surface(session, "sheet-surface") is Some(_))
  // Input requires an attached surface.
  let move = @core.PointerEvent::new(
    position=@core.Point::new(x=1.0, y=1.0),
    phase=@core.PointerPhase::Move,
  )
  assert_true(presenter.route_input(session, move) is None)
  // A stale-generation close is dropped entirely and never reaches the
  // native side.
  assert_true(session.close(5, 99) is None)
  assert_eq(close_calls, [])
  assert_true(presenter.close(session) is Some(_))
  assert_eq(close_calls, ["sheet"])
}
