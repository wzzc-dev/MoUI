///|
test "host surface metrics tracks logical physical and dpr" {
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
    scale_factor=2.0,
  )
  assert_true(metrics.logical_size == @core.Size::new(width=120.0, height=80.0))
  assert_true(
    metrics.physical_size == @core.Size::new(width=240.0, height=160.0),
  )
  inspect(metrics.scale_factor, content="2")
}

///|
test "host app info records shared model boundaries" {
  let info = HostAppInfo::new(
    backend=HostBackendKind::Native,
    description="native host",
  )
  assert_true(info.backend == HostBackendKind::Native)
  inspect(info.uses_shared_event_model, content="true")
  inspect(info.uses_shared_surface_model, content="true")
  inspect(info.uses_shared_input_model, content="true")
}

///|
test "input host owns capabilities focus modifiers and text input gating" {
  let input = InputHostState::new()
  let capabilities = input.capabilities()
  inspect(capabilities.pointer, content="true")
  inspect(capabilities.scroll, content="true")
  inspect(capabilities.ime, content="false")
  inspect(capabilities.drag_drop, content="false")
  inspect(input.coordinate_policy().scale_factor_applied, content="true")
  match input.insert_text("a") {
    None => ()
    Some(_) => fail("unfocused input host should not emit text")
  }
  match input.focus_event(focused=true) {
    Some(HostEvent::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
  input.set_modifiers(@core.KeyModifiers::new(shift=true))
  let key_event = input.keyboard_event(key="A", text=Some("A"))
  match key_event {
    Some(HostEvent::Keyboard(event)) => {
      inspect(event.key, content="A")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
  match input.insert_text("A") {
    Some(HostEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="A")
    _ => fail("expected focused text input")
  }
  match input.focus_event(focused=false) {
    Some(HostEvent::Focus({ focused: false, .. })) => ()
    _ => fail("expected blur event")
  }
  match input.insert_text("b") {
    None => ()
    Some(_) => fail("blurred input host should not emit text")
  }
}

///|
test "host converts window drag drop events to logical core events" {
  let event = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::DragDropped(
      ["/tmp/note.md"],
      @dpi.PhysicalPositionF64::PhysicalPositionF64(24.0, 48.0),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(
      HostEvent::DragDrop(
        {
          phase: @core.DragDropPhase::Dropped,
          paths,
          position: Some({ x: 12.0, y: 24.0 }),
        }
      )
    ) => inspect(paths[0], content="/tmp/note.md")
    _ => fail("expected logical file drop")
  }
  match event {
    Some(host_event) =>
      match host_event.to_core() {
        Some(
          @core.AppEvent::DragDrop({ phase: @core.DragDropPhase::Dropped, .. })
        ) => ()
        _ => fail("expected drag drop app event")
      }
    _ => fail("expected drag drop app event")
  }
  let left = window_event_to_host(
    @window_core.WindowEvent::DragLeft(None),
    @core.Point::new(x=0.0, y=0.0),
  )
  match left {
    Some(
      HostEvent::DragDrop(
        { phase: @core.DragDropPhase::Left, position: None, .. }
      )
    ) => ()
    _ => fail("expected drag left without position")
  }
}

///|
test "host recognizes secondary pointer context menu requests" {
  let right_down = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Pressed,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Right),
  )
  inspect(window_event_is_context_menu_trigger(right_down), content="true")
  inspect(window_event_is_context_menu_button(right_down), content="true")
  let right_up = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Released,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Right),
  )
  inspect(window_event_is_context_menu_trigger(right_up), content="false")
  inspect(window_event_is_context_menu_button(right_up), content="true")
  let left_down = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Pressed,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
  )
  inspect(window_event_is_context_menu_button(left_down), content="false")
}

///|
test "surface host resizes through host event" {
  let surface = SurfaceHostState::new(
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=10.0, height=10.0),
    ),
    owns_surface=true,
  )
  let event = surface.resize(
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=20.0, height=12.0),
      scale_factor=2.0,
    ),
  )
  match event {
    HostEvent::Resized(metrics) => {
      assert_true(
        surface.logical_size() == @core.Size::new(width=20.0, height=12.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=40.0, height=24.0),
      )
      inspect(surface.owns_surface, content="true")
      inspect(surface.can_reconfigure, content="true")
    }
    _ => fail("expected resize event")
  }
}

