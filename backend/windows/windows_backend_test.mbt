///|
test "windows backend converts resize event" {
  let event = window_event_to_core(
    @window_core.WindowEvent::SurfaceResized(@dpi.PhysicalSize::new(10, 20)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::Resize(size)) =>
      assert_true(size == @core.Size::new(width=10.0, height=20.0))
    _ => fail("expected resize event")
  }
}

///|
test "windows backend converts resize event to host metrics" {
  let event = window_event_to_host(
    @window_core.WindowEvent::SurfaceResized(@dpi.PhysicalSize::new(10, 20)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=10.0, height=20.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=10.0, height=20.0),
      )
      inspect(metrics.scale_factor, content="1")
    }
    _ => fail("expected host resize event")
  }
}

///|
test "windows backend converts pointer movement and left button" {
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
test "windows backend converts wheel and focus into host input events" {
  let wheel = window_event_to_host(
    @window_core.WindowEvent::MouseWheel(
      None,
      @window_core.MouseScrollDelta::LineDelta(2.0, -1.0),
      @window_core.TouchPhase::Moved,
    ),
    @core.Point::new(x=11.0, y=12.0),
  )
  match wheel {
    Some(
      @host.HostEvent::Scroll(
        {
          position: { x: 11.0, y: 12.0 },
          delta: @host.HostScrollDelta::Lines({ x: 2.0, y: -1.0 }),
          ..,
        }
      )
    ) => ()
    _ => fail("expected wheel event")
  }
  let focus = window_event_to_host(
    @window_core.WindowEvent::Focused(true),
    @core.Point::new(x=0.0, y=0.0),
  )
  match focus {
    Some(@host.HostEvent::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
}

///|
test "windows backend converts close event" {
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
test "windows backend converts keyboard input event" {
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
      inspect(event.pressed, content="true")
      inspect(event.repeat, content="false")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
}

///|
test "windows backend converts named keys and ignores synthetic input" {
  let key_event = @window_core.KeyEvent::new(
    @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::Backspace),
    @window_core.Key::Named(@window_core.NamedKey::Backspace),
    @window_core.Key::Named(@window_core.NamedKey::Backspace),
    @window_core.KeyLocation::Standard,
    @window_core.ElementState::Released,
    true,
    None,
    None,
  )
  let event = window_event_to_core(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::Keyboard(event)) => {
      inspect(event.key, content="Backspace")
      match event.text {
        None => ()
        Some(_) => fail("expected no text")
      }
      inspect(event.pressed, content="false")
      inspect(event.repeat, content="true")
    }
    _ => fail("expected backspace keyboard event")
  }
  let synthetic = window_event_to_core(
    @window_core.WindowEvent::KeyboardInput(None, key_event, true),
    @core.Point::new(x=0.0, y=0.0),
  )
  match synthetic {
    None => ()
    Some(_) => fail("expected synthetic keyboard input to be ignored")
  }
}

///|
test "windows backend converts ime commit into core composition end" {
  let event = window_event_to_core(
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("x")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="x")
    _ => fail("expected composition end")
  }
}

///|
test "windows backend keeps ime composition separate at host layer" {
  let delete = window_event_to_host(
    @window_core.WindowEvent::Ime(@window_core.Ime::DeleteSurrounding(1, 2)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match delete {
    Some(
      @host.HostEvent::TextInput(@core.TextInputEvent::DeleteSurrounding(1, 2))
    ) => ()
    _ => fail("expected delete surrounding")
  }
  let event = window_event_to_host(
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("x")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="x")
    _ => fail("expected host composition end")
  }
}

///|
test "windows backend exposes platform-owned surface host metadata" {
  let info = windows_surface_host_info()
  inspect(info.platform, content="windows")
  inspect(info.owns_instance, content="true")
}
