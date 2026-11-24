///|
/// The Linux host defaults to the real monotonic clock: a motion duration
/// must be wall-clock time, not one synthetic 16ms step per painted frame
/// (at a 10-20fps paint rate the step stretches a 180ms transition into
/// hundreds of milliseconds).
test "linux host app options default to a real monotonic frame clock" {
  let first = linux_monotonic_now_ms()
  assert_true(first > 0.0)
  let second = linux_monotonic_now_ms()
  assert_true(second >= first)
  let clock = match LinuxHostAppOptions::new().frame_clock {
    Some(clock) => clock
    None =>
      fail("LinuxHostAppOptions::new should default to a real frame clock")
  }
  assert_true(clock() >= second)
}

///|
/// The window loop polls X11/Wayland directly, so the backend must pump GLib
/// timeout sources itself; without this a `TimerSource` subscription never
/// ticks (and a hot-reload host never observes a new generation marker).
test "linux timer pump drives GLib timeout callbacks" {
  let ticks = Ref(0)
  let handle = linux_timer_start(fn(call) { call() }, 10.0, fn() {
    ticks.val = ticks.val + 1
  })
  guard handle != 0 else { fail("linux_timer_start returned no handle") }
  let deadline = linux_monotonic_now_ms() + 2000.0
  while ticks.val == 0 && linux_monotonic_now_ms() < deadline {
    ignore(linux_timer_pump())
  }
  linux_timer_cancel(handle)
  assert_true(ticks.val > 0)
}

///|
/// Passing `None` opts back into the synthetic step used by deterministic
/// tests and benchmarks.
test "linux host app options allow opting out of the frame clock" {
  let options = LinuxHostAppOptions::new(frame_clock=None)
  assert_true(options.frame_clock is None)
}
