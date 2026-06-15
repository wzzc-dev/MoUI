///|
priv struct Clock {
  mut last_time_ms : Double?
}

///|
fn Clock::new() -> Clock {
  { last_time_ms: None }
}

///|
fn Clock::frame(self : Clock, time_ms : Double) -> Frame {
  let delta = match self.last_time_ms {
    Some(last) => (time_ms - last).max(0.0)
    None => 0.0
  }
  self.last_time_ms = Some(time_ms)
  { time_ms, delta_ms: delta }
}
