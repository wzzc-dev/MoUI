///|
priv struct WebTimerRegistration {
  token : Int
  interval_ms : Double
  last_time_ms : Double
  dispatch : (@core.Frame) -> Unit
}

///|
priv struct WebTimerRegistry {
  mut next_token : Int
  mut registrations : Array[WebTimerRegistration]
}

///|
fn WebTimerRegistry::new() -> WebTimerRegistry {
  { next_token: 1, registrations: [] }
}

///|
let web_timer_registry : Ref[WebTimerRegistry] = Ref(WebTimerRegistry::new())

///|
/// Construct a browser timer source backed by the browser event-loop's
/// monotonic `performance.now()` clock. The Web host drains due registrations
/// on each event-loop turn, and the returned cleanup removes its registration.
pub fn web_timer_source() -> @host.HostTimerSource {
  web_timer_source_from_clock(() => web_timer_now_ms().to_double())
}

///|
fn web_timer_source_from_clock(clock : () -> Double) -> @host.HostTimerSource {
  @host.HostTimerSource::new(start_timer=(interval_ms, dispatch) => {
    let token = web_timer_registry.val.next_token
    web_timer_registry.val.next_token = token + 1
    web_timer_registry.val.registrations.push({
      token,
      interval_ms: interval_ms.max(1.0),
      last_time_ms: clock(),
      dispatch,
    })
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
  for registration in web_timer_registry.val.registrations {
    let elapsed = (now_ms - registration.last_time_ms).max(0.0)
    if elapsed >= registration.interval_ms {
      (registration.dispatch)(
        @core.Frame::new(time_ms=now_ms, delta_ms=elapsed),
      )
      next.push({ ..registration, last_time_ms: now_ms })
    } else {
      next.push(registration)
    }
  }
  web_timer_registry.val.registrations = next
}

///|
fn web_timer_remove(token : Int) -> Unit {
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
