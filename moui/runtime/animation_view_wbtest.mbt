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
  let runtime = RuntimeState::new_view(
    root=transitioned_text_view(spec),
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
  let runtime = RuntimeState::new_view(
    root=exited_text_view(spec),
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
