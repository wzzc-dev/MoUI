///|
test "visual v2 counter emits surface title count and styled button commands" {
  let app = @counter_app.CounterApp::new()
  let commands = app.runtime(width=400.0, height=240.0).draw_commands()
  assert_true(commands.any(command => command is @core.DrawCommand::FillRoundedRect(_, _)))
  assert_true(commands.any(command => command is @core.DrawCommand::DrawText({ text: "MoUI Counter", .. })))
  assert_true(commands.any(command => command is @core.DrawCommand::DrawText({ text: "Count: 0", .. })))
  assert_true(commands.any(command => command is @core.DrawCommand::DrawText({ text: "Increment", .. })))
}
