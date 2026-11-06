///|
#derive(Eq, Debug, ToJson)
pub(all) struct Frame {
  time_ms : Double
  delta_ms : Double
}

///|
pub extend Frame with Debug::{to_repr}

///|
pub extend Frame with Eq::{not_equal, equal}

///|
pub extend Frame with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) enum AnimationStatus {
  Idle
  Running
  Completed
}

///|
pub extend AnimationStatus with Debug::{to_repr}

///|
pub extend AnimationStatus with Eq::{not_equal, equal}

///|
pub extend AnimationStatus with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) enum Easing {
  Linear
  EaseIn
  EaseOut
  EaseInOut
}

///|
pub extend Easing with Debug::{to_repr}

///|
pub extend Easing with Eq::{not_equal, equal}

///|
pub extend Easing with ToJson::{to_json}

///|
priv struct Tween {
  from : Double
  to : Double
  easing : Easing
}

///|
#derive(Eq, Debug, ToJson)
pub struct TransitionStyle {
  opacity : Double
  offset : Point
  scale : Point
  foreground : Color?
}

///|
pub extend TransitionStyle with Debug::{to_repr}

///|
pub extend TransitionStyle with Eq::{not_equal, equal}

///|
pub extend TransitionStyle with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub struct TransitionSpec {
  from : TransitionStyle
  to : TransitionStyle
  duration_ms : Double
  easing : Easing
  spring : SpringSpec?
}

///|
pub extend TransitionSpec with Debug::{to_repr}

///|
pub extend TransitionSpec with Eq::{not_equal, equal}

///|
pub extend TransitionSpec with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub struct TransitionSample {
  progress : Double
  style : TransitionStyle
  present : Bool
}

///|
pub extend TransitionSample with Debug::{to_repr}

///|
pub extend TransitionSample with Eq::{not_equal, equal}

///|
pub extend TransitionSample with ToJson::{to_json}

