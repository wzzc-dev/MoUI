///|
fn mobile_wire_runtime_and_driver() -> (@runtime.AppRuntime, HostRuntimeDriver) {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  (runtime, driver)
}

///|
test "mobile host wire emits versioned revisioned platform view snapshots" {
  let channel = MobileHostChannel::new(session_generation=7)
  let placement = @core.PlatformViewPlacement::new(
    id="preview",
    kind="camera.preview",
    frame=@core.Rect::new(x=4.0, y=8.0, width=120.0, height=80.0),
    clip=Some(@core.Rect::new(x=4.0, y=8.0, width=100.0, height=70.0)),
  )
  assert_true(channel.sync_platform_views([placement]))
  assert_false(channel.sync_platform_views([placement]))
  let json = channel.drain_update_envelope_json()
  assert_true(json.contains("\"schemaVersion\":1"))
  assert_true(json.contains("\"sessionGeneration\":7"))
  assert_true(json.contains("\"kind\":\"platform-views\""))
  assert_true(json.contains("\"revision\":1"))
  assert_true(json.contains("\"camera.preview\""))

  assert_true(channel.sync_platform_views([]))
  let envelope = channel.drain_update_envelope()
  inspect(envelope.schema_version, content="1")
  inspect(envelope.session_generation, content="7")
  match envelope.updates {
    [MobileHostUpdate::PlatformViews(snapshot)] => {
      inspect(snapshot.revision, content="2")
      inspect(snapshot.placements.length(), content="0")
    }
    _ => fail("expected a full removal snapshot")
  }
}

///|
test "mobile host wire validates platform view kind id and generation" {
  let (_runtime, driver) = mobile_wire_runtime_and_driver()
  let channel = MobileHostChannel::new(session_generation=9)
  ignore(
    channel.sync_platform_views([
      @core.PlatformViewPlacement::new(
        id="preview",
        kind="camera.preview",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      ),
    ]),
  )
  let event = @core.PlatformViewEvent::Named(
    name="ready",
    value="yes",
    detail="",
    flag=true,
  )
  let response = MobileHostResponse::PlatformView(
    1, "camera.preview", "preview", event,
  )
  assert_false(
    channel.dispatch_response_envelope(
      MobileHostResponseEnvelope::new(session_generation=8, response~),
      driver,
    ),
  )
  assert_false(
    channel.dispatch_response(
      MobileHostResponse::PlatformView(1, "wrong.kind", "preview", event),
      driver,
    ),
  )
  assert_false(
    channel.dispatch_response(
      MobileHostResponse::PlatformView(0, "camera.preview", "preview", event),
      driver,
    ),
  )
  assert_true(
    channel.dispatch_response_envelope(
      MobileHostResponseEnvelope::new(session_generation=9, response~),
      driver,
    ),
  )
}

///|
test "platform channel reuses async queue exactly once and rejects late responses" {
  let (runtime, driver) = mobile_wire_runtime_and_driver()
  let channel = MobileHostChannel::new(session_generation=12)
  let bridge = channel.service_bridge()
  let request = PlatformChannelRequest::new(
    channel="camera.control",
    operation="start",
    payload="{\"quality\":\"high\"}",
  )
  let id = match bridge.dispatch(HostServiceRequest::PlatformChannel(request)) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected a pending platform channel request")
  }
  ignore(channel.sync(runtime))
  let update_json = channel.drain_update_envelope_json()
  assert_true(update_json.contains("\"kind\":\"platform-channel\""))
  assert_true(update_json.contains("\"camera.control\""))

  let ok = MobileHostResponse::PlatformChannel(
    id,
    PlatformChannelResponse::Ok("{\"started\":true}"),
  )
  assert_true(
    channel.dispatch_response_envelope(
      MobileHostResponseEnvelope::new(session_generation=12, response=ok),
      driver,
    ),
  )
  assert_false(channel.dispatch_response(ok, driver))

  let error_id = match
    bridge.dispatch(HostServiceRequest::PlatformChannel(request)) {
    HostServiceResponse::Pending(next) => next
    _ => fail("expected a second pending platform channel request")
  }
  ignore(channel.sync(runtime))
  assert_true(
    channel.dispatch_response(
      MobileHostResponse::PlatformChannel(
        error_id,
        PlatformChannelResponse::Error("camera denied"),
      ),
      driver,
    ),
  )
  assert_false(
    channel.dispatch_response(
      MobileHostResponse::PlatformChannel(
        error_id,
        PlatformChannelResponse::Error("duplicate"),
      ),
      driver,
    ),
  )

  let late_id = match
    bridge.dispatch(HostServiceRequest::PlatformChannel(request)) {
    HostServiceResponse::Pending(next) => next
    _ => fail("expected a late-response fixture request")
  }
  ignore(channel.sync(runtime))
  channel.dispose()
  assert_false(
    channel.dispatch_response(
      MobileHostResponse::PlatformChannel(
        late_id,
        PlatformChannelResponse::Unavailable("disposed"),
      ),
      driver,
    ),
  )
}

///|
test "async service queue cancellation completes once" {
  let queue = HostServiceAsyncQueue::new()
  let id = match
    queue.submit(
      HostServiceRequest::PlatformChannel(
        PlatformChannelRequest::new(
          channel="camera.control",
          operation="cancel-me",
        ),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending request")
  }
  assert_true(queue.cancel(id, "cancelled"))
  assert_false(queue.cancel(id, "cancelled twice"))
  match queue.take_completed(id) {
    Some({ response: HostServiceResponse::Unavailable("cancelled"), .. }) => ()
    _ => fail("expected one cancellation completion")
  }
}
