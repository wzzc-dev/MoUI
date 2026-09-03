///|
test "harmonyos demo update changes model" {
  let tapped = update(Model::new(), TapDemo)
  inspect(tapped.tap_count, content="1")
  let rendered = update(tapped, MarkRendered)
  inspect(rendered.render_hint, content="1")
  inspect(update(rendered, Reset).tap_count, content="0")
}

///|
test "harmonyos demo runtime responds to button click and viewport" {
  // The demo content column is taller than 360; clip-aware hit testing
  // rejects clicks outside the viewport, so use a height that shows the buttons.
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=520.0,
    height=560.0,
  )
  assert_true(has_text(runtime.draw_commands(), "MoUI HarmonyOS Demo"))
  assert_true(has_text(runtime.draw_commands(), "520 x 560"))
  click_text(runtime, "Tap")
  assert_true(has_text(runtime.draw_commands(), "1"))
}

///|
test "harmonyos demo starts at the top of a tall viewport" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=520.0,
    height=900.0,
  )
  guard text_frame(runtime.draw_commands(), "MoUI HarmonyOS Demo")
    is Some(frame) else {
    fail("expected title frame")
  }
  assert_true(frame.origin.y < 80.0)
}

///|
fn click_text(runtime : @runtime.AppRuntime, label : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), label) is Some(frame) else {
    fail("expected text frame")
  }
  let point = @geometry.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], value : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text, .. }) && text == value
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  value : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text, frame, .. }) =>
        if text == value {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
