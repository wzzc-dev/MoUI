///|
test "spring progress starts at zero and settles exactly" {
  let spec = @core.SpringSpec::snappy()
  inspect(@core.spring_progress(spec, 0.0) == 0.0, content="true")
  inspect(@core.spring_progress(spec, 10_000.0) == 1.0, content="true")
  let bouncy = @core.SpringSpec::bouncy()
  inspect(@core.spring_progress(bouncy, 60_000.0) == 1.0, content="true")
}

///|
test "critically damped spring progress is monotone" {
  let spec = @core.SpringSpec::snappy()
  let mut previous = 0.0
  for step in 0..<80 {
    let progress = @core.spring_progress(spec, step.to_double() * 8.0)
    assert_true(progress >= previous - 0.000000001)
    previous = progress
  }
  assert_true(previous == 1.0)
}

///|
test "underdamped spring overshoots then returns" {
  let spec = @core.SpringSpec::bouncy()
  let mut peak = 0.0
  let mut peak_elapsed = 0.0
  let mut settled_value = 0.0
  for step in 0..<200 {
    let elapsed = step.to_double() * 4.0
    let progress = @core.spring_progress(spec, elapsed)
    if progress > peak {
      peak = progress
      peak_elapsed = elapsed
    }
    settled_value = progress
  }
  assert_true(peak > 1.02)
  assert_true(peak_elapsed < 600.0)
  assert_true(settled_value == 1.0)
}

///|
test "transition spec with spring reaches destination and honors reduced motion" {
  let spec = @core.TransitionSpec::fade().with_spring(
    spring=@core.SpringSpec::gentle(),
  )
  let early = spec.sample_elapsed(1.0)
  assert_true(early.style.opacity < 0.3)
  let late = spec.sample_elapsed(5_000.0)
  inspect(late.style.opacity == 1.0, content="true")
  inspect(late.progress == 1.0, content="true")
  let reduced = spec.sample_elapsed(1.0, reduced_motion=true)
  inspect(reduced.style.opacity == 1.0, content="true")
  // A spec without a spring keeps the fixed-duration sampling path.
  let eased = @core.TransitionSpec::fade(duration_ms=200.0)
  inspect(eased.sample_elapsed(100.0).style.opacity < 1.0, content="true")
  inspect(eased.sample_elapsed(200.0).style.opacity == 1.0, content="true")
}

///|
test "spring state integrates deterministically and settles" {
  let spec = @core.SpringSpec::snappy()
  let mut state = @core.SpringState::new(value=0.0)
  for _ in 0..<240 {
    state = state.advance(
      target=1.0,
      frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
      spec~,
    )
  }
  assert_true(state.settled(target=1.0))
  inspect(state.value() == 1.0, content="true")
  // Determinism: replaying the same frames yields the same mid-flight state.
  let mut replay = @core.SpringState::new(value=0.0)
  for _ in 0..<6 {
    replay = replay.advance(
      target=1.0,
      frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
      spec~,
    )
  }
  let mut mirror = @core.SpringState::new(value=0.0)
  for _ in 0..<6 {
    mirror = mirror.advance(
      target=1.0,
      frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
      spec~,
    )
  }
  inspect(replay == mirror, content="true")
  assert_true(replay.value() > 0.0 && replay.value() < 1.0)
  // The full run from the mid-flight state still settles on the target.
  let mut finished = replay
  for _ in 0..<240 {
    finished = finished.advance(
      target=1.0,
      frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
      spec~,
    )
  }
  assert_true(finished.settled(target=1.0))
}

///|
test "spring state carries velocity across a target change" {
  let spec = @core.SpringSpec::bouncy()
  let mut state = @core.SpringState::new(value=0.0)
  for _ in 0..<30 {
    state = state.advance(
      target=1.0,
      frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
      spec~,
    )
  }
  assert_true(state.velocity() > 0.0)
  // Retarget halfway: the next sample must not restart from zero velocity.
  let before_velocity = state.velocity()
  let retargeted = state.advance(
    target=0.0,
    frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
    spec~,
  )
  // The retarget must hand off momentum instead of restarting from rest.
  assert_true(retargeted.velocity() != 0.0)
  inspect(before_velocity != 0.0, content="true")
  inspect(before_velocity > 0.0, content="true")
  // Eventually the reversed spring settles at the new target.
  let mut finished = retargeted
  for _ in 0..<240 {
    finished = finished.advance(
      target=0.0,
      frame=@core.Frame::new(time_ms=0.0, delta_ms=16.6667),
      spec~,
    )
  }
  assert_true(finished.settled(target=0.0))
}

///|
test "spring-driven transition overshoots scale before settling" {
  let spec = @core.TransitionSpec::scale(from_scale=0.96, to_scale=1.0).with_spring(
    spring=@core.SpringSpec::bouncy(),
  )
  let mut peak = 0.0
  for step in 0..<200 {
    let sample = spec.sample_elapsed(step.to_double() * 5.0)
    if sample.style.scale.x > peak {
      peak = sample.style.scale.x
    }
  }
  // A bouncy spring must actually move past the destination; clamping the
  // spring progress back through the fixed easing curve would hide this.
  assert_true(peak > 1.0)
  let settled = spec.sample_elapsed(10_000.0)
  inspect(settled.style.scale.x == 1.0, content="true")
  inspect(settled.progress == 1.0, content="true")
}

///|
test "spring-driven presence keeps exiting content until settled" {
  let spec = @core.TransitionSpec::fade().with_spring(
    spring=@core.SpringSpec::bouncy(),
  )
  let early = spec.presence_elapsed(present=false, 0.0)
  assert_true(early.present)
  assert_true(early.progress < 0.01)
  let late = spec.presence_elapsed(present=false, 10_000.0)
  assert_true(!late.present)
  inspect(late.style.opacity == 0.0, content="true")
}

///|
test "spring-driven opacity stays within the valid range" {
  let spec = @core.TransitionSpec::fade().with_spring(
    spring=@core.SpringSpec::bouncy(),
  )
  for step in 0..<200 {
    let sample = spec.sample_elapsed(step.to_double() * 5.0)
    assert_true(sample.style.opacity >= 0.0)
    assert_true(sample.style.opacity <= 1.0)
  }
}
