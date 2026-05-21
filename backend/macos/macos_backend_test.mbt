///|
test "macos backend is native renderer ready" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.renderer_ready, content="true")
  inspect(info.accessibility.kind.label(), content="appkit")
  inspect(info.accessibility.contract_ready, content="true")
}

///|
test "macos accessibility bridge dispatches semantics actions" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(9),
    role: @core.SemanticsRole::Button,
    label: "Run",
    value: "",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=32.0),
    children: [],
  }
  let bridge = macos_accessibility_bridge(
    root=node,
    dispatch=(element_id, action, _value) => {
      if element_id == @core.ElementId::new(9) && action == @core.SemanticsAction::Activate {
        invoked.val = invoked.val + 1
        true
      } else {
        false
      }
    },
  )
  match bridge.perform_action(
    @host.NativeAccessibilityActionRequest::new(
      element_id=@core.ElementId::new(9),
      action=@core.SemanticsAction::Activate,
    ),
  ) {
    @host.NativeAccessibilityActionResult::Handled => ()
    _ => fail("expected handled AppKit accessibility action")
  }
  inspect(invoked.val, content="1")
}

///|
test "macos service bridge exposes open url and system theme scaffold" {
  let bridge = macos_service_bridge(system_theme=@core.ColorScheme::Dark)
  match bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL opened scaffold response")
  }
  match bridge.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  match bridge.dispatch(
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
  ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected clipboard to remain unavailable")
  }
}

///|
test "macos backend converts resize event to host metrics" {
  let event = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(20, 40),
    ),
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
      @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
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
      @dpi.PhysicalPositionF64::PhysicalPositionF64(5.0, 6.0),
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
      @dpi.PhysicalPositionF64::PhysicalPositionF64(120.0, 80.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match moved {
    Some(
      @host.HostEvent::Pointer(
        { position, phase: @core.PointerPhase::Move, .. }
      )
    ) => assert_true(position == @core.Point::new(x=60.0, y=40.0))
    _ => fail("expected scaled pointer move")
  }
  let down = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(140.0, 100.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match down {
    Some(@host.HostEvent::Pointer({ position, phase, .. })) => {
      assert_true(position == @core.Point::new(x=70.0, y=50.0))
      assert_true(phase == @core.PointerPhase::Down)
    }
    _ => fail("expected scaled pointer button")
  }
}

///|
test "macos backend converts wheel and focus into host input contract" {
  let wheel = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::MouseWheel(
      None,
      @window_core.MouseScrollDelta::PixelDelta(
        @dpi.PhysicalPositionF64::PhysicalPositionF64(16.0, -24.0),
      ),
      @window_core.TouchPhase::Moved,
    ),
    @core.Point::new(x=4.0, y=5.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match wheel {
    Some(
      @host.HostEvent::Scroll(
        {
          position: { x: 4.0, y: 5.0 },
          delta: @host.HostScrollDelta::Pixels({ x: 8.0, y: -12.0 }),
          ..,
        }
      )
    ) => ()
    _ => fail("expected scaled wheel event")
  }
  let blur = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::Focused(false),
    @core.Point::new(x=7.0, y=9.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match blur {
    Some(
      @host.HostEvent::Focus({ focused: false, pointer_cancel_position: None })
    ) => ()
    _ => fail("expected focus loss event")
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
  let key_event = @window_core.KeyEvent::KeyEvent(
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
        Some(@window_core.ImeCursorRange::ImeCursorRange(0, 2)),
      ),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match preedit {
    Some(
      @host.HostEvent::TextInput(
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
    Some(@host.HostEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="x")
    _ => fail("expected host composition end")
  }
}

///|
test "macos backend exposes content-view surface host metadata" {
  let info = macos_surface_host_info()
  inspect(info.platform, content="macos")
  inspect(info.owns_instance, content="true")
}