///|
test "host window registry tracks primary focus resize and close lifecycle" {
  let registry = HostWindowRegistry::new()
  let first = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  let second = registry.open(
    title="Inspector",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=480.0),
    ),
  )
  inspect(registry.open_window_count(), content="2")
  match registry.primary_window() {
    Some({ id, title, .. }) => {
      assert_true(id == first)
      inspect(title, content="Main")
    }
    None => fail("expected first window to become primary")
  }
  assert_true(registry.focus(second))
  match registry.focused_window() {
    Some({ id, phase, .. }) => {
      assert_true(id == second)
      assert_true(phase == HostWindowLifecyclePhase::WindowFocused)
    }
    None => fail("expected focused window")
  }
  assert_true(
    registry.resize(
      second,
      HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=400.0, height=500.0),
        scale_factor=2.0,
      ),
    ),
  )
  match registry.lookup(second) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=400.0, height=500.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=800.0, height=1000.0),
      )
    }
    None => fail("expected resized window")
  }
  assert_true(registry.close(first))
  match registry.primary_window() {
    Some({ id, .. }) => assert_true(id == second)
    None => fail("expected primary reassigned after close")
  }
  inspect(registry.remove_closed(), content="1")
  inspect(registry.open_window_count(), content="1")
  inspect(
    registry.resize(
      first,
      HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=1.0, height=1.0),
      ),
    ),
    content="false",
  )
  inspect(registry.close(first), content="false")
}

///|
test "host window registry applies shared lifecycle host events" {
  let registry = HostWindowRegistry::new()
  let window_id = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  assert_true(
    registry.apply_host_event(
      window_id,
      HostEvent::Resized(
        HostSurfaceMetrics::from_logical(
          size=@core.Size::new(width=640.0, height=480.0),
          scale_factor=2.0,
        ),
      ),
    ),
  )
  match registry.lookup(window_id) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=1280.0, height=960.0),
      )
    }
    None => fail("expected lifecycle window")
  }
  assert_true(
    registry.apply_host_event(
      window_id,
      HostEvent::Focus(HostFocusEvent::new(focused=true)),
    ),
  )
  match registry.focused_window() {
    Some({ id, .. }) => assert_true(id == window_id)
    None => fail("expected focused window")
  }
  assert_true(
    registry.apply_host_event(
      window_id,
      HostEvent::Focus(HostFocusEvent::new(focused=false)),
    ),
  )
  match registry.lookup(window_id) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowVisible)
    None => fail("expected blurred window")
  }
  assert_true(registry.apply_host_event(window_id, HostEvent::CloseRequested))
  match registry.lookup(window_id) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowCloseRequested)
    None => fail("expected close-requested window")
  }
  inspect(
    registry.apply_host_event(window_id, HostEvent::RedrawRequested),
    content="false",
  )
}

///|
test "host service bridge gates typed platform requests by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(_)) => HostServiceResponse::ClipboardWritten
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("copied")
        ShowMenu(commands) =>
          if commands.length() > 0 {
            HostServiceResponse::MenuCommand(commands[0].intent)
          } else {
            HostServiceResponse::Unavailable("empty menu")
          }
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("not implemented")
      }
    },
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
    ) {
    HostServiceResponse::ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard text")
  }
  match
    bridge.dispatch(
      HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      ]),
    ) {
    HostServiceResponse::MenuCommand(@core.CommandIntent::Copy) => ()
    _ => fail("expected selected menu command")
  }
  match
    bridge.dispatch(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file dialog")
  }
}

///|
test "host driver dispatches command intents through runtime action map" {
  let copied = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Copy),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let result = driver.dispatch(HostEvent::Command(@core.CommandIntent::Copy))
  inspect(copied.val, content="1")
  inspect(result.redraw_requested, content="true")
  match HostEvent::Command(@core.CommandIntent::Copy).to_core() {
    None => ()
    Some(_) => fail("host command should dispatch through runtime action map")
  }
}

