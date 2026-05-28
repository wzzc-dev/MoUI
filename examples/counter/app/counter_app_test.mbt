///|
test "counter update changes model" {
  let incremented = update(Model::new(), Increment)
  inspect(incremented.count, content="1")
  inspect(update(incremented, Decrement).count, content="0")
  let reset_target = update(
    update(update(Model::new(), Increment), Increment),
    Increment,
  )
  inspect(update(reset_target, Reset).count, content="0")
}

///|
test "counter runtime increments from button click" {
  let runtime = @app.runtime(width=520.0, height=360.0)
  assert_true(has_text(runtime.draw_commands(), "Count: 0"))
  click_text(runtime, "+")
  assert_true(has_text(runtime.draw_commands(), "Count: 1"))
}

///|
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame")
  }
  let point = @core.Point::new(
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
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
