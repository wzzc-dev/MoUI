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
        position=@core.Point::new(x=40.0, y=120.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=40.0, y=120.0),
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

///|
fn find_text_field_frame(node : @core.SemanticsNode) -> @core.Rect? {
  if node.role == @core.SemanticsRole::TextField {
    Some(node.frame)
  } else {
    for child in node.children {
      match find_text_field_frame(child) {
        Some(frame) => return Some(frame)
        None => ()
      }
    }
    None
  }
}

///|
test "todo runtime enters draft and submits through text field" {
  let app = @app.TodoApp::new()
  let runtime = app.runtime(width=480.0, height=240.0)
  guard find_text_field_frame(runtime.semantics()) is Some(frame) else {
    fail("expected todo draft text field semantics")
  }
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=center, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="a", text=Some("a"))),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="b", text=Some("b"))),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  guard app.items() is [{ id: 0, text: "ab", completed: false }] else {
    fail("expected draft text submitted as first todo item")
  }
  inspect(app.draft.get(), content="")
}
