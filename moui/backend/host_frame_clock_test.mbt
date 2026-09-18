///|
/// A host `frame_clock` drives the animation clock with real monotonic
/// milliseconds: every redraw advances `now_ms` by the clock's own step, so
/// paint-time animations sample real time on any refresh rate (60Hz, 120Hz
/// ProMotion, variable refresh) instead of a synthetic 16ms-per-frame step.
test "host frame clock advances the paint clock in real time" {
  let seen = Ref(-1.0)
  let view = @views.animated_canvas(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width=10.0, height=10.0))
    },
    draw=(_ctx, _frame, now_ms) => seen.val = now_ms,
  )
  let runtime = host_test_runtime(
    root=view,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let now = Ref(1000.0)
  let driver = @runtime.HostRuntimeDriver::new(
    runtime~,
    schedule_redraw=() => (),
    frame_clock=Some(() => now.val),
  )
  driver.begin_redraw()
  ignore(driver.draw_commands())
  assert_eq(seen.val, 1000.0)
  // A 120Hz frame: the clock advances by the host's real step, not 16ms.
  now.val = 1008.333
  driver.begin_redraw()
  ignore(driver.draw_commands())
  assert_eq(seen.val, 1008.333)
}

///|
/// Without a host clock the driver keeps the synthetic fixed step so
/// paint-time animations still progress without user input.
test "host driver without a frame clock keeps the synthetic step" {
  let seen = Ref(-1.0)
  let view = @views.animated_canvas(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width=10.0, height=10.0))
    },
    draw=(_ctx, _frame, now_ms) => seen.val = now_ms,
  )
  let runtime = host_test_runtime(
    root=view,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  driver.begin_redraw()
  ignore(driver.draw_commands())
  assert_eq(seen.val, 16.0)
  driver.begin_redraw()
  ignore(driver.draw_commands())
  assert_eq(seen.val, 32.0)
}
