///|
test "macos backend is native renderer ready" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.renderer_ready, content="true")
  inspect(info.accessibility.kind.label(), content="appkit")
  inspect(info.accessibility.contract_ready, content="true")
}

///|
test "macos capability summary exposes native service readiness" {
  let summary = macos_capability_summary()
  inspect(summary.label, content="macOS host")
  inspect(summary.service_count(), content="6")
  inspect(summary.input_count(), content="7")
  inspect(summary.services.menus, content="true")
  inspect(summary.services.file_access, content="true")
  inspect(summary.drag_drop_ready, content="true")
  inspect(summary.multi_window, content="true")
  inspect(summary.native_accessibility_ready, content="false")
}

///|
test "macos backend host options are constructed through provider runner API" {
  let options = MacosHostAppOptions::new(exit_after_first_present=true)
  let _ = options
  assert_true(backend_info().renderer_ready)
}

///|
test "macos accessibility bridge dispatches semantics actions" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(9),
    role: @core.SemanticsRole::Button,
    label: "Run",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=32.0),
    children: [],
  }
  let bridge = macos_accessibility_bridge(root=node, dispatch=(
    element_id,
    action,
    _value,
  ) => {
    if element_id == @core.ElementId::new(9) &&
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
test "macos service bridge exposes clipboard, open url, and system theme" {
  let opened_url = Ref("")
  let clipboard = Ref("")
  let bridge = macos_service_bridge(
    system_theme=@core.ColorScheme::Dark,
    clipboard=request => {
      match request {
        @host.HostClipboardRequest::ReadText =>
          @host.HostServiceResponse::ClipboardText(clipboard.val)
        @host.HostClipboardRequest::WriteText(text) => {
          clipboard.val = text
          @host.HostServiceResponse::ClipboardWritten
        }
      }
    },
    open_url=url => {
      opened_url.val = url
      true
    },
  )
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL opened response")
  }
  inspect(opened_url.val, content="https://example.test")
  match bridge.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::WriteText("MoUI macOS clipboard smoke"),
      ),
    ) {
    @host.HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected native clipboard write")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::ClipboardText(text) =>
      inspect(text, content="MoUI macOS clipboard smoke")
    _ => fail("expected native clipboard read")
  }
}

///|
test "macos service bridge reports failed open url" {
  let bridge = macos_service_bridge(system_theme=@core.ColorScheme::Light, open_url=_url => {
    false
  })
  match bridge.dispatch(@host.HostServiceRequest::OpenUrl("not-a-url")) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL failed")
    _ => fail("expected failed open URL response")
  }
}

///|
test "macos service bridge exposes file dialog contract" {
  let seen_title = Ref("")
  let bridge = macos_service_bridge(system_theme=@core.ColorScheme::Light, file_dialog=options => {
    seen_title.val = options.title
    ["/tmp/moui.md"]
  })
  inspect(bridge.capabilities.file_dialogs, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::OpenFile,
          title="Open Markdown",
          filters=["*.md"],
        ),
      ),
    ) {
    @host.HostServiceResponse::FileDialogSelection(paths) => {
      inspect(paths.length(), content="1")
      inspect(paths[0], content="/tmp/moui.md")
    }
    _ => fail("expected file dialog selection")
  }
  inspect(seen_title.val, content="Open Markdown")
}

///|
test "macos service bridge exposes menu contract" {
  let seen_count = Ref(0)
  let bridge = macos_service_bridge(system_theme=@core.ColorScheme::Light, menu=commands => {
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
test "macos service bridge reports cancelled or disabled menu selections" {
  let cancelled = macos_service_bridge(system_theme=@core.ColorScheme::Light, menu=_commands => {
    -1
  })
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
  let disabled = macos_service_bridge(system_theme=@core.ColorScheme::Light, menu=_commands => {
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
test "macos resize metrics update runtime driver logical size" {
  let runtime = @core.AppRuntime::new_view(
    root=(@core.View::empty() : @core.View[Unit]),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let event = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(1440, 900),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(host_event) => {
      ignore(driver.dispatch(host_event))
      assert_true(runtime.size() == @core.Size::new(width=720.0, height=450.0))
    }
    None => fail("expected host resize event")
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
test "macos backend converts file drag drop to logical host event" {
  let drop = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::DragDropped(
      ["/tmp/moui.md"],
      @dpi.PhysicalPositionF64::PhysicalPositionF64(120.0, 80.0),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match drop {
    Some(
      @host.HostEvent::DragDrop(
        {
          phase: @core.DragDropPhase::Dropped,
          paths,
          position: Some({ x: 60.0, y: 40.0 }),
        }
      )
    ) => inspect(paths[0], content="/tmp/moui.md")
    _ => fail("expected scaled file drop")
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
