///|
test "clock produces frame deltas" {
  let clock = Clock::new()
  let first = clock.frame(100.0)
  inspect(first.delta_ms, content="0")
  let second = clock.frame(116.0)
  inspect(second.time_ms, content="116")
  inspect(second.delta_ms, content="16")
}

///|
test "tween samples easing curves" {
  let tween = Tween::new(from=10.0, to=20.0, easing=EaseInOut)
  inspect(tween.value(0.0), content="10")
  inspect(tween.value(1.0), content="20")
  inspect(tween.value(0.5), content="15")
  inspect(Easing::EaseOut.sample(0.5), content="0.75")
}

///|
test "animation controller advances and completes" {
  let controller = AnimationController::new(duration_ms=100.0)
  controller.start()
  inspect(controller.is_active(), content="true")
  ignore(controller.tick(Frame::new(time_ms=16.0, delta_ms=40.0)))
  inspect(controller.progress(), content="0.4")
  ignore(controller.tick(Frame::new(time_ms=100.0, delta_ms=60.0)))
  assert_true(controller.status == AnimationStatus::Completed)
  inspect(controller.progress(), content="1")
}

///|
test "runtime requests redraw while animations are active" {
  let scheduled = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::EmptySpec,
    size=Size::new(width=10.0, height=10.0),
  )
  runtime.set_redraw_callback(() => scheduled.val = scheduled.val + 1)
  runtime.dispatch_event(Redraw(Initial))
  inspect(runtime.needs_redraw, content="false")
  let controller = AnimationController::new(duration_ms=32.0)
  controller.start()
  runtime.add_animation(controller)
  inspect(runtime.animation_count(), content="1")
  inspect(scheduled.val, content="1")
  runtime.advance_time(0.0)
  runtime.dispatch_event(Redraw(Explicit))
  inspect(runtime.needs_redraw, content="true")
  runtime.advance_time(16.0)
  runtime.dispatch_event(Redraw(Explicit))
  inspect(runtime.needs_redraw, content="true")
  runtime.advance_time(32.0)
  runtime.dispatch_event(Redraw(Explicit))
  inspect(runtime.needs_redraw, content="false")
}

///|
test "animated values sample visual properties" {
  let opacity = AnimatedDouble::new(from=0.2, to=1.0, duration_ms=100.0)
  inspect(opacity.value(0.0), content="0.2")
  inspect(opacity.value(100.0), content="1")
  let point = AnimatedPoint::new(
    from=Point::new(x=0.0, y=4.0),
    to=Point::new(x=10.0, y=14.0),
    duration_ms=100.0,
    easing=Easing::Linear,
  )
  inspect(point.value(50.0).x, content="5")
  inspect(point.value(50.0).y, content="9")
  let color = AnimatedColor::new(
    from=Color::rgba(r=0.0, g=0.0, b=0.0, a=0.5),
    to=Color::rgba(r=1.0, g=0.5, b=0.25, a=1.0),
    duration_ms=100.0,
    easing=Easing::Linear,
  )
  let sampled = color.value(50.0)
  inspect(sampled.r, content="0.5")
  inspect(sampled.g, content="0.25")
  inspect(sampled.a, content="0.75")
}
