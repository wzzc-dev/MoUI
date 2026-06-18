///|
pub(all) struct Frame {
  time_ms : Double
  delta_ms : Double
} derive(Eq, Debug, ToJson)

///|
pub struct Clock {
  mut last_time_ms : Double?
}

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
priv struct Tween {
  from : Double
  to : Double
  easing : Easing
}

///|
pub struct TransitionStyle {
  opacity : Double
  offset : Point
  scale : Point
  foreground : Color?
} derive(Eq, Debug, ToJson)

///|
pub struct TransitionSpec {
  from : TransitionStyle
  to : TransitionStyle
  duration_ms : Double
  easing : Easing
} derive(Eq, Debug, ToJson)

///|
pub struct TransitionSample {
  progress : Double
  style : TransitionStyle
  present : Bool
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
fn Tween::new(
  from~ : Double,
  to~ : Double,
  easing? : Easing = Easing::Linear,
) -> Tween {
  { from, to, easing }
}

///|
fn Tween::value(self : Tween, progress : Double) -> Double {
  self.from + (self.to - self.from) * self.easing.sample(progress)
}

///|
pub fn animated_value(
  from~ : Double,
  to~ : Double,
  progress~ : Double,
  easing? : Easing = Easing::EaseInOut,
  reduced_motion? : Bool = false,
) -> Double {
  Tween::new(from~, to~, easing~).value(
    if reduced_motion {
      1.0
    } else {
      progress
    },
  )
}

///|
pub fn animated_point(
  from~ : Point,
  to~ : Point,
  progress~ : Double,
  easing? : Easing = Easing::EaseInOut,
  reduced_motion? : Bool = false,
) -> Point {
  let sampled = easing.sample(if reduced_motion { 1.0 } else { progress })
  Point::new(
    x=from.x + (to.x - from.x) * sampled,
    y=from.y + (to.y - from.y) * sampled,
  )
}

///|
pub fn animated_color(
  from~ : Color,
  to~ : Color,
  progress~ : Double,
  easing? : Easing = Easing::EaseInOut,
  reduced_motion? : Bool = false,
) -> Color {
  let sampled = easing.sample(if reduced_motion { 1.0 } else { progress })
  Color::rgba(
    r=from.r + (to.r - from.r) * sampled,
    g=from.g + (to.g - from.g) * sampled,
    b=from.b + (to.b - from.b) * sampled,
    a=from.a + (to.a - from.a) * sampled,
  )
}

///|
pub fn TransitionStyle::identity() -> TransitionStyle {
  {
    opacity: 1.0,
    offset: Point::new(x=0.0, y=0.0),
    scale: Point::new(x=1.0, y=1.0),
    foreground: None,
  }
}

///|
pub fn TransitionStyle::new(
  opacity? : Double = 1.0,
  offset? : Point = Point::new(x=0.0, y=0.0),
  scale? : Point = Point::new(x=1.0, y=1.0),
  foreground? : Color? = None,
) -> TransitionStyle {
  { opacity, offset, scale, foreground }
}

///|
pub fn TransitionStyle::with_opacity(
  self : TransitionStyle,
  opacity : Double,
) -> TransitionStyle {
  { ..self, opacity, }
}

///|
pub fn TransitionStyle::with_offset(
  self : TransitionStyle,
  dx? : Double = self.offset.x,
  dy? : Double = self.offset.y,
) -> TransitionStyle {
  { ..self, offset: Point::new(x=dx, y=dy) }
}

///|
pub fn TransitionStyle::with_scale(
  self : TransitionStyle,
  sx? : Double = self.scale.x,
  sy? : Double = self.scale.y,
) -> TransitionStyle {
  { ..self, scale: Point::new(x=sx, y=sy) }
}

///|
pub fn TransitionStyle::with_foreground(
  self : TransitionStyle,
  color : Color,
) -> TransitionStyle {
  { ..self, foreground: Some(color) }
}

///|
pub fn TransitionStyle::interpolate(
  self : TransitionStyle,
  to : TransitionStyle,
  progress~ : Double,
  easing? : Easing = Easing::EaseInOut,
  reduced_motion? : Bool = false,
) -> TransitionStyle {
  {
    opacity: animated_value(
      from=self.opacity,
      to=to.opacity,
      progress~,
      easing~,
      reduced_motion~,
    ),
    offset: animated_point(
      from=self.offset,
      to=to.offset,
      progress~,
      easing~,
      reduced_motion~,
    ),
    scale: animated_point(
      from=self.scale,
      to=to.scale,
      progress~,
      easing~,
      reduced_motion~,
    ),
    foreground: option_interpolate_color(
      self.foreground,
      to.foreground,
      progress~,
      easing~,
      reduced_motion~,
    ),
  }
}

///|
pub fn TransitionSpec::new(
  from? : TransitionStyle = TransitionStyle::identity(),
  to? : TransitionStyle = TransitionStyle::identity(),
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> TransitionSpec {
  { from, to, duration_ms: max_double(0.0, duration_ms), easing }
}

///|
pub fn TransitionSpec::fade(
  from_opacity? : Double = 0.0,
  to_opacity? : Double = 1.0,
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> TransitionSpec {
  TransitionSpec::new(
    from=TransitionStyle::identity().with_opacity(from_opacity),
    to=TransitionStyle::identity().with_opacity(to_opacity),
    duration_ms~,
    easing~,
  )
}

///|
pub fn TransitionSpec::slide(
  from_offset~ : Point,
  to_offset? : Point = Point::new(x=0.0, y=0.0),
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> TransitionSpec {
  TransitionSpec::new(
    from=TransitionStyle::identity().with_offset(
      dx=from_offset.x,
      dy=from_offset.y,
    ),
    to=TransitionStyle::identity().with_offset(dx=to_offset.x, dy=to_offset.y),
    duration_ms~,
    easing~,
  )
}

///|
pub fn TransitionSpec::scale(
  from_scale? : Double = 0.96,
  to_scale? : Double = 1.0,
  duration_ms? : Double = 180.0,
  easing? : Easing = Easing::EaseInOut,
) -> TransitionSpec {
  TransitionSpec::new(
    from=TransitionStyle::identity().with_scale(sx=from_scale, sy=from_scale),
    to=TransitionStyle::identity().with_scale(sx=to_scale, sy=to_scale),
    duration_ms~,
    easing~,
  )
}

///|
pub fn TransitionSpec::sample(
  self : TransitionSpec,
  progress : Double,
  reduced_motion? : Bool = false,
) -> TransitionSample {
  let resolved = transition_resolved_progress(progress, reduced_motion~)
  {
    progress: resolved,
    style: self.from.interpolate(
      self.to,
      progress=resolved,
      easing=self.easing,
      reduced_motion=false,
    ),
    present: true,
  }
}

///|
pub fn TransitionSpec::sample_elapsed(
  self : TransitionSpec,
  elapsed_ms : Double,
  reduced_motion? : Bool = false,
) -> TransitionSample {
  self.sample(animation_progress(elapsed_ms, self.duration_ms), reduced_motion~)
}

///|
pub fn TransitionSpec::presence(
  self : TransitionSpec,
  present~ : Bool,
  progress~ : Double,
  reduced_motion? : Bool = false,
) -> TransitionSample {
  let resolved = transition_resolved_progress(progress, reduced_motion~)
  let style = if present {
    self.from.interpolate(
      self.to,
      progress=resolved,
      easing=self.easing,
      reduced_motion=false,
    )
  } else {
    self.to.interpolate(
      self.from,
      progress=resolved,
      easing=self.easing,
      reduced_motion=false,
    )
  }
  { progress: resolved, style, present: present || resolved < 1.0 }
}

///|
fn option_interpolate_color(
  from : Color?,
  to : Color?,
  progress~ : Double,
  easing~ : Easing,
  reduced_motion~ : Bool,
) -> Color? {
  match (from, to) {
    (Some(start), Some(end)) =>
      Some(
        animated_color(from=start, to=end, progress~, easing~, reduced_motion~),
      )
    (None, Some(end)) => Some(end)
    (Some(start), None) => Some(start)
    (None, None) => None
  }
}

///|
fn transition_resolved_progress(
  progress : Double,
  reduced_motion~ : Bool,
) -> Double {
  if reduced_motion {
    1.0
  } else {
    clamp_double(progress, 0.0, 1.0)
  }
}

///|
fn animation_progress(elapsed_ms : Double, duration_ms : Double) -> Double {
  if duration_ms <= 0.0 {
    1.0
  } else {
    clamp_double(elapsed_ms / duration_ms, 0.0, 1.0)
  }
}