///|
pub fn Frame::new(time_ms~ : Double, delta_ms~ : Double) -> Frame {
  { time_ms, delta_ms, }
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
fn Tween::new(from~ : Double, to~ : Double, easing~ : Easing = Linear) -> Tween {
  { from, to, easing, }
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
  easing~ : Easing = EaseInOut,
  reduced_motion~ : Bool = false,
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
  easing~ : Easing = EaseInOut,
  reduced_motion~ : Bool = false,
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
  easing~ : Easing = EaseInOut,
  reduced_motion~ : Bool = false,
) -> Color {
  let sampled = easing.sample(if reduced_motion { 1.0 } else { progress })
  // Interpolate in premultiplied-alpha space. Straight RGBA lerp between a
  // transparent color (e.g. `rgba(0,0,0,0)`) and an opaque light tint (e.g.
  // `surface_variant`) walks the RGB toward the tint at half alpha, producing
  // a mid-transition dark gray that flashes against the surface — "light →
  // dark → light". Premultiplying keeps the visible hue at the destination
  // throughout and only ramps coverage, so a transparent→opaque-tint fade
  // stays the tint's color the whole way. When both endpoints are opaque this
  // reduces to the same lerp as before, so opaque→opaque transitions are
  // unchanged.
  let from_pa = from.r * from.a
  let from_pg = from.g * from.a
  let from_pb = from.b * from.a
  let to_pa = to.r * to.a
  let to_pg = to.g * to.a
  let to_pb = to.b * to.a
  let pa = from_pa + (to_pa - from_pa) * sampled
  let pg = from_pg + (to_pg - from_pg) * sampled
  let pb = from_pb + (to_pb - from_pb) * sampled
  let a = from.a + (to.a - from.a) * sampled
  // Un-premultiply back to straight RGBA for the renderer. A fully transparent
  // result has no defined hue; carry the destination RGB so a later increase
  // in alpha doesn't resurrect a stray color.
  if a <= 0.0 {
    Color::rgba(r=to.r, g=to.g, b=to.b, a=0.0)
  } else {
    Color::rgba(r=pa / a, g=pg / a, b=pb / a, a~)
  }
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
  opacity~ : Double = 1.0,
  offset~ : Point = Point::new(x=0.0, y=0.0),
  scale~ : Point = Point::new(x=1.0, y=1.0),
  foreground~ : Color? = None,
) -> TransitionStyle {
  { opacity, offset, scale, foreground, }
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
  dx~ : Double = self.offset.x,
  dy~ : Double = self.offset.y,
) -> TransitionStyle {
  { ..self, offset: Point::new(x=dx, y=dy), }
}

///|
pub fn TransitionStyle::with_scale(
  self : TransitionStyle,
  sx~ : Double = self.scale.x,
  sy~ : Double = self.scale.y,
) -> TransitionStyle {
  { ..self, scale: Point::new(x=sx, y=sy), }
}

///|
pub fn TransitionStyle::with_foreground(
  self : TransitionStyle,
  color : Color,
) -> TransitionStyle {
  { ..self, foreground: Some(color), }
}

///|
pub fn TransitionStyle::interpolate(
  self : TransitionStyle,
  to : TransitionStyle,
  progress~ : Double,
  easing~ : Easing = EaseInOut,
  reduced_motion~ : Bool = false,
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
  from~ : TransitionStyle = TransitionStyle::identity(),
  to~ : TransitionStyle = TransitionStyle::identity(),
  duration_ms~ : Double = 180.0,
  easing~ : Easing = EaseInOut,
) -> TransitionSpec {
  { from, to, duration_ms: max_double(0.0, duration_ms), easing, spring: None, }
}

///|
/// Drive the transition's progress with spring physics instead of the fixed
/// duration + easing curve. `duration_ms` / `easing` stay as the fallback for
/// progress-based callers; the spring's settle estimate governs
/// `sample_elapsed` / `presence` timing.
pub fn TransitionSpec::with_spring(
  self : TransitionSpec,
  spring~ : SpringSpec,
) -> TransitionSpec {
  { ..self, spring: Some(spring), }
}

///|
pub fn TransitionSpec::fade(
  from_opacity~ : Double = 0.0,
  to_opacity~ : Double = 1.0,
  duration_ms~ : Double = 180.0,
  easing~ : Easing = EaseInOut,
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
  to_offset~ : Point = Point::new(x=0.0, y=0.0),
  duration_ms~ : Double = 180.0,
  easing~ : Easing = EaseInOut,
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
  from_scale~ : Double = 0.96,
  to_scale~ : Double = 1.0,
  duration_ms~ : Double = 180.0,
  easing~ : Easing = EaseInOut,
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
  reduced_motion~ : Bool = false,
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
  reduced_motion~ : Bool = false,
) -> TransitionSample {
  let elapsed_progress = match self.spring {
    Some(spring) =>
      if reduced_motion {
        1.0
      } else {
        spring_progress(spring, elapsed_ms)
      }
    None => animation_progress(elapsed_ms, self.duration_ms)
  }
  self.sample(elapsed_progress, reduced_motion~)
}

///|
pub fn TransitionSpec::presence(
  self : TransitionSpec,
  present~ : Bool,
  progress~ : Double,
  reduced_motion~ : Bool = false,
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
  { progress: resolved, style, present: present || resolved < 1.0, }
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

///|
/// Physical spring parameterization: `damping_ratio` (ζ; below 1 bounces,
/// 1 is critically damped, above 1 eases without overshoot) and `duration_ms`
/// as the nominal settle estimate that fixes the natural frequency. Immutable;
/// the closed-form curve and the stateful solver both read from it.
#derive(Eq, Debug, ToJson)
pub(all) struct SpringSpec {
  damping_ratio : Double
  duration_ms : Double
}

///|
pub extend SpringSpec with Debug::{to_repr}

///|
pub extend SpringSpec with Eq::{not_equal, equal}

///|
pub extend SpringSpec with ToJson::{to_json}

///|
pub fn SpringSpec::new(
  damping_ratio~ : Double = 1.0,
  duration_ms~ : Double = 220.0,
) -> SpringSpec {
  {
    damping_ratio: max_double(damping_ratio, 0.05),
    duration_ms: max_double(duration_ms, 1.0),
  }
}

///|
/// Soft settle with a light bounce; good for presence and card motion.
pub fn SpringSpec::gentle() -> SpringSpec {
  SpringSpec::new(damping_ratio=0.85, duration_ms=260.0)
}

///|
/// Critically damped and fast; no overshoot, quick settle.
pub fn SpringSpec::snappy() -> SpringSpec {
  SpringSpec::new(damping_ratio=1.0, duration_ms=200.0)
}

///|
/// Playful underdamped motion with a visible overshoot.
pub fn SpringSpec::bouncy() -> SpringSpec {
  SpringSpec::new(damping_ratio=0.6, duration_ms=320.0)
}

///|
/// Envelope settle factor: the reference spring is ~99.9% settled after
/// `6.6 / ω` seconds, which fixes ω from the requested duration.
fn spring_settle_factor() -> Double {
  6.6
}

///|
fn SpringSpec::omega(self : SpringSpec) -> Double {
  spring_settle_factor() / max_double(self.duration_ms / 1000.0, 0.01)
}

///|
/// Closed-form normalized unit-displacement spring from rest toward 1.
/// ζ ≥ 1 curves are monotone; ζ < 1 overshoots past 1 and returns. Samples
/// inside the settle threshold snap to exactly 1.0 so callers can stop
/// requesting frames at a deterministic time.
pub fn spring_progress(spec : SpringSpec, elapsed_ms : Double) -> Double {
  let t = max_double(elapsed_ms, 0.0) / 1000.0
  let omega = spec.omega()
  let zeta = spec.damping_ratio
  let value = if zeta < 1.0 {
    let damped = omega * (1.0 - zeta * zeta).sqrt()
    1.0 -
    @math.exp(-zeta * omega * t) *
    (@math.cos(damped * t) + zeta * omega / damped * @math.sin(damped * t))
  } else if zeta == 1.0 {
    1.0 - (1.0 + omega * t) * @math.exp(-omega * t)
  } else {
    let spread = (zeta * zeta - 1.0).sqrt()
    let slow_root = -omega * (zeta - spread)
    let fast_root = -omega * (zeta + spread)
    1.0 -
    (
      fast_root * @math.exp(slow_root * t) -
      slow_root * @math.exp(fast_root * t)
    ) /
    (fast_root - slow_root)
  }
  if (1.0 - value).abs() < 0.001 {
    1.0
  } else {
    value
  }
}

///|
/// Stateful, interruptible spring for app-driven motion. `velocity` carries
/// across `advance` calls, so retargeting mid-flight hands the current speed
/// to the new approach instead of restarting from rest.
#derive(Eq, Debug, ToJson)
pub(all) struct SpringState {
  priv value : Double
  priv velocity : Double
}

///|
pub extend SpringState with Debug::{to_repr}

///|
pub extend SpringState with Eq::{not_equal, equal}

///|
pub extend SpringState with ToJson::{to_json}

///|
pub fn SpringState::new(value~ : Double = 0.0) -> SpringState {
  { value, velocity: 0.0, }
}

///|
pub fn SpringState::value(self : SpringState) -> Double {
  self.value
}

///|
pub fn SpringState::velocity(self : SpringState) -> Double {
  self.velocity
}

///|
/// Advance one paint frame toward `target` with semi-implicit Euler, fixed
/// 1/120 s sub-steps so a given delta integrates identically regardless of
/// display refresh rate.
pub fn SpringState::advance(
  self : SpringState,
  target~ : Double,
  frame~ : Frame,
  spec~ : SpringSpec,
) -> SpringState {
  let mut remaining = max_double(frame.delta_ms, 0.0) / 1000.0
  let mut value = self.value
  let mut velocity = self.velocity
  let omega = spec.omega()
  let zeta = spec.damping_ratio
  let substep = 1.0 / 120.0
  while remaining > 0.0 {
    let dt = if remaining < substep { remaining } else { substep }
    let acceleration = omega * omega * (target - value) -
      2.0 * zeta * omega * velocity
    velocity += acceleration * dt
    value += velocity * dt
    remaining -= dt
  }
  if (target - value).abs() < 0.001 && velocity.abs() < 0.01 {
    { value: target, velocity: 0.0, }
  } else {
    { value, velocity, }
  }
}

///|
pub fn SpringState::settled(self : SpringState, target~ : Double) -> Bool {
  (target - self.value).abs() < 0.001 && self.velocity.abs() < 0.01
}
