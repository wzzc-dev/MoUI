///|
test "web maps surface resize through current scale factor" {
  let event = window_event_to_host_with_scale(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(800, 600),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
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
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(240.0, 120.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(@host.HostEvent::Pointer({ position, phase, .. })) => {
      assert_true(position == @core.Point::new(x=120.0, y=60.0))
      assert_true(phase == @core.PointerPhase::Down)
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
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match WebAppOptions::new().scene_resolver.resolve(request) {
    @runtime.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Web scene resolver rejection")
  }
  let resolver = @runtime.HostWindowSceneResolver::new(resolve=request => {
    @runtime.HostWindowSceneResolution::SceneResolved(
      @runtime.HostWindowSceneInstance::new(
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
    @runtime.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
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
    @window_core.KeyEvent::KeyEvent(
      @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::ControlLeft),
      @window_core.Key::Named(@window_core.NamedKey::Control),
      @window_core.Key::Named(@window_core.NamedKey::Control),
      @window_core.KeyLocation::Left,
      @window_core.ElementState::Pressed,
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

  let copy_event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(
      None,
      @window_core.KeyEvent::KeyEvent(
        @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::KeyC),
        @window_core.Key::Character("c"),
        @window_core.Key::Character("c"),
        @window_core.KeyLocation::Standard,
        @window_core.ElementState::Pressed,
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
    Some(@host.HostEvent::Keyboard(event)) =>
      inspect(event.modifiers.control, content="true")
    _ => fail("expected keyboard event with control modifier")
  }

  let control_up = @window_core.WindowEvent::KeyboardInput(
    None,
    @window_core.KeyEvent::KeyEvent(
      @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::ControlLeft),
      @window_core.Key::Named(@window_core.NamedKey::Control),
      @window_core.Key::Named(@window_core.NamedKey::Control),
      @window_core.KeyLocation::Left,
      @window_core.ElementState::Released,
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
