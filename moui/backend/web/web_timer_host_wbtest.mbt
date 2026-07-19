///|
test "web timer source dispatches elapsed browser frames and cleans up" {
  let frames : Array[@core.Frame] = []
  let source = web_timer_source_from_clock(() => 100.0)
  let subscription = source.subscription(
    interval_ms=250.0,
    key="web:timer-test",
    label="Web timer test",
    map=frame => frame,
  )
  let runtime_source = subscription.runtime_sources()[0]
  let cleanup = runtime_source.start(frame => frames.push(frame))
  web_timer_dispatch_due_at(349.0)
  inspect(frames.length(), content="0")
  web_timer_dispatch_due_at(350.0)
  inspect(frames.length(), content="1")
  inspect(frames[0].time_ms, content="350")
  inspect(frames[0].delta_ms, content="250")
  match cleanup {
    Some(cancel) => cancel()
    None => fail("expected browser timer cleanup")
  }
  web_timer_dispatch_due_at(700.0)
  inspect(frames.length(), content="1")
}