///|
test "host driver shows context menu from action commands" {
  let submitted = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Submit,
          label="Submit",
        ),
        handle=() => submitted.val = submitted.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let seen_count = Ref(0)
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          seen_count.val = commands.length()
          HostServiceResponse::MenuCommand(commands[0].intent)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(driver.show_context_menu(services))
  inspect(seen_count.val, content="1")
  inspect(submitted.val, content="1")
}

///|
test "host service bridge routes typed platform channels" {
  let bridge = HostServiceBridge::unavailable()
  bridge.register_channel(
    PlatformChannelHandler::new(channel="clipboard.extra", handle=request => {
      if request.operation == "echo" {
        PlatformChannelResponse::Ok(request.payload)
      } else {
        PlatformChannelResponse::Error("unknown method")
      }
    }),
  )
  match
    bridge.dispatch_channel(
      PlatformChannelRequest::new(
        channel="clipboard.extra",
        operation="echo",
        payload="hello",
      ),
    ) {
    PlatformChannelResponse::Ok(value) => inspect(value, content="hello")
    _ => fail("expected platform channel response")
  }
  match
    bridge.dispatch_channel(
      PlatformChannelRequest::new(channel="missing", operation="echo"),
    ) {
    PlatformChannelResponse::Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: missing")
    _ => fail("expected unavailable platform channel")
  }
}

///|
test "host service bridge routes registered typed services before fallback" {
  let fallback = Ref(0)
  let clipboard_written = Ref("")
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      fallback.val = fallback.val + 1
      HostServiceResponse::Unavailable(request.unavailable_message())
    },
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::ClipboardService, handle=request => {
      match request {
        Clipboard(WriteText(text)) => {
          clipboard_written.val = text
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("registered")
        _ => HostServiceResponse::Unavailable("wrong service")
      }
    }),
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::SystemThemeService, handle=_request => {
      HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
    }),
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::WriteText("hello")),
    ) {
    HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected registered clipboard service")
  }
  inspect(clipboard_written.val, content="hello")
  match bridge.dispatch(HostServiceRequest::QuerySystemTheme) {
    HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected registered theme service")
  }
  match bridge.dispatch(HostServiceRequest::OpenUrl("https://example.test")) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL service is unavailable")
    _ => fail("expected fallback service")
  }
  inspect(fallback.val, content="1")
}

///|
test "host service bridge gates registered services by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::none(),
    handle=_request => HostServiceResponse::ClipboardWritten,
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::ClipboardService, handle=_request => {
      HostServiceResponse::ClipboardWritten
    }),
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::WriteText("blocked")),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected capability gate before registered service")
  }
}

///|
test "native accessibility bridge snapshots semantics recursively" {
  let child = @core.SemanticsNode::{
    element_id: @core.ElementId::new(2),
    role: @core.SemanticsRole::Button,
    label: "Save",
    value: "",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=8.0, y=8.0, width=80.0, height=32.0),
    children: [],
  }
  let root = @core.SemanticsNode::{
    element_id: @core.ElementId::new(1),
    role: @core.SemanticsRole::Group,
    label: "Root",
    value: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    children: [child],
  }
  let bridge = NativeAccessibilityBridge::new(
    kind=NativeAccessibilityBridgeKind::TestBridge,
  )
  match bridge.snapshot_semantics(root) {
    Some(snapshot) => {
      inspect(snapshot.nodes().length(), content="2")
      inspect(snapshot.tree() is Some(_), content="true")
      inspect(snapshot.focus(), content="NodeId(1)")
      let child_update = snapshot.nodes()[1]
      inspect(child_update.node().role(), content="Button")
      match child_update.node().label() {
        Some(label) => inspect(label, content="Save")
        None => fail("expected child accessibility label")
      }
      inspect(
        child_update.node().supports_action(@accesskit.Action::Click),
        content="true",
      )
    }
    None => fail("expected accessibility snapshot")
  }
}

