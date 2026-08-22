///|
/// glTF animation interpolation modes supported by the CPU evaluator.
pub(all) enum AnimationInterpolation {
  Step
  Linear
  CubicSpline
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AnimationPath {
  Translation
  Rotation
  Scale
  Weights
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AnimationKeyframe {
  time : Double
  value : Array[Double]
  in_tangent : Array[Double]
  out_tangent : Array[Double]
} derive(Debug)

///|
pub fn AnimationKeyframe::new(
  time~ : Double,
  value~ : Array[Double],
  in_tangent? : Array[Double] = [],
  out_tangent? : Array[Double] = [],
) -> AnimationKeyframe {
  {
    time,
    value: value.copy(),
    in_tangent: in_tangent.copy(),
    out_tangent: out_tangent.copy(),
  }
}

///|
pub fn AnimationKeyframe::time(self : AnimationKeyframe) -> Double {
  self.time
}

///|
pub fn AnimationKeyframe::value(self : AnimationKeyframe) -> Array[Double] {
  self.value.copy()
}

///|
pub fn AnimationKeyframe::in_tangent(self : AnimationKeyframe) -> Array[Double] {
  self.in_tangent.copy()
}

///|
pub fn AnimationKeyframe::out_tangent(
  self : AnimationKeyframe,
) -> Array[Double] {
  self.out_tangent.copy()
}

///|
pub(all) struct AnimationChannel {
  node : NodeId
  path : AnimationPath
  interpolation : AnimationInterpolation
  keyframes : Array[AnimationKeyframe]
} derive(Debug)

///|
pub fn AnimationChannel::new(
  node~ : NodeId,
  path~ : AnimationPath,
  interpolation~ : AnimationInterpolation,
  keyframes~ : Array[AnimationKeyframe],
) -> AnimationChannel {
  { node, path, interpolation, keyframes: keyframes.copy() }
}

///|
pub fn AnimationChannel::node(self : AnimationChannel) -> NodeId {
  self.node
}

///|
pub fn AnimationChannel::path(self : AnimationChannel) -> AnimationPath {
  self.path
}

///|
pub fn AnimationChannel::interpolation(
  self : AnimationChannel,
) -> AnimationInterpolation {
  self.interpolation
}

///|
pub fn AnimationChannel::keyframes(
  self : AnimationChannel,
) -> Array[AnimationKeyframe] {
  self.keyframes.copy()
}

///|
/// A named glTF animation clip. Channels are evaluated independently and can
/// be blended or selected by the application without coupling the scene to a
/// playback clock.
pub(all) struct AnimationClip {
  name : String
  channels : Array[AnimationChannel]
  duration : Double
} derive(Debug)

///|
pub fn AnimationClip::new(
  name? : String = "",
  channels~ : Array[AnimationChannel],
) -> AnimationClip {
  let mut duration = 0.0
  for channel in channels {
    for keyframe in channel.keyframes() {
      duration = duration.max(keyframe.time())
    }
  }
  { name, channels: channels.copy(), duration }
}

///|
pub fn AnimationClip::name(self : AnimationClip) -> String {
  self.name
}

///|
pub fn AnimationClip::channels(self : AnimationClip) -> Array[AnimationChannel] {
  self.channels.copy()
}

///|
pub fn AnimationClip::duration(self : AnimationClip) -> Double {
  self.duration
}

///|
pub(all) struct AnimationSample {
  node : NodeId
  path : AnimationPath
  value : Array[Double]
} derive(Debug)

///|
pub fn AnimationSample::new(
  node~ : NodeId,
  path~ : AnimationPath,
  value~ : Array[Double],
) -> AnimationSample {
  { node, path, value: value.copy() }
}

///|
pub fn AnimationSample::node(self : AnimationSample) -> NodeId {
  self.node
}

///|
pub fn AnimationSample::path(self : AnimationSample) -> AnimationPath {
  self.path
}

///|
pub fn AnimationSample::value(self : AnimationSample) -> Array[Double] {
  self.value.copy()
}

///|
/// CPU playback state for a selected clip. Applying samples to node TRS is
/// intentionally left to the scene owner so renderers never own animation
/// clocks or mutable scene state.
pub struct AnimationPlayer {
  mut clip : AnimationClip?
  mut time : Double
  mut playing : Bool
}

///|
pub fn AnimationPlayer::new() -> AnimationPlayer {
  { clip: None, time: 0.0, playing: false }
}

///|
pub fn AnimationPlayer::set_clip(
  self : AnimationPlayer,
  clip : AnimationClip,
) -> Unit {
  self.clip = Some(clip)
  self.time = 0.0
}

///|
pub fn AnimationPlayer::clear_clip(self : AnimationPlayer) -> Unit {
  self.clip = None
  self.time = 0.0
  self.playing = false
}

///|
pub fn AnimationPlayer::play(self : AnimationPlayer) -> Unit {
  self.playing = true
}

///|
pub fn AnimationPlayer::pause(self : AnimationPlayer) -> Unit {
  self.playing = false
}

///|
pub fn AnimationPlayer::seek(self : AnimationPlayer, time : Double) -> Unit {
  self.time = self.clamp_time(time)
}

///|
pub fn AnimationPlayer::advance(
  self : AnimationPlayer,
  delta_seconds : Double,
) -> Unit {
  if self.playing && delta_seconds > 0.0 {
    self.time = self.clamp_time(self.time + delta_seconds)
  }
}

///|
pub fn AnimationPlayer::time(self : AnimationPlayer) -> Double {
  self.time
}

///|
pub fn AnimationPlayer::playing(self : AnimationPlayer) -> Bool {
  self.playing
}

///|
pub fn AnimationPlayer::sample(
  self : AnimationPlayer,
) -> Array[AnimationSample] {
  match self.clip {
    None => []
    Some(clip) =>
      clip
      .channels()
      .map(channel => {
        AnimationSample::new(
          node=channel.node(),
          path=channel.path(),
          value=sample_animation_channel(channel, self.time),
        )
      })
  }
}

///|
fn AnimationPlayer::clamp_time(
  self : AnimationPlayer,
  value : Double,
) -> Double {
  match self.clip {
    None => 0.0
    Some(clip) => {
      let duration = clip.duration()
      if duration <= 0.0 {
        0.0
      } else if value < 0.0 {
        0.0
      } else if value > duration {
        duration
      } else {
        value
      }
    }
  }
}

///|
pub fn sample_animation_channel(
  channel : AnimationChannel,
  time : Double,
) -> Array[Double] {
  let keys = channel.keyframes()
  if keys.length() == 0 {
    return []
  }
  if keys.length() == 1 || time <= keys[0].time() {
    return keys[0].value()
  }
  let last = keys[keys.length() - 1]
  if time >= last.time() {
    return last.value()
  }
  let mut index = 0
  while index + 1 < keys.length() && time > keys[index + 1].time() {
    index = index + 1
  }
  let first = keys[index]
  let second = keys[index + 1]
  let span = second.time() - first.time()
  let t = if span <= 1.0e-12 { 0.0 } else { (time - first.time()) / span }
  let a = first.value()
  let b = second.value()
  let count = a.length().min(b.length())
  let result : Array[Double] = []
  for component in 0..<count {
    let value = match channel.interpolation() {
      AnimationInterpolation::Step => a[component]
      AnimationInterpolation::Linear =>
        a[component] + (b[component] - a[component]) * t
      AnimationInterpolation::CubicSpline => {
        let out = first.out_tangent()
        let incoming = second.in_tangent()
        let m0 = if component < out.length() {
          out[component] * span
        } else {
          0.0
        }
        let m1 = if component < incoming.length() {
          incoming[component] * span
        } else {
          0.0
        }
        let t2 = t * t
        let t3 = t2 * t
        (2.0 * t3 - 3.0 * t2 + 1.0) * a[component] +
        (t3 - 2.0 * t2 + t) * m0 +
        (-2.0 * t3 + 3.0 * t2) * b[component] +
        (t3 - t2) * m1
      }
    }
    result.push(value)
  }
  result
}
