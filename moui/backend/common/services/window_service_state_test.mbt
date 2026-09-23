///|
test "window service state rejects re-entry and disposes exactly once" {
  let handled = Ref(0)
  let disposed = Ref(0)
  let reentry_closed = Ref(false)
  let holder : Ref[@services.WindowServiceState?] = Ref(None)
  let state = @services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(open_url=true),
      handle=_request => {
        handled.val = handled.val + 1
        UrlOpened
      },
    ),
    dispose=() => {
      disposed.val = disposed.val + 1
      match holder.val {
        Some(current) =>
          reentry_closed.val = current
            .bridge()
            .dispatch(OpenUrl("https://closed.test"))
            is Unavailable(_)
        None => ()
      }
    },
  )
  holder.val = Some(state)
  ignore(state.bridge().dispatch(OpenUrl("https://open.test")))
  inspect(handled.val, content="1")
  state.dispose()
  state.dispose()
  inspect(disposed.val, content="1")
  assert_true(reentry_closed.val)
  inspect(handled.val, content="1")
  assert_false(state.is_open())
}
