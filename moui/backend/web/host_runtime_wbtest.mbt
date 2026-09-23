///|
test "web maps surface resize through current scale factor" {
  let event = window_event_to_host_with_scale(
    SurfaceResized(PhysicalSize(800, 600)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=400.0, height=300.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=800.0, height=600.0),
      )
      inspect(metrics.scale_factor, content="2")
    }
    _ => fail("expected scaled resize event")
  }
}

///|
test "web maps physical pointer positions through current scale factor" {
  let event = window_event_to_host_with_scale(
    PointerButton(
      None,
      Pressed,
      PhysicalPositionF64(240.0, 120.0),
      true,
      Mouse(Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(Pointer({ position, phase, .. })) => {
      assert_true(position == @core.Point::new(x=120.0, y=60.0))
      assert_true(phase == Down)
    }
    _ => fail("expected scaled pointer button")
  }
}

///|
test "web derives window default canvas id without host string return" {
  inspect(window_web_default_canvas_id(1), content="moonbit-window-web-1")
  inspect(window_web_default_canvas_id(42), content="moonbit-window-web-42")
}

///|
test "web app options carry optional scene resolver" {
  let request = @host.WindowOpenRequest::new(
    title="Inspector",
    scene=@host.WindowScene::new(scene_id="inspector"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match WebAppOptions::new().scene_resolver.resolve(request) {
    SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Web scene resolver rejection")
  }
  let resolver = @window_lifecycle.WindowSceneResolver::new(resolve=request => {
    SceneResolved(
      @window_lifecycle.WindowSceneInstance::new(
        request~,
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  match
    WebAppOptions::new(scene_resolver=resolver).scene_resolver.resolve(request) {
    SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Web scene resolver")
  }
}

///|
test "web route dispatch publishes active route source events" {
  let source = @services.RouteSource::new()
  let observed : Array[@services.RouteEvent] = []
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=(),
      update=(model, _message : Unit) => model,
      view=_model => (@views.empty() : @core.View[Unit]),
      subscriptions=_model => {
        source.subscription(key="web:route", label="Web route", map=event => {
          observed.push(event)
          None
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  ignore(runtime)
  inspect(source.active_handler_count(), content="1")
  set_web_route_source(Some(source))
  inspect(web_dispatch_route_text(1, "navigation?panel=history"), content="1")
  set_web_route_source(None)
  inspect(observed.length(), content="1")
  inspect(observed[0].route(), content="navigation?panel=history")
  inspect(observed[0].source, content="web-popstate")
}

///|
test "web tracks modifiers from keyboard input events" {
  let control_down = @window_core.WindowEvent::KeyboardInput(
    None,
    KeyEvent(
      @window_core.PhysicalKey::from_key_code(ControlLeft),
      Named(Control),
      Named(Control),
      Left,
      Pressed,
      false,
      None,
      None,
    ),
    false,
  )
  let with_control = web_modifiers_after_window_event(
    @core.KeyModifiers::none(),
    control_down,
  )
  inspect(with_control.control, content="true")

  let copy_event = @window_input.window_event_to_host_with_modifiers(
    KeyboardInput(
      None,
      KeyEvent(
        @window_core.PhysicalKey::from_key_code(KeyC),
        Character("c"),
        Character("c"),
        Standard,
        Pressed,
        false,
        Some("c"),
        Some("c"),
      ),
      false,
    ),
    @core.Point::new(x=0.0, y=0.0),
    with_control,
    scale_factor=1.0,
  )
  match copy_event {
    Some(Keyboard(event)) => inspect(event.modifiers.control, content="true")
    _ => fail("expected keyboard event with control modifier")
  }

  let control_up = @window_core.WindowEvent::KeyboardInput(
    None,
    KeyEvent(
      @window_core.PhysicalKey::from_key_code(ControlLeft),
      Named(Control),
      Named(Control),
      Left,
      Released,
      false,
      None,
      None,
    ),
    false,
  )
  let without_control = web_modifiers_after_window_event(
    with_control, control_up,
  )
  inspect(without_control.control, content="false")
}
