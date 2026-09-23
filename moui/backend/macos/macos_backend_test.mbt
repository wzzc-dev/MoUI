///|
test "macos backend is native renderer ready" {
  let info = @macos.backend_info()
  assert_true(info.host_info.backend == Native)
  inspect(info.renderer_available, content="true")
  inspect(info.accessibility.kind, content="appkit")
  inspect(info.accessibility.semantics_bridge_available, content="true")
}

///|
test "macos capability summary exposes native service readiness" {
  let summary = @macos.macos_capability_summary()
  inspect(summary.label, content="macOS host")
  inspect(summary.service_count(), content="6")
  inspect(summary.input_count(), content="7")
  inspect(summary.services.menus, content="true")
  inspect(summary.services.file_access, content="true")
  inspect(summary.drag_drop_available, content="true")
  inspect(summary.multi_window, content="true")
  inspect(summary.native_accessibility_available, content="false")
}

///|
test "macos backend host options are constructed through provider runner API" {
  let options = @macos.MacosHostAppOptions::new()
  let smoke_options = @macos.MacosHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
  )
  let _ = options
  let _ = smoke_options
  assert_true(@macos.backend_info().renderer_available)
}

///|
test "macos accessibility bridge dispatches semantics actions" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.button("Run", on_click=()) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=60.0),
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
  let bridge = @macos.macos_accessibility_bridge(driver)
  match
    bridge.perform_action(
      @accesskit_bridge.accesskit_semantics_action_request(
        node_id=target.node_id,
        generation=snapshot.generation(),
        action=Activate,
      ),
    ) {
    Handled(receipt) => assert_true(receipt.before == snapshot.generation())
    _ => fail("expected handled AppKit accessibility action")
  }
}

///|
test "macos service bridge exposes clipboard, open url, and system theme" {
  let opened_url = Ref("")
  let clipboard = Ref("")
  let bridge = @macos.macos_service_bridge(
    system_theme=Dark,
    clipboard=request => {
      match request {
        ReadText => ClipboardText(clipboard.val)
        WriteText(text) => {
          clipboard.val = text
          ClipboardWritten
        }
        ReadImage => ClipboardImage(b"")
        WriteImage(_, _) => ClipboardWritten
      }
    },
    open_url=url => {
      opened_url.val = url
      true
    },
  )
  match bridge.dispatch(OpenUrl("https://example.test")) {
    UrlOpened => ()
    _ => fail("expected URL opened response")
  }
  inspect(opened_url.val, content="https://example.test")
  match bridge.dispatch(QuerySystemTheme) {
    SystemTheme(Dark) => ()
    _ => fail("expected dark system theme")
  }
  match bridge.dispatch(Clipboard(WriteText("MoUI macOS clipboard smoke"))) {
    ClipboardWritten => ()
    _ => fail("expected native clipboard write")
  }
  match bridge.dispatch(Clipboard(ReadText)) {
    ClipboardText(text) => inspect(text, content="MoUI macOS clipboard smoke")
    _ => fail("expected native clipboard read")
  }
}

///|
test "macos service bridge reports failed open url" {
  let bridge = @macos.macos_service_bridge(system_theme=Light, open_url=_url => {
    false
  })
  match bridge.dispatch(OpenUrl("not-a-url")) {
    Unavailable(message) => inspect(message, content="open URL failed")
    _ => fail("expected failed open URL response")
  }
}

///|
test "macos service bridge reports unregistered platform channels unavailable" {
  let bridge = @macos.macos_service_bridge(system_theme=Light)
  match
    bridge.dispatch(
      PlatformChannel(
        @host.PlatformChannelRequest::new(
          channel="macos.missing",
          operation="probe",
        ),
      ),
    ) {
    Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: macos.missing")
    _ => fail("expected unavailable macOS platform channel")
  }
}

