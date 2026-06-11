///|
test "windows backend converts resize event" {
  let event = window_event_to_core(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(10, 20),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::Resize(size)) =>
      assert_true(size == @core.Size::new(width=10.0, height=20.0))
    _ => fail("expected resize event")
  }
}

///|
test "windows capability summary exposes native service readiness" {
  let summary = windows_capability_summary()
  inspect(summary.label, content="Windows host")
  inspect(summary.service_count(), content="6")
  inspect(summary.input_count(), content="7")
  inspect(summary.services.menus, content="true")
  inspect(summary.services.file_access, content="true")
  inspect(summary.drag_drop_ready, content="true")
  inspect(summary.multi_window, content="true")
  inspect(summary.native_accessibility_ready, content="false")
}

///|
test "windows host options construct without renderer dependencies" {
  let options = WindowsHostAppOptions::new()
  let _ = options
  inspect(windows_capability_summary().label, content="Windows host")
}

///|
test "windows service bridge exposes clipboard open url and system theme contracts" {
  let opened_url = Ref("")
  let bridge = windows_service_bridge(system_theme=@core.ColorScheme::Dark, open_url=url => {
    opened_url.val = url
    true
  })
  inspect(bridge.capabilities.clipboard, content="true")
  inspect(bridge.capabilities.open_url, content="true")
  inspect(bridge.capabilities.system_theme, content="true")
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL opened response")
  }
  inspect(opened_url.val, content="https://example.test")
  match bridge.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected Windows system theme")
  }
}

///|
test "windows service bridge reports failed open url" {
  let bridge = windows_service_bridge(system_theme=@core.ColorScheme::Light, open_url=_url => {
    false
  })
  match bridge.dispatch(@host.HostServiceRequest::OpenUrl("not-a-url")) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL failed")
    _ => fail("expected failed open URL response")
  }
}

///|
test "windows service bridge exposes file dialog contract" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let bridge = windows_service_bridge(system_theme=@core.ColorScheme::Light, file_dialog=options => {
    seen_kind.val = options.kind
    ["C:\\Users\\moui\\note.md"]
  })
  inspect(bridge.capabilities.file_dialogs, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::SaveFile,
          title="Save note",
          default_name=Some("note.md"),
        ),
      ),
    ) {
    @host.HostServiceResponse::FileDialogSelection(paths) => {
      inspect(paths.length(), content="1")
      inspect(paths[0], content="C:\\Users\\moui\\note.md")
    }
    _ => fail("expected file dialog selection")
  }
  assert_true(seen_kind.val == @host.HostFileDialogKind::SaveFile)
}

///|
test "windows service bridge exposes menu contract" {
  let seen_count = Ref(0)
  let bridge = windows_service_bridge(system_theme=@core.ColorScheme::Light, menu=commands => {
    seen_count.val = commands.length()
    1
  })
  inspect(bridge.capabilities.menus, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
        @core.ActionCommand::new(
          intent=@core.CommandIntent::Paste,
          label="Paste",
        ),
      ]),
    ) {
    @host.HostServiceResponse::MenuAction(command) => {
      assert_true(command.intent == @core.CommandIntent::Paste)
      inspect(command.label, content="Paste")
    }
    _ => fail("expected selected menu command")
  }
  inspect(seen_count.val, content="2")
}

///|
test "windows service bridge reports cancelled or disabled menu selections" {
  let cancelled = windows_service_bridge(
    system_theme=@core.ColorScheme::Light,
    menu=_commands => -1,
  )
  match
    cancelled.dispatch(
      @host.HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      ]),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="menu selection cancelled")
    _ => fail("expected cancelled menu response")
  }
  let disabled = windows_service_bridge(system_theme=@core.ColorScheme::Light, menu=_commands => {
    0
  })
  match
    disabled.dispatch(
      @host.HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(
          intent=@core.CommandIntent::Paste,
          label="Paste",
          enabled=false,
        ),
      ]),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="menu command is disabled")
    _ => fail("expected disabled menu response")
  }
}

///|
test "windows backend converts resize event to host metrics" {
  let event = window_event_to_host(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(10, 20),
    ),
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
test "windows backend converts file drag drop to host event contract" {
  let drop = window_event_to_host(
    @window_core.WindowEvent::DragDropped(
      ["C:\\Users\\moui\\note.md"],
      @dpi.PhysicalPositionF64::PhysicalPositionF64(24.0, 48.0),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match drop {
    Some(
      @host.HostEvent::DragDrop(
        {
          phase: @core.DragDropPhase::Dropped,
          paths,
          position: Some({ x: 24.0, y: 48.0 }),
        }
      )
    ) => inspect(paths[0], content="C:\\Users\\moui\\note.md")
    _ => fail("expected file drop contract")
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
      inspect(event.pressed, content="true")
      inspect(event.repeat, content="false")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
}

///|
test "windows backend converts named keys and ignores synthetic input" {
  let key_event = @window_core.KeyEvent::KeyEvent(
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
test "windows accessibility bridge reports UI Automation contract" {
  let info = windows_accessibility_bridge_info()
  inspect(info.kind.label(), content="uiautomation")
  inspect(info.contract_ready, content="true")
  inspect(info.native_binding_ready, content="false")
}

///|
test "windows accessibility bridge dispatches semantics actions" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(11),
    role: @core.SemanticsRole::Checkbox,
    label: "Enable",
    value: "false",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=120.0, height=32.0),
    children: [],
  }
  let bridge = windows_accessibility_bridge(root=node, dispatch=(
    element_id,
    action,
    _value,
  ) => {
    if element_id == @core.ElementId::new(11) &&
      action == @core.SemanticsAction::Activate {
      invoked.val = invoked.val + 1
      true
    } else {
      false
    }
  })
  match
    bridge.perform_action(
      @host.NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(11),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @host.NativeAccessibilityActionResult::Handled => ()
    _ => fail("expected handled UIA accessibility action")
  }
  inspect(invoked.val, content="1")
}
