///|
test "linux backend reports Wayland renderer readiness with explicit gaps" {
  let info = @linux.backend_info()
  assert_true(info.host_info.backend == Native)
  inspect(info.window_backend_available, content="true")
  inspect(info.renderer_available, content="true")
  inspect(info.capabilities.window, content="true")
  inspect(info.capabilities.renderer, content="true")
  inspect(info.capabilities.titlebar, content="true")
  inspect(info.capabilities.text_input, content="true")
  inspect(info.capabilities.ime, content="true")
  inspect(info.capabilities.clipboard, content="true")
  inspect(info.capabilities.drag_drop, content="true")
  inspect(info.capabilities.scale_factor, content="true")
  inspect(info.capabilities.accessibility, content="true")
  inspect(info.accessibility.kind, content="at-spi")
  inspect(info.accessibility.semantics_bridge_available, content="true")
  inspect(
    info.accessibility.native_accessibility_bridge_available,
    content="false",
  )
  inspect(info.services.clipboard, content="true")
  inspect(info.services.file_dialogs, content="true")
  inspect(info.services.file_access, content="true")
  inspect(info.services.open_url, content="true")
  inspect(info.services.menus, content="true")
  inspect(info.services.system_theme, content="true")
  inspect(info.readiness.ready, content="true")
  inspect(info.readiness.blocked_by.length(), content="0")
  assert_true(info.readiness.next_steps.length() >= 1)
}

///|
test "linux client decoration commands reserve a titlebar" {
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=232.0),
  )
  let decorations = @linux.LinuxClientDecorationState::new(active=true)
  let commands = @linux.linux_client_decorated_commands(
    [
      Clear(@core.Color::gray()),
      FillRect(
        @core.Rect::new(x=0.0, y=0.0, width=320.0, height=200.0),
        @core.Color::blue(),
      ),
    ],
    title="Inspector",
    metrics~,
    decorations~,
  )
  assert_true(commands.length() > 6)
  guard commands[0] is Clear(clear_color) else {
    fail("expected wrapper clear")
  }
  assert_true(clear_color == @core.Color::gray())
  guard commands[1] is FillRect({ size: { height, .. }, .. }, _) else {
    fail("expected titlebar fill")
  }
  inspect(height, content="32")
  assert_true(
    commands.any(command => command is DrawText({ text: "Inspector", .. })),
  )
  assert_true(
    commands.any(command => command is PushTransform({ ty: 32.0, .. })),
  )
  assert_false(commands[1:].any(command => command is Clear(_)))
}

///|
test "linux client decoration metrics and input stay in the content space" {
  let decorations = @linux.LinuxClientDecorationState::new(active=true)
  let content = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=200.0),
    scale_factor=2.0,
  )
  let surface = @linux.linux_surface_metrics_for_content(content, decorations)
  inspect(surface.logical_size.height, content="232")
  inspect(surface.physical_size.height, content="464")
  let recovered = @linux.linux_content_metrics_for_surface(surface, decorations)
  inspect(recovered.logical_size.height, content="200")
  inspect(recovered.physical_size.height, content="400")
  match
    @linux.linux_adjust_host_event_for_client_decorations(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=18.0),
          phase=Down,
        ),
      ),
      decorations,
    ) {
    None => ()
    Some(_) => fail("expected titlebar pointer to stay out of app content")
  }
  match
    @linux.linux_adjust_host_event_for_client_decorations(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=52.0),
          phase=Down,
        ),
      ),
      decorations,
    ) {
    Some(Pointer({ position, .. })) => inspect(position.y, content="20")
    _ => fail("expected content pointer to be translated")
  }
}

///|
test "linux backend carries tracked modifiers into keyboard events" {
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
  let modifiers = @window_input.modifiers_to_core(
    Modifiers(true, true, false, false),
  )
  let event = @window_input.window_event_to_host_with_modifiers(
    KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    modifiers,
  )
  match event {
    Some(Keyboard(event)) => {
      inspect(event.key, content="a")
      match event.text {
        Some(text) => inspect(text, content="a")
        None => fail("expected keyboard text")
      }
      inspect(event.pressed, content="true")
      inspect(event.modifiers.shift, content="true")
      inspect(event.modifiers.control, content="true")
      inspect(event.modifiers.alt, content="false")
    }
    _ => fail("expected Linux keyboard host event")
  }
}