///|
test "macos service bridge exposes file dialog contract" {
  let seen_title = Ref("")
  let bridge = @macos.macos_service_bridge(system_theme=Light, file_dialog=options => {
    seen_title.val = options.title
    ["/tmp/moui.md"]
  })
  inspect(bridge.capabilities().file_dialogs, content="true")
  match
    bridge.dispatch(
      FileDialog(
        @host.HostFileDialogOptions::new(kind=OpenFile, title="Open Markdown", filters=[
          "*.md",
        ]),
      ),
    ) {
    FileDialogSelection(paths) => {
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
  let bridge = @macos.macos_service_bridge(system_theme=Light, menu=commands => {
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
test "macos service bridge reports cancelled or disabled menu selections" {
  let cancelled = @macos.macos_service_bridge(system_theme=Light, menu=_commands => {
    -1
  })
  match
    cancelled.dispatch(
      ShowMenu([@core.ActionCommand::new(intent=Copy, label="Copy")]),
    ) {
    Unavailable(message) => inspect(message, content="menu selection cancelled")
    _ => fail("expected cancelled menu response")
  }
  let disabled = @macos.macos_service_bridge(system_theme=Light, menu=_commands => {
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
test "macos backend converts resize event to host metrics" {
  let event = @window_input.window_event_to_host_with_modifiers(
    SurfaceResized(PhysicalSize(20, 40)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(Resized(metrics)) => {
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
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let event = @window_input.window_event_to_host_with_modifiers(
    SurfaceResized(PhysicalSize(1440, 900)),
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
test "macos backend converts scaled pointer coordinates to logical host points" {
  let moved = @window_input.window_event_to_host_with_modifiers(
    PointerMoved(None, PhysicalPositionF64(120.0, 80.0), true, Mouse),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match moved {
    Some(Pointer({ position, phase: Move, .. })) =>
      assert_true(position == @core.Point::new(x=60.0, y=40.0))
    _ => fail("expected scaled pointer move")
  }
  let down = @window_input.window_event_to_host_with_modifiers(
    PointerButton(
      None,
      Pressed,
      PhysicalPositionF64(140.0, 100.0),
      true,
      Mouse(Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match down {
    Some(Pointer({ position, phase, .. })) => {
      assert_true(position == @core.Point::new(x=70.0, y=50.0))
      assert_true(phase == Down)
    }
    _ => fail("expected scaled pointer button")
  }
}

///|
test "macos backend converts file drag drop to logical host event" {
  let drop = @window_input.window_event_to_host_with_modifiers(
    DragDropped(["/tmp/moui.md"], PhysicalPositionF64(120.0, 80.0)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match drop {
    Some(
      DragDrop(
        { phase: Dropped, paths, position: Some({ x: 60.0, y: 40.0, }), }
      )
    ) => inspect(paths[0], content="/tmp/moui.md")
    _ => fail("expected scaled file drop")
  }
}

///|
test "macos backend converts wheel and focus into host input contract" {
  let wheel = @window_input.window_event_to_host_with_modifiers(
    MouseWheel(None, PixelDelta(PhysicalPositionF64(16.0, -24.0)), Moved),
    @core.Point::new(x=4.0, y=5.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match wheel {
    Some(
      Scroll(
        {
          position: { x: 4.0, y: 5.0, },
          delta: Pixels({ x: 8.0, y: -12.0, }),
          ..
        }
      )
    ) => ()
    _ => fail("expected scaled wheel event")
  }
  let blur = @window_input.window_event_to_host_with_modifiers(
    Focused(false),
    @core.Point::new(x=7.0, y=9.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match blur {
    Some(Focus({ focused: false, pointer_cancel_position: None, })) => ()
    _ => fail("expected focus loss event")
  }
}

///|
test "macos backend converts close event" {
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
test "macos backend converts keyboard input event" {
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
  let event = match
    @window_input.window_event_to_host_with_modifiers(
      KeyboardInput(None, key_event, false),
      @core.Point::new(x=0.0, y=0.0),
      @core.KeyModifiers::new(shift=true),
    ) {
    Some(host_event) => host_event.to_core()
    None => None
  }
  match event {
    Some(Keyboard(event)) => {
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
  let preedit = @window_input.window_event_to_host(
    Ime(Preedit("ni", Some(ImeCursorRange(0, 2)))),
    @core.Point::new(x=0.0, y=0.0),
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
