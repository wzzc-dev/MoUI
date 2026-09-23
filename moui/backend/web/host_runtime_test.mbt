///|
test "web backend exposes window-hosted wasm-gc lifecycle" {
  let info = @web.backend_info()
  assert_true(info.host_info.backend == Web)
  inspect(info.uses_window_web_backend, content="true")
}

///|
test "web app options carry scene resolver and platform event sources" {
  let request = @host.WindowOpenRequest::new(
    title="Inspector",
    scene=@host.WindowScene::new(scene_id="inspector"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match @web.WebAppOptions::new().scene_resolver.resolve(request) {
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
  let options = @web.WebAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
    route_source=Some(@services.RouteSource::new()),
  )
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Web platform event sources")
  }
  match options.route_source {
    Some(source) => inspect(source.active_handler_count(), content="0")
    None => fail("expected configured Web route source")
  }
  match options.scene_resolver.resolve(request) {
    SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Web scene resolver")
  }
}

///|
test "web maps close event to host event" {
  let event = @window_input.window_event_to_host_with_modifiers(
    CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(CloseRequested) => ()
    _ => fail("expected close requested")
  }
}

///|
test "web maps browser theme change to host theme event" {
  let event = @window_input.window_event_to_host_with_modifiers(
    ThemeChanged(Dark),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(ThemeChanged(Dark)) => ()
    _ => fail("expected host theme change")
  }
}

///|
test "web maps surface resize to host metrics" {
  let event = @window_input.window_event_to_host_with_modifiers(
    SurfaceResized(PhysicalSize(320, 200)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=320.0, height=200.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=320.0, height=200.0),
      )
    }
    _ => fail("expected resize event")
  }
}

///|
test "web maps scale factor changes to host metrics" {
  let writer = @window_core.SurfaceSizeWriter::SurfaceSizeWriter(
    PhysicalSize(640, 360),
  )
  let event = @window_input.window_event_to_host_with_modifiers(
    ScaleFactorChanged(2.0, writer),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=320.0, height=180.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=640.0, height=360.0),
      )
      inspect(metrics.scale_factor, content="2")
    }
    _ => fail("expected scale factor resize event")
  }
}

///|
test "web maps pointer move and left button to host events" {
  let moved = @window_input.window_event_to_host_with_modifiers(
    PointerMoved(None, PhysicalPositionF64(12.0, 34.0), true, Mouse),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match moved {
    Some(Pointer({ position, phase: Move, .. })) =>
      assert_true(position == @core.Point::new(x=12.0, y=34.0))
    _ => fail("expected pointer move")
  }

  let down = @window_input.window_event_to_host_with_modifiers(
    PointerButton(
      None,
      Pressed,
      PhysicalPositionF64(5.0, 6.0),
      true,
      Mouse(Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match down {
    Some(Pointer({ position, phase, button, .. })) => {
      assert_true(position == @core.Point::new(x=5.0, y=6.0))
      assert_true(phase == Down)
      inspect(button, content="0")
    }
    _ => fail("expected pointer button")
  }
}

///|
test "web maps wheel and focus to host input events" {
  let wheel = @window_input.window_event_to_host_with_modifiers(
    MouseWheel(None, LineDelta(0.0, -3.0), Moved),
    @core.Point::new(x=12.0, y=34.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match wheel {
    Some(
      Scroll(
        { position: { x: 12.0, y: 34.0, }, delta: Lines({ y: -3.0, .. }), .. }
      )
    ) => ()
    _ => fail("expected scroll event")
  }
  let focus = @window_input.window_event_to_host_with_modifiers(
    Focused(true),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match focus {
    Some(Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
}

///|
test "web maps keyboard modifiers repeat and text" {
  let key_event = @window_core.KeyEvent::KeyEvent(
    @window_core.PhysicalKey::from_key_code(KeyA),
    Character("a"),
    Character("a"),
    Standard,
    Pressed,
    true,
    Some("a"),
    Some("A"),
  )
  let event = @window_input.window_event_to_host_with_modifiers(
    KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::new(shift=true),
    scale_factor=1.0,
  )
  match event {
    Some(Keyboard(event)) => {
      inspect(event.key, content="a")
      match event.text {
        Some(text) => inspect(text, content="a")
        None => fail("expected text")
      }
      inspect(event.pressed, content="true")
      inspect(event.repeat, content="true")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
}

///|
test "web maps named keys and ignores synthetic keyboard input" {
  let key_event = @window_core.KeyEvent::KeyEvent(
    @window_core.PhysicalKey::from_key_code(Enter),
    Named(Enter),
    Named(Enter),
    Standard,
    Released,
    false,
    None,
    None,
  )
  let event = @window_input.window_event_to_host_with_modifiers(
    KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(Keyboard(event)) => {
      inspect(event.key, content="Enter")
      inspect(event.pressed, content="false")
    }
    _ => fail("expected named key event")
  }
  let synthetic = @window_input.window_event_to_host_with_modifiers(
    KeyboardInput(None, key_event, true),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match synthetic {
    None => ()
    Some(_) => fail("expected synthetic keyboard input to be ignored")
  }
}

///|
test "web maps ime composition lifecycle and redraw" {
  let preedit = @window_input.window_event_to_host_with_modifiers(
    Ime(Preedit("ni", Some(ImeCursorRange(0, 2)))),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  let expected_preedit = Some(
    @host.Event::TextInput(
      CompositionUpdate(
        @core.CompositionUpdate::new(
          text="ni",
          cursor=Some(@core.TextRange::new(start=0, end=2)),
        ),
      ),
    ),
  )
  match preedit {
    event if event == expected_preedit => ()
    _ => fail("expected composition update")
  }

  let ime = @window_input.window_event_to_host_with_modifiers(
    Ime(Commit("hello")),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match ime {
    Some(TextInput(CompositionEnd(text))) => inspect(text, content="hello")
    _ => fail("expected composition end")
  }

  let redraw = @window_input.window_event_to_host_with_modifiers(
    RedrawRequested,
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match redraw {
    Some(RedrawRequested) => ()
    _ => fail("expected redraw requested")
  }
}
