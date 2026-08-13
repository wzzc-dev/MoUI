///|
test "linux backend reports Wayland renderer readiness with explicit gaps" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
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
  let decorations = LinuxClientDecorationState::new(active=true)
  let commands = linux_client_decorated_commands(
    [
      @core.DrawCommand::Clear(@core.Color::gray()),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=0.0, y=0.0, width=320.0, height=200.0),
        @core.Color::blue(),
      ),
    ],
    title="Inspector",
    metrics~,
    decorations~,
  )
  assert_true(commands.length() > 6)
  guard commands[0] is @core.DrawCommand::Clear(clear_color) else {
    fail("expected wrapper clear")
  }
  assert_true(clear_color == @core.Color::gray())
  guard commands[1]
    is @core.DrawCommand::FillRect({ size: { height, .. }, .. }, _) else {
    fail("expected titlebar fill")
  }
  inspect(height, content="32")
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Inspector", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::PushTransform({ ty: 32.0, .. })
    }),
  )
  assert_false(
    commands[1:].any(command => command is @core.DrawCommand::Clear(_)),
  )
}

///|
test "linux client decoration metrics and input stay in the content space" {
  let decorations = LinuxClientDecorationState::new(active=true)
  let content = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=200.0),
    scale_factor=2.0,
  )
  let surface = linux_surface_metrics_for_content(content, decorations)
  inspect(surface.logical_size.height, content="232")
  inspect(surface.physical_size.height, content="464")
  let recovered = linux_content_metrics_for_surface(surface, decorations)
  inspect(recovered.logical_size.height, content="200")
  inspect(recovered.physical_size.height, content="400")
  match
    linux_adjust_host_event_for_client_decorations(
      @host.Event::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=18.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
      decorations,
    ) {
    None => ()
    Some(_) => fail("expected titlebar pointer to stay out of app content")
  }
  match
    linux_adjust_host_event_for_client_decorations(
      @host.Event::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=52.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
      decorations,
    ) {
    Some(@host.Event::Pointer({ position, .. })) =>
      inspect(position.y, content="20")
    _ => fail("expected content pointer to be translated")
  }
}

///|
test "linux backend carries tracked modifiers into keyboard events" {
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
  let modifiers = @window_input.modifiers_to_core(
    @window_core.Modifiers::Modifiers(true, true, false, false),
  )
  let event = @window_input.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    modifiers,
  )
  match event {
    Some(@host.Event::Keyboard(event)) => {
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
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(42.0, 64.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=1.0, y=2.0),
    @core.KeyModifiers::none(),
  )
  match event {
    Some(@host.Event::Pointer(event)) => {
      inspect(event.position.x, content="42")
      inspect(event.position.y, content="64")
      assert_true(event.phase == @core.PointerPhase::Down)
      inspect(event.button, content="0")
    }
    _ => fail("expected Linux pointer button host event")
  }
}

///|
test "linux backend converts high dpi pointer coordinates to logical space" {
  let event = @window_input.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(84.0, 128.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(@host.Event::Pointer({ position, .. })) => {
      inspect(position.x, content="42")
      inspect(position.y, content="64")
    }
    _ => fail("expected logical high dpi pointer position")
  }
}

///|
test "linux backend preserves normalized vertical wheel direction" {
  let event = @window_input.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::MouseWheel(
      None,
      @window_core.MouseScrollDelta::PixelDelta(
        @dpi.PhysicalPositionF64::PhysicalPositionF64(0.0, -120.0),
      ),
      @window_core.TouchPhase::Moved,
    ),
    @core.Point::new(x=8.0, y=24.0),
    @core.KeyModifiers::none(),
  )
  match event {
    Some(
      @host.Event::Scroll(
        {
          position: { x: 8.0, y: 24.0 },
          delta: @host.HostScrollDelta::Pixels({ x: 0.0, y: -120.0 }),
          ..,
        }
      )
    ) => ()
    _ => fail("expected normalized Linux wheel delta to stay negative")
  }
}

///|
test "linux backend converts high dpi pixel scroll delta to logical space" {
  let event = @window_input.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::MouseWheel(
      None,
      @window_core.MouseScrollDelta::PixelDelta(
        @dpi.PhysicalPositionF64::PhysicalPositionF64(24.0, -120.0),
      ),
      @window_core.TouchPhase::Moved,
    ),
    @core.Point::new(x=8.0, y=24.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(
      @host.Event::Scroll(
        { delta: @host.HostScrollDelta::Pixels({ x: 12.0, y: -60.0 }), .. }
      )
    ) => ()
    _ => fail("expected logical high dpi pixel scroll delta")
  }
}

