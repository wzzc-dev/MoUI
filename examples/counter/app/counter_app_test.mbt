///|
test "counter app updates and renders count" {
  let app = @app.CounterApp::new()
  let runtime = app.runtime(width=520.0, height=360.0)
  assert_true(has_text(runtime.draw_commands(), "Count: 0"))
  app.increment()
  app.increment()
  app.decrement()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  inspect(app.count.get(), content="1")
  assert_true(has_text(runtime.draw_commands(), "Count: 1"))
  app.reset()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  assert_true(has_text(runtime.draw_commands(), "Count: 0"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
