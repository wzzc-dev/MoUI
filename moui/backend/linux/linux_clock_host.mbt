///|
/// Monotonic host milliseconds for the runtime frame clock.
extern "C" fn linux_monotonic_now_ms() -> Double = "moui_linux_monotonic_now_ms"

///|
/// The default Linux frame clock: real monotonic milliseconds, so motion
/// durations are wall-clock time rather than a fixed 16ms per painted frame.
///
/// Pass `frame_clock=None` to `LinuxHostAppOptions::new` to opt back into the
/// synthetic step (deterministic frame stepping in tests and benchmarks).
pub fn linux_frame_clock() -> () -> Double {
  () => linux_monotonic_now_ms()
}
