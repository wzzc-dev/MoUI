///|
test "web backend exposes window-hosted wasm-gc lifecycle" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Web)
  inspect(info.uses_window_web_backend, content="true")
}

///|
test "web app options carry scene resolver and platform event sources" {
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
  let options = WebAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
    route_source=Some(@runtime.HostRouteSource::new()),
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
    @runtime.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Web scene resolver")
  }
}

///|
test "web maps close event to host event" {
  let event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(@host.HostEvent::CloseRequested) => ()
    _ => fail("expected close requested")
  }
}

///|
test "web maps browser theme change to host theme event" {
  let event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::ThemeChanged(@window_core.Theme::Dark),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(@host.HostEvent::ThemeChanged(@core.ColorScheme::Dark)) => ()
    _ => fail("expected host theme change")
  }
}

///|
test "web maps surface resize to host metrics" {
  let event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(320, 200),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
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
    @dpi.PhysicalSize::PhysicalSize(640, 360),
  )
  let event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::ScaleFactorChanged(2.0, writer),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
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
  let moved = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(12.0, 34.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match moved {
    Some(
      @host.HostEvent::Pointer(
        { position, phase: @core.PointerPhase::Move, .. }
      )
    ) => assert_true(position == @core.Point::new(x=12.0, y=34.0))
    _ => fail("expected pointer move")
  }

  let down = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(5.0, 6.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match down {
    Some(@host.HostEvent::Pointer({ position, phase, button, .. })) => {
      assert_true(position == @core.Point::new(x=5.0, y=6.0))
      assert_true(phase == @core.PointerPhase::Down)
      inspect(button, content="0")
    }
    _ => fail("expected pointer button")
  }
}

///|
test "web maps wheel and focus to host input events" {
  let wheel = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::MouseWheel(
      None,
      @window_core.MouseScrollDelta::LineDelta(0.0, -3.0),
      @window_core.TouchPhase::Moved,
    ),
    @core.Point::new(x=12.0, y=34.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match wheel {
    Some(
      @host.HostEvent::Scroll(
        {
          position: { x: 12.0, y: 34.0 },
          delta: @host.HostScrollDelta::Lines({ y: -3.0, .. }),
          ..,
        }
      )
    ) => ()
    _ => fail("expected scroll event")
  }
  let focus = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::Focused(true),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match focus {
    Some(@host.HostEvent::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
}

///|
test "web maps keyboard modifiers repeat and text" {
  let key_event = @window_core.KeyEvent::KeyEvent(
    @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::KeyA),
    @window_core.Key::Character("a"),
    @window_core.Key::Character("a"),
    @window_core.KeyLocation::Standard,
    @window_core.ElementState::Pressed,
    true,
    Some("a"),
    Some("A"),
  )
  let event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::new(shift=true),
    scale_factor=1.0,
  )
  match event {
    Some(@host.HostEvent::Keyboard(event)) => {
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
    @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::Enter),
    @window_core.Key::Named(@window_core.NamedKey::Enter),
    @window_core.Key::Named(@window_core.NamedKey::Enter),
    @window_core.KeyLocation::Standard,
    @window_core.ElementState::Released,
    false,
    None,
    None,
  )
  let event = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match event {
    Some(@host.HostEvent::Keyboard(event)) => {
      inspect(event.key, content="Enter")
      inspect(event.pressed, content="false")
    }
    _ => fail("expected named key event")
  }
  let synthetic = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(None, key_event, true),
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
  let preedit = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::Ime(
      @window_core.Ime::Preedit(
        "ni",
        Some(@window_core.ImeCursorRange::ImeCursorRange(0, 2)),
      ),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  let expected_preedit = Some(
    @host.HostEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
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

  let ime = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("hello")),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match ime {
    Some(@host.HostEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="hello")
    _ => fail("expected composition end")
  }

  let redraw = @host.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::RedrawRequested,
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=1.0,
  )
  match redraw {
    Some(@host.HostEvent::RedrawRequested) => ()
    _ => fail("expected redraw requested")
  }
}