///|
test "linux backend converts high dpi drag drop coordinates to logical space" {
  let event = @window_input.window_event_to_host_with_modifiers(
    @window_core.WindowEvent::DragDropped(
      ["/tmp/high-dpi.txt"],
      @dpi.PhysicalPositionF64::PhysicalPositionF64(96.0, 144.0),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(
      @host.Event::DragDrop(
        {
          phase: @core.DragDropPhase::Dropped,
          position: Some({ x: 48.0, y: 72.0 }),
          ..,
        }
      )
    ) => ()
    _ => fail("expected logical high dpi drag drop position")
  }
}

///|
test "linux capability summary exposes known service gaps" {
  let summary = linux_capability_summary()
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
  let bridge = linux_service_bridge(
    system_theme=@core.ColorScheme::Dark,
    clipboard=request => {
      match request {
        @host.HostClipboardRequest::ReadText =>
          @host.HostServiceResponse::ClipboardText(clipboard_text.val)
        @host.HostClipboardRequest::WriteText(text) => {
          clipboard_text.val = text
          @host.HostServiceResponse::ClipboardWritten
        }
        @host.HostClipboardRequest::ReadImage =>
          @host.HostServiceResponse::Unavailable(
            "clipboard image read is unavailable",
          )
        @host.HostClipboardRequest::WriteImage(_, _) =>
          @host.HostServiceResponse::Unavailable(
            "clipboard image write is unavailable",
          )
      }
    },
    open_url=url => {
      opened_url.val = url
      true
    },
    file_dialog=options => {
      [
        match options.kind {
          @host.HostFileDialogKind::OpenFile => "/tmp/open.txt"
          @host.HostFileDialogKind::SaveFile => "/tmp/save.txt"
          @host.HostFileDialogKind::PickDirectory => "/tmp"
        },
      ]
    },
    text_file=request => {
      match request {
        @host.HostTextFileRequest::ReadText(path) =>
          @host.HostServiceResponse::TextFileContent(path, "Linux text")
        @host.HostTextFileRequest::WriteText(path, _text) =>
          @host.HostServiceResponse::TextFileWritten(path)
      }
    },
    menu=_commands => -2,
  )
  inspect(bridge.capabilities().clipboard, content="true")
  inspect(bridge.capabilities().file_dialogs, content="true")
  inspect(bridge.capabilities().file_access, content="true")
  inspect(bridge.capabilities().open_url, content="true")
  inspect(bridge.capabilities().menus, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::WriteText("copied from Linux"),
      ),
    ) {
    @host.HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected Linux clipboard write")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::ClipboardText(text) =>
      inspect(text, content="copied from Linux")
    _ => fail("expected Linux clipboard read")
  }
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened =>
      inspect(opened_url.val, content="https://example.test")
    _ => fail("expected Linux URL open")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::OpenFile,
        ),
      ),
    ) {
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      inspect(paths[0], content="/tmp/open.txt")
    _ => fail("expected Linux file dialog selection")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::ReadText("/tmp/note.md"),
      ),
    ) {
    @host.HostServiceResponse::TextFileContent(path, text) => {
      inspect(path, content="/tmp/note.md")
      inspect(text, content="Linux text")
    }
    _ => fail("expected Linux text-file read")
  }
  match bridge.dispatch(@host.HostServiceRequest::ShowMenu([])) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="menu service is unavailable")
    _ => fail("expected Linux native menu fallback")
  }
}

///|
test "linux service bridge reports unregistered platform channels unavailable" {
  let bridge = linux_service_bridge()
  match
    bridge.dispatch(
      @host.HostServiceRequest::PlatformChannel(
        @host.PlatformChannelRequest::new(
          channel="linux.missing",
          operation="probe",
        ),
      ),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: linux.missing")
    _ => fail("expected unavailable Linux platform channel")
  }
}

///|
test "linux service bridge exposes menu selection dispatch" {
  let seen_count = Ref(0)
  let bridge = linux_service_bridge(menu=commands => {
    seen_count.val = commands.length()
    1
  })
  inspect(bridge.capabilities().menus, content="true")
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
    _ => fail("expected selected Linux menu command")
  }
  inspect(seen_count.val, content="2")
}

