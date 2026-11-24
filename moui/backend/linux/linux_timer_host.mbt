///|
/// Linux timer host bridge. A GLib timeout source on the default main context
/// calls back into MoonBit on each tick; the returned handle removes the
/// source. Used to construct a `TimerSource` for app subscriptions.
#borrow(call_closure)
#owned(tick)
extern "C" fn linux_timer_start(
  call_closure : FuncRef[(() -> Unit) -> Unit],
  interval_ms : Double,
  tick : () -> Unit,
) -> UInt64 = "moui_linux_timer_start"

///|
extern "C" fn linux_timer_cancel(handle : UInt64) -> Unit = "moui_linux_timer_cancel"

///|
/// Dispatch due GLib timeout sources and return the next deadline in
/// milliseconds, or `-1` when no GLib timer is pending. The window event loop
/// polls X11/Wayland directly, so the backend drives this from its wait hook.
extern "C" fn linux_timer_pump() -> Int32 = "moui_linux_timer_pump"

///|
/// Construct a `TimerSource` backed by the GLib main-loop timeout timer.
/// Ticks use the shared timer skeleton with interval-based frames.
pub fn linux_timer_source() -> @services.TimerSource {
  @services.TimerSource::from_native_timer(
    start=linux_timer_start,
    cancel=linux_timer_cancel,
  )
}
