///|
test "timer_host_source interval mode dispatches interval frames" {
  let dispatches : Ref[Array[Double]] = Ref([])
  let source = timer_host_source(
    start=fn(
      _call : FuncRef[(() -> Unit) -> Unit],
      _interval_ms : Double,
      tick : () -> Unit,
    ) -> UInt64 {
      tick()
      tick()
      7
    },
    cancel=fn(_handle : UInt64) -> Unit {
    },
  )
  let start_timer = source.start_timer_fn
  let cancel = start_timer(50.0, frame => dispatches.val.push(frame.delta_ms))
  inspect(dispatches.val, content="[50, 50]")
  guard cancel is Some(stop) else {
    fail("expected a cancel closure")
  }
  stop()
}

///|
test "timer_host_source clock mode reports real elapsed time" {
  let dispatches : Ref[Array[Double]] = Ref([])
  let mut now_ms = 100.0
  let source = timer_host_source(
    start=fn(
      _call : FuncRef[(() -> Unit) -> Unit],
      _interval_ms : Double,
      tick : () -> Unit,
    ) -> UInt64 {
      tick()
      now_ms = 130.0
      tick()
      tick()
      9
    },
    cancel=fn(_handle : UInt64) -> Unit {
    },
    clock=Some(() => now_ms),
  )
  let start_timer = source.start_timer_fn
  let cancel = start_timer(50.0, frame => dispatches.val.push(frame.delta_ms))
  inspect(dispatches.val, content="[0, 30, 0]")
  guard cancel is Some(stop) else {
    fail("expected a cancel closure")
  }
  stop()
}
