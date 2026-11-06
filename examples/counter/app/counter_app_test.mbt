///|
test "counter update changes model" {
  let incremented = @app.update(@app.Model::new(), Increment)
  inspect(incremented.count, content="1")
  inspect(@app.update(incremented, Decrement).count, content="0")
  let reset_target = @app.update(
    @app.update(@app.update(@app.Model::new(), Increment), Increment),
    Increment,
  )
  inspect(@app.update(reset_target, Reset).count, content="0")
}

///|
test "counter runtime increments from button click" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=520.0,
    height=360.0,
  )
  assert_true(has_text(runtime.draw_commands(), "Count: 0"))
  click_text(runtime, "+")
  assert_true(has_text(runtime.draw_commands(), "Count: 1"))
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame")
  }
  let point = @geometry.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Down)),
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Up)),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value == text
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
test "counter dev-state persistence round-trips the model" {
  match @app.program_with_dev_state().runtime_state_persistence() {
    Some(persistence) => {
      let mut model = @app.Model::new()
      for _ in 0..<42 {
        model = @app.update(model, @app.Increment)
      }
      let payload = persistence.save(model)
      match persistence.load(payload) {
        Some(model) => inspect(model.count, content="42")
        None => abort("expected model restore")
      }
      assert_true(persistence.load("not json") is None)
      assert_true(persistence.load("{}") is None)
    }
    None => abort("expected dev-state persistence")
  }
}
