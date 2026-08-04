///|
/// Windows timer host bridge. A timer-queue timer calls back into MoonBit on
/// each tick; the returned handle cancels the timer. Used to construct a
/// `TimerSource` for app subscriptions (toast dismiss, autosave).
#borrow(call_closure)
#owned(tick)
extern "C" fn windows_timer_start(
  call_closure : FuncRef[(() -> Unit) -> Unit],
  interval_ms : Double,
  tick : () -> Unit,
) -> UInt64 = "moui_windows_timer_start"

///|
extern "C" fn windows_timer_cancel(handle : UInt64) -> Unit = "moui_windows_timer_cancel"

///|
/// Construct a `TimerSource` backed by the Windows timer-queue timer.
/// Ticks use the shared timer skeleton with interval-based frames.
pub fn windows_timer_source() -> @services.TimerSource {
  @services.TimerSource::from_native_timer(
    start=windows_timer_start,
    cancel=windows_timer_cancel,
  )
}