///|
test "linux backend uses Wayland button event coordinates" {
  let event = @window_input.window_event_to_host_with_modifiers(
    PointerButton(
      None,
      Pressed,
      PhysicalPositionF64(42.0, 64.0),
      true,
      Mouse(Left),
    ),
    @core.Point::new(x=1.0, y=2.0),
    @core.KeyModifiers::none(),
  )
  match event {
    Some(Pointer(event)) => {
      inspect(event.position.x, content="42")
      inspect(event.position.y, content="64")
      assert_true(event.phase == Down)
      inspect(event.button, content="0")
    }
    _ => fail("expected Linux pointer button host event")
  }
}

///|
test "linux backend converts high dpi pointer coordinates to logical space" {
  let event = @window_input.window_event_to_host_with_modifiers(
    PointerMoved(None, PhysicalPositionF64(84.0, 128.0), true, Mouse),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(Pointer({ position, .. })) => {
      inspect(position.x, content="42")
      inspect(position.y, content="64")
    }
    _ => fail("expected logical high dpi pointer position")
  }
}

///|
test "linux backend preserves normalized vertical wheel direction" {
  let event = @window_input.window_event_to_host_with_modifiers(
    MouseWheel(None, PixelDelta(PhysicalPositionF64(0.0, -120.0)), Moved),
    @core.Point::new(x=8.0, y=24.0),
    @core.KeyModifiers::none(),
  )
  match event {
    Some(
      Scroll(
        {
          position: { x: 8.0, y: 24.0, },
          delta: Pixels({ x: 0.0, y: -120.0, }),
          ..
        }
      )
    ) => ()
    _ => fail("expected normalized Linux wheel delta to stay negative")
  }
}

