///|
test "visual counter emits surface title count and styled button commands" {
  let app = @app.CounterApp::new()
  let commands = app.runtime(width=400.0, height=240.0).draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::FillRoundedRectBrush(
        { rect: { size: { width: 400.0, height: 240.0 }, .. }, .. },
        _
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "MoUI Counter", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Count: 0", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Increment", .. })
    }),
  )
}

///|
test "visual counter surface follows runtime resize" {
  let runtime = @app.CounterApp::new().runtime(width=320.0, height=200.0)
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
