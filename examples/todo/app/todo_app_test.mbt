///|
test "todo app add toggle and remove update shared state" {
  let app = @app.TodoApp::new()
  app.add("Write tests")
  app.add("Ship runtime")
  inspect(app.count(), content="2")
  app.toggle(0)
  guard app.items() is [{ completed: true, .. }, { completed: false, .. }] else {
    fail("expected first item toggled")
  }
  app.remove(0)
  inspect(app.count(), content="1")
  guard app.items() is [{ id: 1, text: "Ship runtime", .. }] else {
    fail("expected second item to remain")
  }
}

///|
test "todo runtime reuses keyed rows after toggle" {
  let app = @app.TodoApp::new()
  app.add("One")
  app.add("Two")
  let runtime = app.runtime(width=400.0, height=240.0)
  let first_row_id = runtime.state.element_tree.find_keyed("todo-0").unwrap()
  app.toggle(0)
  runtime.state.needs_rebuild = true
  ignore(runtime.draw_commands())
  assert_true(
    runtime.state.element_tree.find_keyed("todo-0") == Some(first_row_id),
  )
}

///|
test "todo runtime click updates item through shared pipeline" {
  let app = @app.TodoApp::new()
  app.add("One")
  let runtime = app.runtime(width=400.0, height=240.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=120.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=120.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  guard app.items() is [{ completed: true, .. }] else {
    fail("expected clicked todo toggled")
  }
  guard runtime.draw_commands() is [_, .. commands] else {
    fail("expected draw commands")
  }
  assert_true(commands.length() > 0)
}
