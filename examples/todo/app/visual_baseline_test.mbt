///|
test "visual todo emits field button and keyed row text commands" {
  let app = @app.TodoApp::new()
  app.add("Visual baseline")
  let commands = app.runtime(width=480.0, height=560.0).draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::FillRoundedRectBrush(
        { rect: { size: { width: 480.0, height: 560.0 }, .. }, .. },
        _
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "MoUI Todo", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "New todo", frame: { origin: { x: 76.0, .. }, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Visual baseline", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, _)
    }),
  )
  assert_false(
    commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
}

///|
test "visual todo surface follows runtime resize" {
  let runtime = @app.TodoApp::new().runtime(width=320.0, height=200.0)
  runtime.dispatch_event(
    @core.AppEvent::Resize(@core.Size::new(width=640.0, height=360.0)),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::FillRoundedRectBrush(
        { rect: { size: { width: 640.0, height: 360.0 }, .. }, .. },
        _
      )
    }),
  )
}
