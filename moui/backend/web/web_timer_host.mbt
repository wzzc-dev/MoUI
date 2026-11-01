///|
priv struct WebTimerRegistration {
  token : Int32
  interval_ms : Double
  last_time_ms : Double
  dispatch : (@core.Frame) -> Unit
}

///|
priv struct WebTimerRegistry {
  mut next_token : Int32
  mut registrations : Array[WebTimerRegistration]
  // Injectable so headless tests never link the browser wake import.
  mut wake : (Double) -> Unit
}

///|
fn WebTimerRegistry::new() -> WebTimerRegistry {
  { next_token: 1, registrations: [], wake: (_delay_ms) => () }
}

///|
let web_timer_registry : Ref[WebTimerRegistry] = Ref(WebTimerRegistry::new())

///|
/// Construct a browser timer source backed by the browser event-loop's
/// monotonic `performance.now()` clock. The Web host drains due registrations
/// on each event-loop turn, and the returned cleanup removes its registration.
pub fn web_timer_source() -> @services.TimerSource {
  web_timer_registry.val.wake = (delay_ms) =>
    web_schedule_timeout(delay_ms.ceil().to_int().max(1))
  web_timer_source_from_clock(() => web_timer_now_ms().to_double())
}

///|
fn web_timer_source_from_clock(clock : () -> Double) -> @services.TimerSource {
  @services.TimerSource::new(start=(interval_ms, dispatch) => {
    let token = web_timer_registry.val.next_token
    web_timer_registry.val.next_token = token + 1
    let interval_ms = interval_ms.max(1.0)
    web_timer_registry.val.registrations.push({
      token,
      interval_ms,
      last_time_ms: clock(),
      dispatch,
    })
    // The event loop may be waiting for input; arm a timeout so due timers
    // wake it even when the user is idle.
    (web_timer_registry.val.wake)(interval_ms)
    Some(() => web_timer_remove(token))
  })
}

///|
fn web_timer_dispatch_due() -> Unit {
  web_timer_dispatch_due_at(web_timer_now_ms().to_double())
}

///|
fn web_timer_dispatch_due_at(now_ms : Double) -> Unit {
  let next : Array[WebTimerRegistration] = []
  // Wake again for whichever registration is due soonest; dispatch only
  // happens when the loop actually runs, and the loop sleeps between
  // events, so the timer must keep its own heartbeat scheduled.
  let mut soonest : Double = -1.0
  for registration in web_timer_registry.val.registrations {
    let elapsed = (now_ms - registration.last_time_ms).max(0.0)
    if elapsed >= registration.interval_ms {
      (registration.dispatch)(
        @core.Frame::new(time_ms=now_ms, delta_ms=elapsed),
      )
      let item = { ..registration, last_time_ms: now_ms, }
      next.push(item)
      soonest = registration.interval_ms
    } else {
      let remaining = registration.interval_ms - elapsed
      soonest = if soonest < 0.0 {
        remaining
      } else {
        soonest.min(remaining)
      }
      next.push(registration)
    }
  }
  web_timer_registry.val.registrations = next
  if soonest >= 0.0 {
    (web_timer_registry.val.wake)(soonest)
  }
}

///|
fn web_timer_remove(token : Int32) -> Unit {
  let next : Array[WebTimerRegistration] = []
  for registration in web_timer_registry.val.registrations {
    if registration.token != token {
      next.push(registration)
    }
  }
  web_timer_registry.val.registrations = next
}

///|
extern "wasm" fn web_timer_now_ms() -> Int64 = "window_web" "now_ms"

extern "wasm" fn web_schedule_timeout(delay_ms : Int32) -> Unit = "window_web" "schedule_timeout"