///|
test "native accessibility bridge validates action roundtrip" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(42),
    role: @core.SemanticsRole::TextField,
    label: "Name",
    value: "MoUI",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Focus, @core.SemanticsAction::SetText],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    children: [],
  }
  let bridge = NativeAccessibilityBridge::semantics_action_bridge(
    kind=NativeAccessibilityBridgeKind::TestBridge,
    root=node,
    dispatch=(element_id, action, value) => {
      if element_id == @core.ElementId::new(42) &&
        action == @core.SemanticsAction::SetText &&
        value == Some("Luna") {
        invoked.val = invoked.val + 1
        true
      } else {
        false
      }
    },
  )
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(42),
        action=@core.SemanticsAction::SetText,
        value=Some("Luna"),
      ),
    ) {
    NativeAccessibilityActionResult::Handled => ()
    _ => fail("expected handled action")
  }
  inspect(invoked.val, content="1")
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(42),
        action=@core.SemanticsAction::Submit,
      ),
    ) {
    NativeAccessibilityActionResult::Unsupported(message) =>
      inspect(message, content="semantics node does not expose action: submit")
    _ => fail("expected unsupported action")
  }
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(7),
        action=@core.SemanticsAction::Focus,
      ),
    ) {
    NativeAccessibilityActionResult::ElementNotFound({ value: 7 }) => ()
    _ => fail("expected missing element result")
  }
}

///|
test "host driver dispatches resize and deduplicates redraw requests" {
  let scheduled = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let first = driver.dispatch(HostEvent::Resized(metrics))
  let second = driver.dispatch(HostEvent::Resized(metrics))
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(first.redraw_requested, content="true")
  inspect(second.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(driver.dispatch(HostEvent::Resized(metrics)))
  inspect(scheduled.val, content="2")
}

///|
test "host driver maps focused text input through core text input event" {
  let text = @core.State::new("")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=400),
      foreground: @core.Color::black(),
      placeholder_color: @core.Color::gray(),
      background: @core.Brush::solid(@core.Color::white()),
      border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::gray()),
          width=1.0,
        ),
      ),
      focused_border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::blue()),
          width=2.0,
        ),
      ),
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(HostEvent::TextInput(@core.TextInputEvent::InsertText("a"))),
  )
  inspect(text.get(), content="")
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  let result = driver.dispatch(
    HostEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.get(), content="a")
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver routes text clipboard commands through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=400),
      foreground: @core.Color::black(),
      placeholder_color: @core.Color::gray(),
      background: @core.Brush::solid(@core.Color::white()),
      border: None,
      focused_border: None,
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Copy, bridge),
  )
  inspect(clipboard.val, content="hello")
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Cut, bridge),
  )
  inspect(text.get(), content="")
  clipboard.val = "world"
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Paste, bridge),
  )
  inspect(text.get(), content="world")
}

///|
test "host driver routes clipboard keyboard shortcuts through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=400),
      foreground: @core.Color::black(),
      placeholder_color: @core.Color::gray(),
      background: @core.Brush::solid(@core.Color::white()),
      border: None,
      focused_border: None,
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  inspect(clipboard.val, content="hello")
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="")
  clipboard.val = "world"
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="v",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="world")
}

///|
test "host driver falls back clipboard shortcuts to action commands" {
  let copied = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Copy),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=_request => HostServiceResponse::ClipboardWritten,
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(copied.val, content="1")
}

///|
test "host driver dispatches ime composition text input events" {
  let text = @core.State::new("")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=400),
      foreground: @core.Color::black(),
      placeholder_color: @core.Color::gray(),
      background: @core.Brush::solid(@core.Color::white()),
      border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::gray()),
          width=1.0,
        ),
      ),
      focused_border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::blue()),
          width=2.0,
        ),
      ),
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionEnd("你")),
    ),
  )
  inspect(text.get(), content="你")
}

