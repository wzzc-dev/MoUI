///|
/// macOS timer host bridge. A repeating `dispatch_source` on the main queue
/// calls back into MoonBit on each tick; the returned handle cancels the
/// source. Used to construct a `TimerSource` so app subscriptions (toast
/// dismiss, autosave) fire on a real platform clock.
#borrow(call_closure)
#owned(tick)
extern "C" fn macos_timer_start(
  call_closure : FuncRef[(() -> Unit) -> Unit],
  interval_ms : Double,
  tick : () -> Unit,
) -> UInt64 = "moui_macos_timer_start"

///|
extern "C" fn macos_timer_cancel(handle : UInt64) -> Unit = "moui_macos_timer_cancel"

///|
/// Construct a `TimerSource` backed by the macOS main-queue dispatch timer.
/// Each tick builds a `Frame` carrying real elapsed time via the shared timer
/// skeleton; the cancel closure returned to the runtime releases the dispatch
/// source and the captured MoonBit closure.
pub fn macos_timer_source() -> @services.TimerSource {
  @services.TimerSource::from_native_timer(
    start=macos_timer_start,
    cancel=macos_timer_cancel,
    clock=Some(macos_perf_now_ms),
  )
}
