///|
fn test_host_controller() -> (WebViewHost, WebViewController) {
  let host = WebViewHost::new()
  let origin = WebViewOrigin::parse("https://example.test").unwrap()
  let controller = host
    .create_controller(
      id="main",
      config=WebViewControllerConfig::new(
        security=WebViewSecurityPolicy::new(allowed_origins=[origin], allowed_channels=[
          WebViewChannelPolicy::new(name="rpc"),
        ]),
      ),
    )
    .unwrap()
  (host, controller)
}

///|
test "webview controller assigns FIFO command and navigation ids" {
  let (host, controller) = test_host_controller()
  let _ = controller.navigate("https://example.test/one").start(_ => ())
  let _ = controller.reload().start(_ => ())
  let commands : Array[HostWebViewQueuedCommand] = []
  ignore(host.drain_commands(command => commands.push(command)))
  inspect(commands.length(), content="2")
  assert_true(commands[0].command_id.value() < commands[1].command_id.value())
  assert_true(
    commands[0].navigation_id.unwrap().value() <
    commands[1].navigation_id.unwrap().value(),
  )
}

///|
test "webview host drops stale native generation events" {
  let (host, controller) = test_host_controller()
  let _ = controller.navigate("https://example.test/one").start(_ => ())
  let first = host.drain_commands(_ => ())
  assert_true(first == 1)
  let _ = controller.navigate("https://example.test/two").start(_ => ())
  let commands : Array[HostWebViewQueuedCommand] = []
  ignore(host.drain_commands(command => commands.push(command)))
  let current = commands[0].navigation_id.unwrap().value()
  assert_true(
    host.accept_native_event(
      controller_id="main",
      kind=3,
      navigation_raw=current - 1UL,
      url="https://example.test/one",
      detail="",
      flag=0,
    )
    is None,
  )
  assert_true(
    host.accept_native_event(
      controller_id="main",
      kind=3,
      navigation_raw=current,
      url="https://example.test/two",
      detail="",
      flag=0,
    )
    is Some(_),
  )
}

///|
test "webview host request completion is removed exactly once" {
  let (host, controller) = test_host_controller()
  let _ = controller.navigate("https://example.test").start(_ => ())
  ignore(host.drain_commands(_ => ()))
  let completion : Ref[WebViewTaskResult[Json]?] = Ref(None)
  let _cancel = controller
    .request(channel="rpc", payload=Json::null(), timeout_ms=1)
    .start(result => completion.val = Some(result))
  assert_true(host.pending_request_count() == 1)
  ignore(host.poll_timeouts(9223372036854775807L))
  assert_true(host.pending_request_count() == 0)
  match completion.val {
    Some(WebViewTaskResult::Failure(error)) =>
      inspect(error.code, content="request-timeout")
    _ => fail("request timeout did not complete")
  }
}
