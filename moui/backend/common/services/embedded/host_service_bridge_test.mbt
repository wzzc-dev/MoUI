///|
test "embedded services accept only callback-backed requests in FIFO order" {
  let services = EmbeddedHostServices::new()
  let bridge = services.bridge()
  let first = bridge.dispatch(
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
  )
  let second = bridge.dispatch(
    @host.HostServiceRequest::PlatformChannel(
      @host.PlatformChannelRequest::new(channel="probe", operation="ping"),
    ),
  )
  match (first, second, services.drain_pending()) {
    (
      @host.HostServiceResponse::Pending(first_id),
      @host.HostServiceResponse::Pending(second_id),
      [first_pending, second_pending],
    ) => {
      assert_eq(first_id.value, 1)
      assert_eq(second_id.value, 2)
      assert_eq(first_pending.id, first_id)
      assert_eq(second_pending.id, second_id)
    }
    _ => abort("expected ordered pending embedded service requests")
  }
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::Unavailable(_) => ()
    _ => abort("expected desktop-only service to fail synchronously")
  }
}

///|
test "embedded service completion and disposal are exactly once" {
  let services = EmbeddedHostServices::new()
  let bridge = services.bridge()
  let id = match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Pending(id) => id
    _ => abort("expected pending clipboard request")
  }
  ignore(services.drain_pending())
  assert_true(
    services.complete(id, @host.HostServiceResponse::ClipboardText("value")),
  )
  assert_false(
    services.complete(id, @host.HostServiceResponse::ClipboardText("again")),
  )
  match services.drain_completed() {
    [
      {
        id: completed_id,
        response: @host.HostServiceResponse::ClipboardText("value"),
        ..,
      },
    ] => assert_eq(completed_id, id)
    _ => abort("expected one clipboard completion")
  }

  let cancelled = match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Pending(id) => id
    _ => abort("expected second pending clipboard request")
  }
  ignore(services.drain_pending())
  match services.dispose(reason="surface detached") {
    [
      {
        id: cancelled_id,
        response: @host.HostServiceResponse::Unavailable("surface detached"),
        ..,
      },
    ] => assert_eq(cancelled_id, cancelled)
    _ => abort("expected one cancellation completion")
  }
  assert_false(
    services.complete(cancelled, @host.HostServiceResponse::ClipboardWritten),
  )
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Unavailable(_) => ()
    _ => abort("expected disposed services to reject new requests")
  }
}

///|
test "embedded services deliver callbacks and cancel pending requests" {
  let services = EmbeddedHostServices::new()
  let bridge = services.bridge()
  let completed : Array[@host.HostCompletedServiceResponse] = []
  let callback_id = match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Pending(id) => id
    _ => abort("expected pending callback request")
  }
  ignore(services.drain_pending())
  assert_true(
    services.on_completed(callback_id, value => completed.push(value)),
  )
  assert_true(
    services.complete(
      callback_id,
      @host.HostServiceResponse::ClipboardText("callback"),
    ),
  )
  assert_eq(completed.length(), 1)
  assert_eq(completed[0].id, callback_id)

  let pending_id = match
    bridge.dispatch(
      @host.HostServiceRequest::PlatformChannel(
        @host.PlatformChannelRequest::new(channel="probe", operation="cancel"),
      ),
    ) {
    @host.HostServiceResponse::Pending(id) => id
    _ => abort("expected pending platform-channel request")
  }
  match services.dispose(reason="runtime disposed") {
    [
      {
        id,
        response: @host.HostServiceResponse::Unavailable("runtime disposed"),
        ..,
      },
    ] => assert_eq(id, pending_id)
    _ => abort("expected pending request cancellation")
  }
}
