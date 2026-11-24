///|
/// A timer subscription the app registered against the hot dev environment.
/// The host drives time through `FrameTick` events, and the plugin fires due
/// timers from that same tick, so app timers keep running without a platform
/// event loop of their own inside the plugin image.
priv struct HotTimer {
  token : Int32
  interval_ms : Double
  dispatch : (@core.Frame) -> Unit
  mut next_due_ms : Double
}

///|
priv struct HotTimerRegistry {
  mut next_token : Int32
  mut timers : Array[HotTimer]
  mut now_ms : Double
}

///|
let hot_timer_registry : Ref[HotTimerRegistry] = Ref({
  next_token: 1,
  timers: [],
  now_ms: 0.0,
})

///|
/// The latest host frame time. `AppEnvironment::clock()` in a hot plugin reads
/// this so app timestamps share the host frame timeline.
pub fn hot_now_ms() -> Double {
  hot_timer_registry.val.now_ms
}

///|
fn reset_hot_time() -> Unit {
  hot_timer_registry.val = { next_token: 1, timers: [], now_ms: 0.0, }
}

///|
fn clear_hot_timers() -> Unit {
  hot_timer_registry.val.timers = []
}

///|
/// Build the dev environment handed to an app factory in hot mode.
///
/// The timer source registers app timer subscriptions with the plugin; the
/// host's periodic `FrameTick` delivery makes them fire. Platform services the
/// host owns stay unavailable here: a plugin only receives the app-visible
/// events the bridge forwards.
pub fn hot_environment() -> @services.AppEnvironment {
  // A fresh program is constructed for every generation, and its subscription
  // start callbacks must not see handles from the previous generation.
  reset_hot_time()
  let timer = @services.TimerSource::new(start=(interval_ms, dispatch) => {
    let registry = hot_timer_registry.val
    let token = registry.next_token
    registry.next_token = token + 1
    let interval = if interval_ms > 0.0 { interval_ms } else { 1.0 }
    registry.timers.push({
      token,
      interval_ms: interval,
      dispatch,
      next_due_ms: registry.now_ms + interval,
    })
    Some(() => {
      hot_timer_registry.val.timers = hot_timer_registry.val.timers.filter(timer => {
        timer.token != token
      })
    })
  })
  @services.AppEnvironment::new(timer=Some(timer), clock=Some(hot_now_ms))
}

///|
/// Advance the dev clock with a host frame and fire every timer that is due.
/// Timers fire before the event is dispatched so update work driven by a timer
/// is visible in the frame produced for the same tick.
fn advance_hot_time(frame : @core.Frame) -> Unit {
  let registry = hot_timer_registry.val
  registry.now_ms = frame.time_ms
  let due : Array[HotTimer] = []
  for timer in registry.timers {
    if timer.next_due_ms <= frame.time_ms {
      due.push(timer)
    }
  }
  for timer in due {
    // One catch-up fire per tick keeps a stalled host from replaying a burst
    // of timer messages; the due time re-anchors to the current frame.
    let mut next_due = timer.next_due_ms + timer.interval_ms
    if next_due <= frame.time_ms {
      next_due = frame.time_ms + timer.interval_ms
    }
    timer.next_due_ms = next_due
    (timer.dispatch)(frame)
  }
}
