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
