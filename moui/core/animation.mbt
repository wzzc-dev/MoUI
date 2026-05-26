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
pub(all) struct AnimatedDouble {
  from : Double
  to : Double
  duration_ms : Double
  easing : Easing
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AnimatedPoint {
  from : Point
  to : Point
  duration_ms : Double
  easing : Easing
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AnimatedColor {
  from : Color
  to : Color
  duration_ms : Double
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
        1.0 - (-2.0 * t + 2.0) * (-2.0 * t + 2.0) / 2.0
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
pub fn AnimatedDouble::new(
  from~ : Double,
  to~ : Double,
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> AnimatedDouble {
  { from, to, duration_ms: max_double(0.0, duration_ms), easing }
}

///|
pub fn AnimatedDouble::value(
  self : AnimatedDouble,
  elapsed_ms : Double,
) -> Double {
  Tween::new(from=self.from, to=self.to, easing=self.easing).value(
    animation_progress(elapsed_ms, self.duration_ms),
  )
}

///|
pub fn AnimatedPoint::new(
  from~ : Point,
  to~ : Point,
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> AnimatedPoint {
  { from, to, duration_ms: max_double(0.0, duration_ms), easing }
}

///|
pub fn AnimatedPoint::value(self : AnimatedPoint, elapsed_ms : Double) -> Point {
  let progress = self.easing.sample(
    animation_progress(elapsed_ms, self.duration_ms),
  )
  Point::new(
    x=self.from.x + (self.to.x - self.from.x) * progress,
    y=self.from.y + (self.to.y - self.from.y) * progress,
  )
}

///|
pub fn AnimatedColor::new(
  from~ : Color,
  to~ : Color,
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> AnimatedColor {
  { from, to, duration_ms: max_double(0.0, duration_ms), easing }
}

///|
pub fn AnimatedColor::value(self : AnimatedColor, elapsed_ms : Double) -> Color {
  let progress = self.easing.sample(
    animation_progress(elapsed_ms, self.duration_ms),
  )
  Color::rgba(
    r=self.from.r + (self.to.r - self.from.r) * progress,
    g=self.from.g + (self.to.g - self.from.g) * progress,
    b=self.from.b + (self.to.b - self.from.b) * progress,
    a=self.from.a + (self.to.a - self.from.a) * progress,
  )
}

///|
fn animation_progress(elapsed_ms : Double, duration_ms : Double) -> Double {
  if duration_ms <= 0.0 {
    1.0
  } else {
    clamp_double(elapsed_ms / duration_ms, 0.0, 1.0)
  }
}

///|
pub fn AnimationController::new(duration_ms~ : Double) -> AnimationController {
  { duration_ms: max_double(0.0, duration_ms), elapsed_ms: 0.0, status: Idle }
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
pub fn AnimationController::tick(
  self : AnimationController,
  frame : Frame,
) -> Bool {
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