///|
test "linux backend converts high dpi pixel scroll delta to logical space" {
  let event = @window_input.window_event_to_host_with_modifiers(
    MouseWheel(None, PixelDelta(PhysicalPositionF64(24.0, -120.0)), Moved),
    @core.Point::new(x=8.0, y=24.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(Scroll({ delta: Pixels({ x: 12.0, y: -60.0, }), .. })) => ()
    _ => fail("expected logical high dpi pixel scroll delta")
  }
}

///|
test "linux backend converts high dpi drag drop coordinates to logical space" {
  let event = @window_input.window_event_to_host_with_modifiers(
    DragDropped(["/tmp/high-dpi.txt"], PhysicalPositionF64(96.0, 144.0)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(
      DragDrop({ phase: Dropped, position: Some({ x: 48.0, y: 72.0, }), .. })
    ) => ()
    _ => fail("expected logical high dpi drag drop position")
  }
}

///|
test "linux capability summary exposes known service gaps" {
  let summary = @linux.linux_capability_summary()
  inspect(summary.label, content="Linux host")
  inspect(summary.services.system_theme, content="true")
  inspect(summary.services.clipboard, content="true")
  inspect(summary.services.file_dialogs, content="true")
  inspect(summary.services.file_access, content="true")
  inspect(summary.services.open_url, content="true")
  inspect(summary.services.menus, content="true")
  inspect(summary.service_count(), content="6")
  inspect(summary.input_count(), content="7")
  inspect(summary.text_input_available, content="true")
  inspect(summary.ime_available, content="true")
  inspect(summary.drag_drop_available, content="true")
  inspect(summary.has_required_app_basics(), content="true")
}

///|
test "linux service bridge routes real service contracts through handlers" {
  let clipboard_text = Ref("")
  let opened_url = Ref("")
  let bridge = @linux.linux_service_bridge(
    system_theme=Dark,
    clipboard=request => {
      match request {
        ReadText => ClipboardText(clipboard_text.val)
        WriteText(text) => {
          clipboard_text.val = text
          ClipboardWritten
        }
        ReadImage => Unavailable("clipboard image read is unavailable")
        WriteImage(_, _) => Unavailable("clipboard image write is unavailable")
      }
    },
    open_url=url => {
      opened_url.val = url
      true
    },
    file_dialog=options => {
      [
        match options.kind {
          OpenFile => "/tmp/open.txt"
          SaveFile => "/tmp/save.txt"
          PickDirectory => "/tmp"
        },
      ]
    },
    text_file=request => {
      match request {
        ReadText(path) => TextFileContent(path, "Linux text")
        WriteText(path, _text) => TextFileWritten(path)
      }
    },
    menu=_commands => -2,
  )
  inspect(bridge.capabilities().clipboard, content="true")
  inspect(bridge.capabilities().file_dialogs, content="true")
  inspect(bridge.capabilities().file_access, content="true")
  inspect(bridge.capabilities().open_url, content="true")
  inspect(bridge.capabilities().menus, content="true")
  match bridge.dispatch(Clipboard(WriteText("copied from Linux"))) {
    ClipboardWritten => ()
    _ => fail("expected Linux clipboard write")
  }
  match bridge.dispatch(Clipboard(ReadText)) {
    ClipboardText(text) => inspect(text, content="copied from Linux")
    _ => fail("expected Linux clipboard read")
  }
  match bridge.dispatch(OpenUrl("https://example.test")) {
    UrlOpened => inspect(opened_url.val, content="https://example.test")
    _ => fail("expected Linux URL open")
  }
  match
    bridge.dispatch(FileDialog(@host.HostFileDialogOptions::new(kind=OpenFile))) {
    FileDialogSelection(paths) => inspect(paths[0], content="/tmp/open.txt")
    _ => fail("expected Linux file dialog selection")
  }
  match bridge.dispatch(TextFile(ReadText("/tmp/note.md"))) {
    TextFileContent(path, text) => {
      inspect(path, content="/tmp/note.md")
      inspect(text, content="Linux text")
    }
    _ => fail("expected Linux text-file read")
  }
  match bridge.dispatch(ShowMenu([])) {
    Unavailable(message) =>
      inspect(message, content="menu service is unavailable")
    _ => fail("expected Linux native menu fallback")
  }
}

///|
test "linux service bridge reports unregistered platform channels unavailable" {
  let bridge = @linux.linux_service_bridge()
  match
    bridge.dispatch(
      PlatformChannel(
        @host.PlatformChannelRequest::new(
          channel="linux.missing",
          operation="probe",
        ),
      ),
    ) {
    Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: linux.missing")
    _ => fail("expected unavailable Linux platform channel")
  }
}

///|
test "linux service bridge exposes menu selection dispatch" {
  let seen_count = Ref(0)
  let bridge = @linux.linux_service_bridge(menu=commands => {
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
    _ => fail("expected selected Linux menu command")
  }
  inspect(seen_count.val, content="2")
}

///|
test "linux service bridge reports cancelled disabled and unavailable menu selections" {
  let cancelled = @linux.linux_service_bridge(menu=_commands => -1)
  match
    cancelled.dispatch(
      ShowMenu([@core.ActionCommand::new(intent=Copy, label="Copy")]),
    ) {
    Unavailable(message) => inspect(message, content="menu selection cancelled")
    _ => fail("expected cancelled Linux menu response")
  }
  let disabled = @linux.linux_service_bridge(menu=_commands => 0)
  match
    disabled.dispatch(
      ShowMenu([
        @core.ActionCommand::new(intent=Paste, label="Paste", enabled=false),
      ]),
    ) {
    Unavailable(message) => inspect(message, content="menu command is disabled")
    _ => fail("expected disabled Linux menu response")
  }
  let unavailable = @linux.linux_service_bridge(menu=_commands => -2)
  match
    unavailable.dispatch(
      ShowMenu([@core.ActionCommand::new(intent=Undo, label="Undo")]),
    ) {
    Unavailable(message) =>
      inspect(message, content="menu service is unavailable")
    _ => fail("expected unavailable Linux menu response")
  }
}

///|
test "linux scaffold exposes host contracts without owning a surface" {
  let surface = @linux.scaffold_surface_host(
    logical_width=320.0,
    logical_height=200.0,
    scale_factor=2.0,
  )
  assert_true(
    surface.logical_size() == @core.Size::new(width=320.0, height=200.0),
  )
  inspect(surface.owns_surface, content="false")
  inspect(surface.can_reconfigure, content="false")
  let input = @linux.scaffold_input_host()
  inspect(input.capabilities().text_input, content="false")
  inspect(input.capabilities().ime, content="false")
  inspect(input.capabilities().clipboard, content="false")
  inspect(input.capabilities().drag_drop, content="false")
  let services = @linux.scaffold_service_bridge()
  match services.dispatch(Clipboard(ReadText)) {
    Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected unavailable Linux scaffold service")
  }
  let platform_services = @linux.linux_service_bridge()
  match platform_services.dispatch(QuerySystemTheme) {
    SystemTheme(Light) => ()
    _ => fail("expected Linux platform system theme response")
  }
}

///|
test "linux host options construct without renderer dependencies" {
  let options = @linux.LinuxHostAppOptions::new()
  let _ = options
  assert_true(@linux.backend_info().renderer_available)
}

///|
test "linux accessibility bridge dispatches semantics actions" {
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
  let bridge = @linux.linux_accessibility_bridge(driver)
  inspect(@linux.linux_accessibility_bridge_info().kind, content="at-spi")
  inspect(bridge.available, content="true")
  match bridge.publish_semantics(Full(snapshot)) {
    Some(_) => ()
    None => fail("expected Linux AT-SPI semantics update")
  }
  match
    bridge.perform_action(
      @accesskit_bridge.accesskit_semantics_action_request(
        node_id=target.node_id,
        generation=snapshot.generation(),
        action=Activate,
      ),
    ) {
    Handled(receipt) => assert_true(receipt.before == snapshot.generation())
    _ => fail("expected Linux accessibility bridge action dispatch")
  }
}

///|
test "linux list directory service returns entries for existing directory" {
  let bridge = @linux.linux_service_bridge()
  match bridge.dispatch(ListDirectory("/tmp")) {
    DirectoryListing(path, entries) => {
      inspect(path, content="/tmp")
      assert_true(entries.length() >= 0)
    }
    Unavailable(_) =>
      fail(
        "expected Linux ListDirectory to use @fs.read_dir instead of unavailable",
      )
    _ => fail("expected DirectoryListing response")
  }
}

///|
test "linux list directory returns empty list for missing path" {
  let bridge = @linux.linux_service_bridge()
  match bridge.dispatch(ListDirectory("/tmp/moui-nonexistent-directory-xyz")) {
    DirectoryListing(path, entries) => {
      inspect(path, content="/tmp/moui-nonexistent-directory-xyz")
      inspect(entries.length(), content="0")
    }
    _ => fail("expected empty DirectoryListing for missing path")
  }
}

///|
test "linux list directory hides dotfiles and reports is_directory" {
  let bridge = @linux.linux_service_bridge(list_directory=path => {
    let entries : Array[@host.HostDirectoryEntry] = [
      @host.HostDirectoryEntry::new(
        name="readme.md",
        path=path + "/readme.md",
        is_directory=false,
      ),
      @host.HostDirectoryEntry::new(
        name="src",
        path=path + "/src",
        is_directory=true,
      ),
      @host.HostDirectoryEntry::new(
        name=".git",
        path=path + "/.git",
        is_directory=true,
      ),
    ]
    DirectoryListing(path, entries)
  })
  match bridge.dispatch(ListDirectory("/tmp/project")) {
    DirectoryListing(path, entries) => {
      inspect(path, content="/tmp/project")
      inspect(entries.length(), content="3")
      assert_true(
        entries.any(entry => {
          entry.name() == "readme.md" && !entry.is_directory()
        }),
      )
      assert_true(
        entries.any(entry => entry.name() == "src" && entry.is_directory()),
      )
      assert_true(
        entries.any(entry => entry.name() == ".git" && entry.is_directory()),
      )
    }
    _ => fail("expected ListDirectory response with test entries")
  }
}

///|
test "linux list directory filters hidden files in real dispatch" {
  let bridge = @linux.linux_service_bridge()
  match bridge.dispatch(ListDirectory("/tmp")) {
    DirectoryListing(_, listing) =>
      assert_true(listing.all(entry => !entry.name().has_prefix(".")))
    _ => ()
  }
}
