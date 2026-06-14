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
test "animated values sample visual properties" {
  inspect(
    animated_value(from=0.2, to=1.0, progress=0.0, easing=Easing::Linear),
    content="0.2",
  )
  inspect(
    animated_value(from=0.2, to=1.0, progress=1.0, easing=Easing::Linear),
    content="1",
  )
  let point = animated_point(
    from=Point::new(x=0.0, y=4.0),
    to=Point::new(x=10.0, y=14.0),
    progress=0.5,
    easing=Easing::Linear,
  )
  inspect(point.x, content="5")
  inspect(point.y, content="9")
  let sampled = animated_color(
    from=Color::rgba(r=0.0, g=0.0, b=0.0, a=0.5),
    to=Color::rgba(r=1.0, g=0.5, b=0.25, a=1.0),
    progress=0.5,
    easing=Easing::Linear,
  )
  inspect(sampled.r, content="0.5")
  inspect(sampled.g, content="0.25")
  inspect(sampled.a, content="0.75")
}

///|
test "transition samples existing visual properties" {
  let spec = TransitionSpec::new(
    from=TransitionStyle::identity()
      .with_opacity(0.0)
      .with_offset(dx=-16.0, dy=4.0)
      .with_scale(sx=0.8, sy=0.8)
      .with_foreground(Color::black()),
    to=TransitionStyle::identity().with_foreground(Color::white()),
    duration_ms=100.0,
    easing=Easing::Linear,
  )
  let sample = spec.sample(0.5)
  inspect(sample.progress, content="0.5")
  inspect(sample.style.opacity, content="0.5")
  inspect(sample.style.offset.x, content="-8")
  inspect(sample.style.offset.y, content="2")
  inspect(sample.style.scale.x, content="0.9")
  guard sample.style.foreground is Some({ r: 0.5, a: 1.0, .. }) else {
    fail("expected interpolated foreground")
  }
}

///|
test "transition respects reduced motion shortcut" {
  let value = animated_value(
    from=0.0,
    to=10.0,
    progress=0.0,
    easing=Easing::Linear,
    reduced_motion=true,
  )
  inspect(value, content="10")
  let spec = TransitionSpec::fade(from_opacity=0.0, to_opacity=1.0)
  let sample = spec.sample(0.0, reduced_motion=true)
  inspect(sample.progress, content="1")
  inspect(sample.style.opacity, content="1")
}

///|
test "presence keeps exiting content until transition completes" {
  let spec = TransitionSpec::fade(from_opacity=0.0, to_opacity=1.0)
  let entering = spec.presence(present=true, progress=0.25)
  assert_true(entering.present)
  inspect(entering.style.opacity, content="0.125")
  let exiting = spec.presence(present=false, progress=0.25)
  assert_true(exiting.present)
  inspect(exiting.style.opacity, content="0.875")
  let gone = spec.presence(present=false, progress=1.0)
  assert_false(gone.present)
  inspect(gone.style.opacity, content="0")
}

///|
test "view transition applies opacity offset scale and foreground modifiers" {
  let spec = TransitionSpec::new(
    from=TransitionStyle::identity()
      .with_opacity(0.2)
      .with_offset(dx=6.0, dy=0.0)
      .with_scale(sx=0.9, sy=0.9)
      .with_foreground(Color::blue()),
    to=TransitionStyle::identity().with_foreground(Color::black()),
    easing=Easing::Linear,
  )
  let runtime = RuntimeState::new_spec(
    root=realize_view(transitioned_text_view(spec), _msg => ()),
    size=Size::new(width=120.0, height=40.0),
  )
  let commands = runtime.build_draw_commands()
  let transform_index = first_command_index(commands, command => {
    command is PushTransform(_)
  })
  let opacity_index = first_command_index(commands, command => {
    command is PushOpacity(0.2)
  })
  let text_index = first_command_index(commands, command => {
    command is DrawText({ text: "Motion", .. })
  })
  assert_true(transform_index < opacity_index)
  assert_true(opacity_index < text_index)
  guard commands[text_index] is DrawText({ frame, color, .. }) else {
    fail("expected transitioned text")
  }
  inspect(frame.origin.x, content="6")
  assert_true(color == Color::blue())
  assert_true(
    first_command_index(commands, command => command is PopOpacity) > text_index,
  )
  assert_true(
    first_command_index(commands, command => command is PopTransform) >
    text_index,
  )
}

///|
test "view presence unmounts content after exit progress" {
  let spec = TransitionSpec::fade(from_opacity=0.0, to_opacity=1.0)
  let runtime = RuntimeState::new_spec(
    root=realize_view(exited_text_view(spec), _msg => ()),
    size=Size::new(width=120.0, height=40.0),
  )
  assert_false(has_draw_text(runtime.build_draw_commands(), "Gone"))
}

///|
fn transitioned_text_view(spec : TransitionSpec) -> View[Unit] {
  View::primitive_text_view(
    text="Motion",
    size=Size::new(width=80.0, height=20.0),
    font=FontSpec::new(),
    color=Color::gray(),
  ).transition(spec~, progress=0.0)
}

///|
fn exited_text_view(spec : TransitionSpec) -> View[Unit] {
  View::primitive_text_view(
    text="Gone",
    size=Size::new(width=80.0, height=20.0),
    font=FontSpec::new(),
    color=Color::black(),
  ).presence(present=false, spec~, progress=1.0)
}

///|
fn first_command_index(
  commands : Array[DrawCommand],
  matches : (DrawCommand) -> Bool,
) -> Int raise {
  for index, command in commands {
    if matches(command) {
      return index
    }
  }
  fail("expected matching command")
}
