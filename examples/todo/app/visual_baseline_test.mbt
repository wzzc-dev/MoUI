///|
test "visual v2 todo emits field button and keyed row text commands" {
  let app = @app.TodoApp::new()
  app.add("Visual baseline")
  let commands = app.runtime(width=480.0, height=560.0).draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::FillRoundedRect(_, _)),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "MoUI Todo", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "New todo", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Visual baseline", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::StrokeRoundedRect(_, _, _)
    }),
  )
}
