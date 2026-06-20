///|
/// Linux timer host bridge. A GLib timeout source on the default main context
/// calls back into MoonBit on each tick; the returned handle removes the
/// source. Used to construct a `HostTimerSource` for app subscriptions.

#borrow(call_closure)
#owned(tick)
extern "C" fn linux_timer_start(
  call_closure : FuncRef[((() -> Unit), ) -> Unit],
  interval_ms : Double,
  tick : () -> Unit,
) -> UInt64 = "moui_linux_timer_start"

///|
extern "C" fn linux_timer_cancel(handle : UInt64) -> Unit = "moui_linux_timer_cancel"

///|
/// Construct a `HostTimerSource` backed by the GLib main-loop timeout timer.
pub fn linux_timer_source() -> @host.HostTimerSource {
  @host.HostTimerSource::new(
    start_timer=(interval_ms, dispatch) => {
      let tick = () => {
        dispatch(@core.Frame::new(time_ms=0.0, delta_ms=interval_ms))
      }
      let handle = linux_timer_start(
        fn(callback) {
          callback()
        },
        interval_ms,
        tick,
      )
      Some(() => linux_timer_cancel(handle))
    },
  )
}
