///|
test "animation channels sample step linear and cubic spline" {
  let linear = AnimationChannel::new(
    node=NodeId::new(0),
    path=AnimationPath::Translation,
    interpolation=AnimationInterpolation::Linear,
    keyframes=[
      AnimationKeyframe::new(time=0.0, value=[0.0]),
      AnimationKeyframe::new(time=1.0, value=[10.0]),
    ],
  )
  assert_eq(sample_animation_channel(linear, 0.5), [5.0])
  let step = AnimationChannel::new(
    node=NodeId::new(0),
    path=AnimationPath::Scale,
    interpolation=AnimationInterpolation::Step,
    keyframes=[
      AnimationKeyframe::new(time=0.0, value=[1.0]),
      AnimationKeyframe::new(time=1.0, value=[3.0]),
    ],
  )
  assert_eq(sample_animation_channel(step, 0.8), [1.0])
  let cubic = AnimationChannel::new(
    node=NodeId::new(0),
    path=AnimationPath::Translation,
    interpolation=AnimationInterpolation::CubicSpline,
    keyframes=[
      AnimationKeyframe::new(time=0.0, value=[0.0], out_tangent=[10.0]),
      AnimationKeyframe::new(time=1.0, value=[10.0], in_tangent=[10.0]),
    ],
  )
  let sampled = sample_animation_channel(cubic, 0.5)
  assert_true(sampled[0] > 4.0 && sampled[0] < 6.0)
}

///|
test "animation player supports clip selection playback and seek" {
  let clip = AnimationClip::new(name="walk", channels=[
    AnimationChannel::new(
      node=NodeId::new(2),
      path=AnimationPath::Translation,
      interpolation=AnimationInterpolation::Linear,
      keyframes=[
        AnimationKeyframe::new(time=0.0, value=[0.0, 0.0, 0.0]),
        AnimationKeyframe::new(time=2.0, value=[2.0, 0.0, 0.0]),
      ],
    ),
  ])
  let player = AnimationPlayer::new()
  player.set_clip(clip)
  player.play()
  player.advance(0.5)
  assert_true(player.playing())
  assert_eq(player.time(), 0.5)
  let samples = player.sample()
  assert_eq(samples.length(), 1)
  assert_eq(samples[0].node(), NodeId::new(2))
  assert_eq(samples[0].value(), [0.5, 0.0, 0.0])
  player.seek(99.0)
  assert_eq(player.time(), 2.0)
  player.pause()
  player.advance(1.0)
  assert_eq(player.time(), 2.0)
}
