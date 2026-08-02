///|
/// Shared native timer host skeleton (ADR 0020). Desktop backends wrap their
/// platform timer (dispatch source / GLib timeout / timer-queue) in the same
/// `HostTimerSource` construction; only the native `start`/`cancel` externs
/// and the monotonic clock differ per platform. The optional `clock` makes
/// macOS keep its real elapsed-time frames; Linux/Windows keep their
/// interval-based frames (`clock~ = None`).
pub fn timer_host_source(
  start~ : (FuncRef[(() -> Unit) -> Unit], Double, () -> Unit) -> UInt64,
  cancel~ : (UInt64) -> Unit,
  clock? : (() -> Double)? = None,
) -> HostTimerSource {
  HostTimerSource::new(start_timer=(interval_ms, dispatch) => {
    let tick = match clock {
      None =>
        () => dispatch(@core.Frame::new(time_ms=0.0, delta_ms=interval_ms))
      Some(now) => {
        let last_time_ms = Ref(now())
        () => {
          let now_ms = now()
          let delta_ms = (now_ms - last_time_ms.val).max(0.0)
          last_time_ms.val = now_ms
          dispatch(@core.Frame::new(time_ms=now_ms, delta_ms~))
        }
      }
    }
    let handle = start(fn(callback) { callback() }, interval_ms, tick)
    Some(() => cancel(handle))
  })
}
