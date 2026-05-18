///|
test "macos backend is native renderer ready" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.renderer_ready, content="true")
}

///|
test "macos backend converts resize event to host metrics" {
  let event = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::SurfaceResized(@dpi.PhysicalSize::new(20, 40)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=10.0, height=20.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=20.0, height=40.0),
      )
      inspect(metrics.scale_factor, content="2")
    }
    _ => fail("expected host resize event")
  }
}

///|
test "macos backend converts pointer movement and left button" {
  let moved = window_event_to_core(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::new(3.0, 4.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match moved {
    Some(@core.AppEvent::Pointer(event)) => {
      assert_true(event.position == @core.Point::new(x=3.0, y=4.0))
      assert_true(event.phase == @core.PointerPhase::Move)
    }
    _ => fail("expected pointer move")
  }
  let down = window_event_to_core(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::new(5.0, 6.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match down {
    Some(@core.AppEvent::Pointer(event)) => {
      assert_true(event.position == @core.Point::new(x=5.0, y=6.0))
      assert_true(event.phase == @core.PointerPhase::Down)
    }
    _ => fail("expected pointer down")
  }
}

///|
test "macos backend converts scaled pointer coordinates to logical host points" {
  let moved = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::new(120.0, 80.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match moved {
    Some(@host.HostEvent::PointerMoved(position)) =>
      assert_true(position == @core.Point::new(x=60.0, y=40.0))
    _ => fail("expected scaled pointer move")
  }
  let down = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::new(140.0, 100.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match down {
    Some(@host.HostEvent::PointerButton(position, phase, _)) => {
      assert_true(position == @core.Point::new(x=70.0, y=50.0))
      assert_true(phase == @core.PointerPhase::Down)
    }
    _ => fail("expected scaled pointer button")
  }
}

///|
test "macos backend converts close event" {
  let event = window_event_to_core(
    @window_core.WindowEvent::CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::CloseRequested) => ()
    _ => fail("expected close event")
  }
}

///|
test "macos backend converts keyboard input event" {
  let key_event = @window_core.KeyEvent::new(
    @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::KeyA),
    @window_core.Key::Character("a"),
    @window_core.Key::Character("a"),
    @window_core.KeyLocation::Standard,
    @window_core.ElementState::Pressed,
    false,
    Some("a"),
    Some("A"),
  )
  let event = window_event_to_core_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::new(shift=true),
  )
  match event {
    Some(@core.AppEvent::Keyboard(event)) => {
      inspect(event.key, content="a")
      match event.text {
        Some(text) => inspect(text, content="a")
        None => fail("expected text")
      }
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
}

///|
test "macos backend keeps ime composition separate at host layer" {
  let preedit = window_event_to_host(
    @window_core.WindowEvent::Ime(
      @window_core.Ime::Preedit(
        "ni",
        Some(@window_core.ImeCursorRange::new(0, 2)),
      ),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match preedit {
    Some(
      @host.HostEvent::TextInputEvent(
        @core.TextInputEvent::CompositionUpdate(
          { text: "ni", cursor: Some({ start: 0, end: 2 }) }
        )
      )
    ) => ()
    _ => fail("expected composition update")
  }
  let event = window_event_to_host(
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("x")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(
      @host.HostEvent::TextInputEvent(
        @core.TextInputEvent::CompositionEnd(text)
      )
    ) => inspect(text, content="x")
    _ => fail("expected host composition end")
  }
}

///|
test "macos backend exposes platform-owned surface host metadata" {
  let info = macos_surface_host_info()
  inspect(info.platform, content="macos")
  inspect(info.owns_instance, content="true")
}
