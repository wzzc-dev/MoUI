///|
test "probe update counts clicks and ticks" {
  let clicked = @app.update(@app.Model::new(), Increment)
  inspect(clicked.count, content="1")
  let ticked = @app.update(clicked, Tick)
  inspect(ticked.ticks, content="1")
  inspect(ticked.count, content="1")
}

///|
test "probe pointer tap increments the model" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=520.0,
    height=360.0,
  )
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "Count: 0"),
  )
  let position = @core.Point::new(x=260.0, y=180.0)
  for phase in [@core.PointerPhase::Down, @core.PointerPhase::Up] {
    runtime.dispatch_event(
      @core.AppEvent::Pointer(@core.PointerEvent::new(position~, phase~)),
    )
  }
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "Count: 1"),
  )
}

///|
test "probe environment timer drives ticks" {
  let fire : Ref[(() -> Unit)?] = Ref(None)
  let timer = @services.TimerSource::new(start=(interval_ms, dispatch) => {
    ignore(interval_ms)
    fire.val = Some(() => {
      dispatch(@core.Frame::new(time_ms=100.0, delta_ms=100.0))
    })
    None
  })
  let environment = @services.AppEnvironment::new(timer=Some(timer))
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program_with_dev_environment(environment),
    width=520.0,
    height=360.0,
  )
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "Ticks: 0"),
  )
  match fire.val {
    Some(fire) => fire()
    None => abort("probe timer subscription did not start")
  }
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "Ticks: 1"),
  )
}

///|
test "probe state persistence restores the click count" {
  match
    @app.program_with_dev_environment(@services.AppEnvironment::new()).runtime_state_persistence() {
    Some(persistence) => {
      let mut model = @app.Model::new()
      for _ in 0..<3 {
        model = @app.update(model, @app.Increment)
      }
      match persistence.load(persistence.save(model)) {
        Some(restored) => {
          inspect(restored.count, content="3")
          inspect(restored.ticks, content="0")
        }
        None => abort("expected probe model restore")
      }
    }
    None => abort("expected probe state persistence")
  }
}
