///|
test "animation channels sample step linear and cubic spline" {
  let linear = @moui_3d.AnimationChannel::new(
    node=@moui_3d.NodeId::new(0),
    path=Translation,
    interpolation=Linear,
    keyframes=[
      @moui_3d.AnimationKeyframe::new(time=0.0, value=[0.0]),
      @moui_3d.AnimationKeyframe::new(time=1.0, value=[10.0]),
    ],
  )
  assert_eq(@moui_3d.sample_animation_channel(linear, 0.5), [5.0])
  let step = @moui_3d.AnimationChannel::new(
    node=@moui_3d.NodeId::new(0),
    path=Scale,
    interpolation=Step,
    keyframes=[
      @moui_3d.AnimationKeyframe::new(time=0.0, value=[1.0]),
      @moui_3d.AnimationKeyframe::new(time=1.0, value=[3.0]),
    ],
  )
  assert_eq(@moui_3d.sample_animation_channel(step, 0.8), [1.0])
  let cubic = @moui_3d.AnimationChannel::new(
    node=@moui_3d.NodeId::new(0),
    path=Translation,
    interpolation=CubicSpline,
    keyframes=[
      @moui_3d.AnimationKeyframe::new(time=0.0, value=[0.0], out_tangent=[10.0]),
      @moui_3d.AnimationKeyframe::new(time=1.0, value=[10.0], in_tangent=[10.0]),
    ],
  )
  let sampled = @moui_3d.sample_animation_channel(cubic, 0.5)
  assert_true(sampled[0] > 4.0 && sampled[0] < 6.0)
}

///|
test "animation player supports clip selection playback and seek" {
  let clip = @moui_3d.AnimationClip::new(name="walk", channels=[
    @moui_3d.AnimationChannel::new(
      node=@moui_3d.NodeId::new(2),
      path=Translation,
      interpolation=Linear,
      keyframes=[
        @moui_3d.AnimationKeyframe::new(time=0.0, value=[0.0, 0.0, 0.0]),
        @moui_3d.AnimationKeyframe::new(time=2.0, value=[2.0, 0.0, 0.0]),
      ],
    ),
  ])
  let player = @moui_3d.AnimationPlayer::new()
  player.set_clip(clip)
  player.play()
  player.advance(0.5)
  assert_true(player.playing())
  assert_eq(player.time(), 0.5)
  let samples = player.sample()
  assert_eq(samples.length(), 1)
  assert_eq(samples[0].node(), @moui_3d.NodeId::new(2))
  assert_eq(samples[0].value(), [0.5, 0.0, 0.0])
  player.seek(99.0)
  assert_eq(player.time(), 2.0)
  player.pause()
  player.advance(1.0)
  assert_eq(player.time(), 2.0)
}
