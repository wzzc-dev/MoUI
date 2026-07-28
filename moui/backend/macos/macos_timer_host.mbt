///|
/// macOS timer host bridge. A repeating `dispatch_source` on the main queue
/// calls back into MoonBit on each tick; the returned handle cancels the
/// source. Used to construct a `HostTimerSource` so app subscriptions (toast
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
/// Construct a `HostTimerSource` backed by the macOS main-queue dispatch timer.
/// Each tick builds a `Frame` carrying the interval as `delta_ms` and dispatches
/// the subscription's mapped message. The cancel closure returned to the runtime
/// releases the dispatch source and the captured MoonBit closure.
pub fn macos_timer_source() -> @runtime.HostTimerSource {
  @runtime.HostTimerSource::new(start_timer=(interval_ms, dispatch) => {
    let last_time_ms = Ref(macos_perf_now_ms())
    let tick = () => {
      let now_ms = macos_perf_now_ms()
      let delta_ms = (now_ms - last_time_ms.val).max(0.0)
      last_time_ms.val = now_ms
      dispatch(@core.Frame::new(time_ms=now_ms, delta_ms~))
    }
    let handle = macos_timer_start(
      fn(callback) { callback() },
      interval_ms,
      tick,
    )
    Some(() => macos_timer_cancel(handle))
  })
}
