///|
test "counter app constructs runtime" {
  let app = @app.CounterApp::new()
  let runtime = app.runtime(width=320.0, height=240.0)
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  assert_true(runtime.draw_commands().length() >= 6)
}

///|
test "counter app rebuilds root through dynamic runtime after click" {
  let app = @app.CounterApp::new()
  let runtime = app.runtime(width=300.0, height=300.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=112.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=112.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(runtime.needs_rebuild(), content="false")
  inspect(runtime.needs_rebuild(), content="false")
  inspect(app.count.get(), content="1")
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "MoUI Counter", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Count: 1", .. })
    }),
  )
}
