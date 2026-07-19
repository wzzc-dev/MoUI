///|
test "session epochs advance only on a viable attach" {
  let session = ShellSession::new(generation=7)
  inspect(session.surface_epoch(), content="0")
  inspect(session.attach(), content="true")
  inspect(session.surface_epoch(), content="1")
  inspect(session.detach(), content="true")
  inspect(session.destroy(), content="true")
  inspect(session.attach(), content="false")
}

///|
test "frame scheduler coalesces requests raised in frame" {
  let scheduler = ShellFrameScheduler::new()
  scheduler.request()
  inspect(scheduler.begin_frame(), content="true")
  scheduler.request()
  inspect(scheduler.finish_frame(), content="true")
  inspect(scheduler.begin_frame(), content="true")
}

///|
test "channel rejects stale responses" {
  let channel = ShellChannel::new()
  let request = channel.begin_request()
  inspect(channel.complete(request), content="true")
  inspect(channel.complete(request), content="false")
}

///|
test "wire envelope retains update request correlation and session epoch" {
  let session = ShellSession::new(generation=9)
  assert_true(session.attach())
  let channel = ShellChannel::new()
  let request = channel.begin_request()
  assert_true(
    channel.enqueue_update(kind="clipboard", request_id=Some(request), payload={
      "operation": "read-text",
    }),
  )
  let encoded = channel.drain_update_envelope(session).to_json_string()
  let decoded = parse_wire_envelope_json(encoded).unwrap()
  inspect(decoded.session_generation, content="9")
  inspect(decoded.surface_epoch, content="1")
  inspect(decoded.updates.length(), content="1")
  assert_true(decoded.updates[0].request_id is Some(_))
}

///|
test "descriptor negotiation reports an unavailable capability" {
  let descriptor : ShellPlatformDescriptor = {
    platform: Android,
    shell_api_version: 1,
    embedding_api_version: 1,
    capabilities: [Surface],
  }
  assert_true(
    descriptor.negotiate(shell_api_version=1, embedding_api_version=1, required_capabilities=[
      Clipboard,
    ])
    is CapabilityMissing(Clipboard),
  )
}
