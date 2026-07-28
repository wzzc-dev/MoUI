///|
/// Windows timer host bridge. A timer-queue timer calls back into MoonBit on
/// each tick; the returned handle cancels the timer. Used to construct a
/// `HostTimerSource` for app subscriptions (toast dismiss, autosave).
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
/// Construct a `HostTimerSource` backed by the Windows timer-queue timer.
pub fn windows_timer_source() -> @runtime.HostTimerSource {
  @runtime.HostTimerSource::new(start_timer=(interval_ms, dispatch) => {
    let tick = () => {
      dispatch(@core.Frame::new(time_ms=0.0, delta_ms=interval_ms))
    }
    let handle = windows_timer_start(
      fn(callback) { callback() },
      interval_ms,
      tick,
    )
    Some(() => windows_timer_cancel(handle))
  })
}