///|
test "text input session enables updates and disables ime requests" {
  let text = @core.State::new("ab")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::FlexSpec({
      key: None,
      axis: @core.Axis::Vertical,
      spacing: 4.0,
      main_axis_alignment: @core.MainAxisAlignment::MainStart,
      cross_axis_alignment: @core.CrossAxisAlignment::CrossStart,
      children: [
        @core.ViewSpec::TextFieldSpec({
          key: None,
          value: text.binding(),
          placeholder: "Type",
          size: @core.Size::new(width=120.0, height=40.0),
          font: @core.FontSpec::new(size=16.0, weight=400),
          foreground: @core.Color::black(),
          placeholder_color: @core.Color::gray(),
          background: @core.Brush::solid(@core.Color::white()),
          border: None,
          focused_border: None,
          cursor_color: @core.Color::blue(),
          corner_radius: 0.0,
          on_submit: None,
        }),
      ],
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let session = TextInputSession::new()
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unfocused runtime should not change ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    EnableIme(@window_core.ImeRequest::Enable(_)) => ()
    _ => fail("focused text field should enable ime")
  }
  match session.sync(runtime.focused_text_input()) {
    UpdateIme(@window_core.ImeRequest::Update(data)) => {
      match data.cursor_area() {
        Some((_, size)) => assert_true(size.to_logical(1.0).height() > 0.0)
        None => fail("expected cursor area")
      }
      match data.surrounding_text() {
        Some(surrounding) => inspect(surrounding.text(), content="ab")
        None => fail("expected surrounding text")
      }
    }
    _ => fail("focused text field should update active ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=230.0, y=55.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    DisableIme(@window_core.ImeRequest::Disable) => ()
    _ => fail("blur should disable ime")
  }
}

///|
test "text input session enables ime when surrounding text is too long" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "a".repeat(@window_core.ImeSurroundingText::max_text_bytes() + 1),
    caret: 0,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) => {
      assert_true(!request.capabilities().surrounding_text())
      assert_true(!request.request_data().has_surrounding_text())
    }
    _ => fail("focused text field should still enable ime")
  }
}

///|
test "text input session preserves selection anchor in ime surrounding text" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "你ab好",
    caret: 3,
    selection: Some(@core.TextRange::new(start=1, end=3)),
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) =>
      match request.request_data().surrounding_text() {
        Some(surrounding) => {
          inspect(surrounding.cursor(), content="5")
          inspect(surrounding.anchor(), content="3")
        }
        None => fail("expected surrounding text")
      }
    _ => fail("focused text field should enable ime")
  }
}

///|
test "text input session preserves reverse selection anchor in ime surrounding text" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "你ab好",
    caret: 1,
    selection: Some(@core.TextRange::new(start=3, end=1)),
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) =>
      match request.request_data().surrounding_text() {
        Some(surrounding) => {
          inspect(surrounding.cursor(), content="3")
          inspect(surrounding.anchor(), content="5")
        }
        None => fail("expected surrounding text")
      }
    _ => fail("focused text field should enable ime")
  }
}

///|
test "host event converts to current core event model" {
  let event = HostEvent::TextInput(@core.TextInputEvent::InsertText("x")).to_core()
  match event {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="x")
    _ => fail("expected text input event")
  }
  let composition = HostEvent::TextInput(
    @core.TextInputEvent::CompositionEnd("你"),
  ).to_core()
  match composition {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="你")
    _ => fail("expected composition text input event")
  }
  let scroll = HostEvent::Scroll(
    HostScrollEvent::new(
      position=@core.Point::new(x=8.0, y=9.0),
      delta=HostScrollDelta::Lines(@core.Point::new(x=1.0, y=-2.0)),
    ),
  ).to_core()
  match scroll {
    Some(@core.AppEvent::Pointer({ wheel_delta: { x: 40.0, y: -80.0 }, .. })) =>
      ()
    _ => fail("expected scroll pointer event")
  }
  let blur = HostEvent::Focus(
    HostFocusEvent::new(
      focused=false,
      pointer_cancel_position=Some(@core.Point::new(x=2.0, y=3.0)),
    ),
  ).to_core()
  match blur {
    Some(@core.AppEvent::Pointer({ phase: @core.PointerPhase::Cancel, .. })) =>
      ()
    _ => fail("expected blur cancel pointer event")
  }
}
