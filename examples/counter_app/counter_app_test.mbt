///|
test "counter app constructs runtime" {
  let app = @counter_app.CounterApp::new()
  let runtime = app.runtime(width=320.0, height=240.0)
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(runtime.draw_commands().length(), content="5")
}

///|
test "counter app rebuilds root after click" {
  let app = @counter_app.CounterApp::new()
  let runtime = app.runtime(width=300.0, height=300.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=210.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=210.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(runtime.needs_rebuild(), content="true")
  app.sync_runtime(runtime)
  inspect(runtime.needs_rebuild(), content="false")
  inspect(app.count, content="1")
}
