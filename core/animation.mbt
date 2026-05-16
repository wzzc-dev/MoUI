///|
pub(all) struct Frame {
  time_ms : Double
  delta_ms : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Clock {
  mut last_time_ms : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AnimationStatus {
  Idle
  Running
  Completed
} derive(Eq, Debug, ToJson)

///|
pub(all) enum Easing {
  Linear
  EaseIn
  EaseOut
  EaseInOut
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Tween {
  from : Double
  to : Double
  easing : Easing
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AnimationController {
  duration_ms : Double
  mut elapsed_ms : Double
  mut status : AnimationStatus
} derive(Eq, Debug, ToJson)

///|
pub fn Frame::new(time_ms~ : Double, delta_ms~ : Double) -> Frame {
  { time_ms, delta_ms }
}

///|
pub fn Clock::new() -> Clock {
  { last_time_ms: None }
}

///|
pub fn Clock::frame(self : Clock, time_ms : Double) -> Frame {
  let delta = match self.last_time_ms {
    Some(last) => max_double(0.0, time_ms - last)
    None => 0.0
  }
  self.last_time_ms = Some(time_ms)
  Frame::new(time_ms~, delta_ms=delta)
}

///|
pub fn Easing::sample(self : Easing, progress : Double) -> Double {
  let t = clamp_double(progress, 0.0, 1.0)
  match self {
    Linear => t
    EaseIn => t * t
    EaseOut => 1.0 - (1.0 - t) * (1.0 - t)
    EaseInOut =>
      if t < 0.5 {
        2.0 * t * t
      } else {
        1.0 - ((-2.0 * t + 2.0) * (-2.0 * t + 2.0)) / 2.0
      }
  }
}

///|
pub fn Tween::new(
  from~ : Double,
  to~ : Double,
  easing? : Easing = Easing::Linear,
) -> Tween {
  { from, to, easing }
}

///|
pub fn Tween::value(self : Tween, progress : Double) -> Double {
  self.from + (self.to - self.from) * self.easing.sample(progress)
}

///|
pub fn AnimationController::new(
  duration_ms~ : Double,
) -> AnimationController {
  {
    duration_ms: max_double(0.0, duration_ms),
    elapsed_ms: 0.0,
    status: Idle,
  }
}

///|
pub fn AnimationController::start(self : AnimationController) -> Unit {
  self.elapsed_ms = 0.0
  self.status = if self.duration_ms <= 0.0 { Completed } else { Running }
}

///|
pub fn AnimationController::stop(self : AnimationController) -> Unit {
  self.status = Idle
}

///|
pub fn AnimationController::reset(self : AnimationController) -> Unit {
  self.elapsed_ms = 0.0
  self.status = Idle
}

///|
pub fn AnimationController::tick(self : AnimationController, frame : Frame) -> Bool {
  if self.status != Running {
    false
  } else {
    self.elapsed_ms = min_double(
      self.duration_ms,
      self.elapsed_ms + max_double(0.0, frame.delta_ms),
    )
    if self.elapsed_ms >= self.duration_ms {
      self.status = Completed
    }
    true
  }
}

///|
pub fn AnimationController::progress(self : AnimationController) -> Double {
  if self.duration_ms <= 0.0 {
    1.0
  } else {
    clamp_double(self.elapsed_ms / self.duration_ms, 0.0, 1.0)
  }
}

///|
pub fn AnimationController::is_active(self : AnimationController) -> Bool {
  self.status == Running
}
