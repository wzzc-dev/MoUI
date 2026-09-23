///|
test "windows backend converts resize event" {
  let event = @window_input.window_event_to_core(
    SurfaceResized(PhysicalSize(10, 20)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(Resize(size)) =>
      assert_true(size == @core.Size::new(width=10.0, height=20.0))
    _ => fail("expected resize event")
  }
}

///|
test "windows capability summary exposes native service readiness" {
  let summary = @windows.windows_capability_summary()
  inspect(summary.label, content="Windows host")
  inspect(summary.service_count(), content="6")
  inspect(summary.input_count(), content="7")
  inspect(summary.services.menus, content="true")
  inspect(summary.services.file_access, content="true")
  inspect(summary.drag_drop_available, content="true")
  inspect(summary.multi_window, content="true")
  inspect(summary.native_accessibility_available, content="false")
}

///|
test "windows host options construct without renderer dependencies" {
  let options = @windows.WindowsHostAppOptions::new()
  let _ = options
  inspect(@windows.windows_capability_summary().label, content="Windows host")
}

///|
test "windows service bridge exposes clipboard open url and system theme contracts" {
  let opened_url = Ref("")
  let bridge = @windows.windows_service_bridge(system_theme=Dark, open_url=url => {
    opened_url.val = url
    true
  })
  inspect(bridge.capabilities().clipboard, content="true")
  inspect(bridge.capabilities().open_url, content="true")
  inspect(bridge.capabilities().system_theme, content="true")
  match bridge.dispatch(OpenUrl("https://example.test")) {
    UrlOpened => ()
    _ => fail("expected URL opened response")
  }
  inspect(opened_url.val, content="https://example.test")
  match bridge.dispatch(QuerySystemTheme) {
    SystemTheme(Dark) => ()
    _ => fail("expected Windows system theme")
  }
}

///|
test "windows service bridge reports failed open url" {
  let bridge = @windows.windows_service_bridge(system_theme=Light, open_url=_url => {
    false
  })
  match bridge.dispatch(OpenUrl("not-a-url")) {
    Unavailable(message) => inspect(message, content="open URL failed")
    _ => fail("expected failed open URL response")
  }
}

///|
test "windows service bridge reports unregistered platform channels unavailable" {
  let bridge = @windows.windows_service_bridge(system_theme=Light)
  match
    bridge.dispatch(
      PlatformChannel(
        @host.PlatformChannelRequest::new(
          channel="windows.missing",
          operation="probe",
        ),
      ),
    ) {
    Unavailable(message) =>
      inspect(
        message,
        content="platform channel is unavailable: windows.missing",
      )
    _ => fail("expected unavailable Windows platform channel")
  }
}

///|
test "windows service bridge exposes file dialog contract" {
  let seen_kind = Ref(@host.HostFileDialogKind::OpenFile)
  let bridge = @windows.windows_service_bridge(system_theme=Light, file_dialog=options => {
    seen_kind.val = options.kind
    ["C:\\Users\\moui\\note.md"]
  })
  inspect(bridge.capabilities().file_dialogs, content="true")
  match
    bridge.dispatch(
      FileDialog(
        @host.HostFileDialogOptions::new(
          kind=SaveFile,
          title="Save note",
          default_name=Some("note.md"),
        ),
      ),
    ) {
    FileDialogSelection(paths) => {
      inspect(paths.length(), content="1")
      inspect(paths[0], content="C:\\Users\\moui\\note.md")
    }
    _ => fail("expected file dialog selection")
  }
  assert_true(seen_kind.val == SaveFile)
}

///|
test "windows service bridge exposes menu contract" {
  let seen_count = Ref(0)
  let bridge = @windows.windows_service_bridge(system_theme=Light, menu=commands => {
    seen_count.val = commands.length()
    1
  })
  inspect(bridge.capabilities().menus, content="true")
  match
    bridge.dispatch(
      ShowMenu([
        @core.ActionCommand::new(intent=Copy, label="Copy"),
        @core.ActionCommand::new(intent=Paste, label="Paste"),
      ]),
    ) {
    MenuAction(command) => {
      assert_true(command.intent == Paste)
      inspect(command.label, content="Paste")
    }
    _ => fail("expected selected menu command")
  }
  inspect(seen_count.val, content="2")
}

///|
test "windows service bridge reports cancelled or disabled menu selections" {
  let cancelled = @windows.windows_service_bridge(system_theme=Light, menu=_commands => {
    -1
  })
  match
    cancelled.dispatch(
      ShowMenu([@core.ActionCommand::new(intent=Copy, label="Copy")]),
    ) {
    Unavailable(message) => inspect(message, content="menu selection cancelled")
    _ => fail("expected cancelled menu response")
  }
  let disabled = @windows.windows_service_bridge(system_theme=Light, menu=_commands => {
    0
  })
  match
    disabled.dispatch(
      ShowMenu([
        @core.ActionCommand::new(intent=Paste, label="Paste", enabled=false),
      ]),
    ) {
    Unavailable(message) => inspect(message, content="menu command is disabled")
    _ => fail("expected disabled menu response")
  }
}

///|
test "windows backend converts resize event to host metrics" {
  let event = @window_input.window_event_to_host(
    SurfaceResized(PhysicalSize(10, 20)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(Resized(metrics)) => {
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
test "windows normalizes resize pointer and drag across common DPI scales" {
  for dpi_case in [(1.25, 125, 100), (1.5, 150, 120), (2.0, 200, 160)] {
    let (scale, physical_width, physical_height) = dpi_case
    match
      @window_input.transform_cross_platform_event(
        SurfaceResized(PhysicalSize(physical_width, physical_height)),
        scale_factor=scale,
      ) {
      DispatchHostEvent(Resized(metrics)) => {
        assert_true(
          metrics.logical_size == @core.Size::new(width=100.0, height=80.0),
        )
        assert_true(metrics.scale_factor == scale)
      }
      _ => fail("expected DPI-normalized Windows resize")
    }
    match
      @window_input.window_event_to_host_with_modifiers(
        PointerMoved(
          None,
          PhysicalPositionF64(12.0 * scale, 24.0 * scale),
          true,
          Mouse,
        ),
        @core.Point::new(x=0.0, y=0.0),
        @core.KeyModifiers::none(),
        scale_factor=scale,
      ) {
      Some(Pointer({ position, .. })) =>
        assert_true(position == @core.Point::new(x=12.0, y=24.0))
      _ => fail("expected DPI-normalized Windows pointer")
    }
    match
      @window_input.window_event_to_host_with_modifiers(
        DragDropped(
          ["C:\\Users\\moui\\dpi.txt"],
          PhysicalPositionF64(20.0 * scale, 32.0 * scale),
        ),
        @core.Point::new(x=0.0, y=0.0),
        @core.KeyModifiers::none(),
        scale_factor=scale,
      ) {
      Some(DragDrop({ position: Some(position), .. })) =>
        assert_true(position == @core.Point::new(x=20.0, y=32.0))
      _ => fail("expected DPI-normalized Windows drag")
    }
  }
}

///|
test "windows backend converts pointer movement and left button" {
  let moved = @window_input.window_event_to_core(
    PointerMoved(None, PhysicalPositionF64(3.0, 4.0), true, Mouse),
    @core.Point::new(x=0.0, y=0.0),
  )
  match moved {
    Some(Pointer(event)) => {
      assert_true(event.position == @core.Point::new(x=3.0, y=4.0))
      assert_true(event.phase == Move)
    }
    _ => fail("expected pointer move")
  }

  let down = @window_input.window_event_to_core(
    PointerButton(
      None,
      Pressed,
      PhysicalPositionF64(5.0, 6.0),
      true,
      Mouse(Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match down {
    Some(Pointer(event)) => {
      assert_true(event.position == @core.Point::new(x=5.0, y=6.0))
      assert_true(event.phase == Down)
    }
    _ => fail("expected pointer down")
  }
}

///|
test "windows backend converts wheel and focus into host input events" {
  let wheel = @window_input.window_event_to_host(
    MouseWheel(None, LineDelta(2.0, -1.0), Moved),
    @core.Point::new(x=11.0, y=12.0),
  )
  match wheel {
    Some(
      Scroll(
        {
          position: { x: 11.0, y: 12.0, },
          delta: Lines({ x: 2.0, y: -1.0, }),
          ..
        }
      )
    ) => ()
    _ => fail("expected wheel event")
  }
  let focus = @window_input.window_event_to_host(
    Focused(true),
    @core.Point::new(x=0.0, y=0.0),
  )
  match focus {
    Some(Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
}

///|
test "windows backend converts file drag drop to host event contract" {
  let drop = @window_input.window_event_to_host(
    DragDropped(["C:\\Users\\moui\\note.md"], PhysicalPositionF64(24.0, 48.0)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match drop {
    Some(
      DragDrop(
        { phase: Dropped, paths, position: Some({ x: 24.0, y: 48.0, }), }
      )
    ) => inspect(paths[0], content="C:\\Users\\moui\\note.md")
    _ => fail("expected file drop contract")
  }
}

///|
test "windows backend converts close event" {
  let event = @window_input.window_event_to_core(
    CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(CloseRequested) => ()
    _ => fail("expected close event")
  }
}

///|
test "windows backend converts keyboard input event" {
  let key_event = @window_core.KeyEvent::KeyEvent(
    @window_core.PhysicalKey::from_key_code(KeyA),
    Character("a"),
    Character("a"),
    Standard,
    Pressed,
    false,
    Some("a"),
    Some("A"),
  )
  let event = @window_input.window_event_to_host_with_modifiers(
    KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::new(shift=true),
  )
  match event {
    Some(Keyboard(event)) => {
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
    @window_core.PhysicalKey::from_key_code(Backspace),
    Named(Backspace),
    Named(Backspace),
    Standard,
    Released,
    true,
    None,
    None,
  )
  let event = @window_input.window_event_to_core(
    KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(Keyboard(event)) => {
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
  let synthetic = @window_input.window_event_to_core(
    KeyboardInput(None, key_event, true),
    @core.Point::new(x=0.0, y=0.0),
  )
  match synthetic {
    None => ()
    Some(_) => fail("expected synthetic keyboard input to be ignored")
  }
}

///|
test "windows backend converts ime commit into core composition end" {
  let event = @window_input.window_event_to_core(
    Ime(Commit("x")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(TextInput(CompositionEnd(text))) => inspect(text, content="x")
    _ => fail("expected composition end")
  }
}

///|
test "windows backend keeps ime composition separate at host layer" {
  let delete = @window_input.window_event_to_host(
    Ime(DeleteSurrounding(1, 2)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match delete {
    Some(TextInput(DeleteSurrounding(1, 2))) => ()
    _ => fail("expected delete surrounding")
  }
  let event = @window_input.window_event_to_host(
    Ime(Commit("x")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(TextInput(CompositionEnd(text))) => inspect(text, content="x")
    _ => fail("expected host composition end")
  }
}

///|
test "windows accessibility bridge reports UI Automation contract" {
  let info = @windows.windows_accessibility_bridge_info()
  inspect(info.kind, content="uiautomation")
  inspect(info.semantics_bridge_available, content="true")
  inspect(info.native_accessibility_bridge_available, content="false")
}

///|
test "windows accessibility bridge dispatches semantics actions" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.button("Enable", on_click=()) : @core.View[Unit]),
    size=@core.Size::new(width=140.0, height=60.0),
  )
  let snapshot = match runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot
    _ => abort("expected full committed semantics")
  }
  let mut target : @core.SemanticsNode? = None
  for node in snapshot.nodes() {
    if node.actions.any(action => action == Activate) {
      target = Some(node)
    }
  }
  let target = target.unwrap()
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @windows.windows_accessibility_bridge(driver)
  match
    bridge.perform_action(
      @accesskit_bridge.accesskit_semantics_action_request(
        node_id=target.node_id,
        generation=snapshot.generation(),
        action=Activate,
      ),
    ) {
    Handled(receipt) => assert_true(receipt.before == snapshot.generation())
    _ => fail("expected handled UIA accessibility action")
  }
}