///|
test "linux service bridge reports cancelled disabled and unavailable menu selections" {
  let cancelled = linux_service_bridge(menu=_commands => -1)
  match
    cancelled.dispatch(
      @host.HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      ]),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="menu selection cancelled")
    _ => fail("expected cancelled Linux menu response")
  }
  let disabled = linux_service_bridge(menu=_commands => 0)
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
    _ => fail("expected disabled Linux menu response")
  }
  let unavailable = linux_service_bridge(menu=_commands => -2)
  match
    unavailable.dispatch(
      @host.HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Undo, label="Undo"),
      ]),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="menu service is unavailable")
    _ => fail("expected unavailable Linux menu response")
  }
}

///|
test "linux scaffold exposes host contracts without owning a surface" {
  let surface = scaffold_surface_host(
    logical_width=320.0,
    logical_height=200.0,
    scale_factor=2.0,
  )
  assert_true(
    surface.logical_size() == @core.Size::new(width=320.0, height=200.0),
  )
  inspect(surface.owns_surface, content="false")
  inspect(surface.can_reconfigure, content="false")
  let input = scaffold_input_host()
  inspect(input.capabilities().text_input, content="false")
  inspect(input.capabilities().ime, content="false")
  inspect(input.capabilities().clipboard, content="false")
  inspect(input.capabilities().drag_drop, content="false")
  let services = scaffold_service_bridge()
  match
    services.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected unavailable Linux scaffold service")
  }
  let platform_services = linux_service_bridge()
  match platform_services.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Light) => ()
    _ => fail("expected Linux platform system theme response")
  }
}

///|
test "linux host options construct without renderer dependencies" {
  let options = LinuxHostAppOptions::new()
  let _ = options
  assert_true(backend_info().renderer_available)
}

///|
test "linux accessibility bridge dispatches semantics actions" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.button("Run", on_click=()) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=60.0),
  )
  let snapshot = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => snapshot
    _ => abort("expected full committed semantics")
  }
  let mut target : @core.SemanticsNode? = None
  for node in snapshot.nodes() {
    if node.actions.any(action => action == @core.SemanticsActionKind::Activate) {
      target = Some(node)
    }
  }
  let target = target.unwrap()
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = linux_accessibility_bridge(driver)
  inspect(linux_accessibility_bridge_info().kind, content="at-spi")
  inspect(bridge.available, content="true")
  match bridge.publish_semantics(@runtime.SemanticsRead::Full(snapshot)) {
    Some(_) => ()
    None => fail("expected Linux AT-SPI semantics update")
  }
  match
    bridge.perform_action(
      @accesskit_bridge.accesskit_semantics_action_request(
        node_id=target.node_id,
        generation=snapshot.generation(),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @accesskit_bridge.AccessKitActionResult::Handled(receipt) =>
      assert_true(receipt.before == snapshot.generation())
    _ => fail("expected Linux accessibility bridge action dispatch")
  }
}

///|
test "linux list directory service returns entries for existing directory" {
  let bridge = linux_service_bridge()
  match bridge.dispatch(@host.HostServiceRequest::ListDirectory("/tmp")) {
    @host.HostServiceResponse::DirectoryListing(path, entries) => {
      inspect(path, content="/tmp")
      assert_true(entries.length() >= 0)
    }
    @host.HostServiceResponse::Unavailable(_) =>
      fail(
        "expected Linux ListDirectory to use @fs.read_dir instead of unavailable",
      )
    _ => fail("expected DirectoryListing response")
  }
}

///|
test "linux list directory returns empty list for missing path" {
  let bridge = linux_service_bridge()
  match
    bridge.dispatch(
      @host.HostServiceRequest::ListDirectory(
        "/tmp/moui-nonexistent-directory-xyz",
      ),
    ) {
    @host.HostServiceResponse::DirectoryListing(path, entries) => {
      inspect(path, content="/tmp/moui-nonexistent-directory-xyz")
      inspect(entries.length(), content="0")
    }
    _ => fail("expected empty DirectoryListing for missing path")
  }
}

///|
test "linux list directory hides dotfiles and reports is_directory" {
  let bridge = linux_service_bridge(list_directory=path => {
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
    @host.HostServiceResponse::DirectoryListing(path, entries)
  })
  match
    bridge.dispatch(@host.HostServiceRequest::ListDirectory("/tmp/project")) {
    @host.HostServiceResponse::DirectoryListing(path, entries) => {
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
  let bridge = linux_service_bridge()
  match bridge.dispatch(@host.HostServiceRequest::ListDirectory("/tmp")) {
    @host.HostServiceResponse::DirectoryListing(_, listing) =>
      assert_true(listing.all(entry => !entry.name().has_prefix(".")))
    _ => ()
  }
}
