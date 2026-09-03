///|
test "host app info records shared model boundaries" {
  let info = @backend_host.HostAppInfo::new(
    backend=@backend_host.HostBackendKind::Native,
    description="native host",
  )
  assert_true(info.backend == @backend_host.HostBackendKind::Native)
  inspect(info.uses_shared_event_model, content="true")
  inspect(info.uses_shared_surface_model, content="true")
  inspect(info.uses_shared_input_model, content="true")
}

///|
test "host capability summary combines service input and window readiness" {
  let services = @backend_host.HostServiceCapabilities::new(
    clipboard=true,
    file_dialogs=true,
    open_url=true,
    system_theme=true,
  )
  let input = @backend_host.HostInputCapabilities::new(
    pointer=true,
    keyboard=true,
    focus=true,
    text_input=true,
    drag_drop=true,
  )
  let summary = @backend_host.HostCapabilitySummary::from_contracts(
    info=@backend_host.HostAppInfo::new(
      backend=@backend_host.HostBackendKind::Web,
      description="browser host",
    ),
    services~,
    input~,
    label="Web host",
    window_lifecycle=true,
    multi_window=true,
    async_services=true,
    host_modal_available=true,
  )
  inspect(summary.backend.label(), content="Web")
  inspect(summary.label, content="Web host")
  inspect(summary.service_count(), content="4")
  inspect(summary.input_count(), content="6")
  inspect(summary.has_required_app_basics(), content="true")
  inspect(summary.multi_window, content="true")
  inspect(summary.async_services, content="true")
  inspect(summary.services.enabled_labels().length(), content="4")
  assert_true(summary.input.enabled_labels().any(label => label == "drag/drop"))
  let preflight = summary.preflight_fields()
  assert_true(preflight.contains("host=Web host"))
  assert_true(
    preflight.contains(
      "host_services=clipboard,file dialogs,open URL,system theme",
    ),
  )
  assert_true(preflight.contains("clipboard=available"))
  assert_true(preflight.contains("menu_service=gap"))
  assert_true(preflight.contains("file_dialogs=available"))
  assert_true(preflight.contains("open_url=available"))
  assert_true(preflight.contains("system_theme=available"))
  assert_true(preflight.contains("async_services=available"))
  assert_true(preflight.contains("window_lifecycle=available"))
  assert_true(preflight.contains("multi_window=available"))
  assert_true(preflight.contains("text_input=available"))
  assert_true(preflight.contains("ime=gap"))
  assert_true(preflight.contains("drag_drop=available"))
  assert_true(preflight.contains("native_context_menu=gap"))
  assert_true(preflight.contains("host_modal=available"))
  assert_true(preflight.contains("native_accessibility=gap"))
  let unmodal = @backend_host.HostCapabilitySummary::from_contracts(
    info=@backend_host.HostAppInfo::new(
      backend=@backend_host.HostBackendKind::Web,
      description="browser host",
    ),
    services~,
    input~,
  )
  assert_true(unmodal.preflight_fields().contains("host_modal=gap"))
}

///|
test "host capability summary reports unavailable host" {
  let summary = @backend_host.HostCapabilitySummary::unavailable()
  inspect(summary.backend.label(), content="Test")
  inspect(summary.service_count(), content="0")
  inspect(summary.input_count(), content="0")
  inspect(summary.has_required_app_basics(), content="false")
  inspect(summary.services.enabled_labels().length(), content="0")
  let preflight = summary.preflight_fields()
  assert_true(preflight.contains("host=Unavailable host"))
  assert_true(preflight.contains("host_services=none"))
  assert_true(preflight.contains("host_input=none"))
  assert_true(preflight.contains("clipboard=gap"))
  assert_true(preflight.contains("window_lifecycle=gap"))
  assert_true(preflight.contains("native_accessibility=gap"))
}

///|
test "input host owns capabilities focus modifiers and text input gating" {
  let input = InputState::new()
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
    Some(@backend_host.Event::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
  input.set_modifiers(@core.KeyModifiers::new(shift=true))
  let key_event = input.keyboard_event(key="A", text=Some("A"))
  match key_event {
    Some(@backend_host.Event::Keyboard(event)) => {
      inspect(event.key, content="A")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
  match input.insert_text("A") {
    Some(@backend_host.Event::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="A")
    _ => fail("expected focused text input")
  }
  match input.focus_event(focused=false) {
    Some(@backend_host.Event::Focus({ focused: false, .. })) => ()
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
      @backend_host.Event::DragDrop(
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
      @backend_host.Event::DragDrop(
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
test "host maps touch button events to core pointer phases" {
  let touch_down = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(24.0, 48.0),
      true,
      @window_core.ButtonSource::Touch(@window_core.FingerId::from_raw(0), None),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match touch_down {
    Some(
      @backend_host.Event::Pointer(
        {
          phase: @core.PointerPhase::Down,
          button: 0,
          position: { x: 12.0, y: 24.0 },
          ..,
        }
      )
    ) => ()
    _ => fail("expected touch down pointer event")
  }
  let touch_up = window_event_to_host(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Released,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(24.0, 48.0),
      true,
      @window_core.ButtonSource::Touch(@window_core.FingerId::from_raw(0), None),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match touch_up {
    Some(@backend_host.Event::Pointer({ phase: @core.PointerPhase::Up, .. })) =>
      ()
    _ => fail("expected touch up pointer event")
  }
}

///|
test "surface host resizes through host event" {
  let surface = SurfaceState::new(
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=10.0, height=10.0),
    ),
    owns_surface=true,
  )
  let event = surface.resize(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=20.0, height=12.0),
      scale_factor=2.0,
    ),
  )
  match event {
    @backend_host.Event::Resized(metrics) => {
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
test "window theme change maps to host theme event" {
  let event = window_event_to_host(
    @window_core.WindowEvent::ThemeChanged(@window_core.Theme::Dark),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@backend_host.Event::ThemeChanged(@core.ColorScheme::Dark)) => ()
    _ => fail("expected dark host theme event")
  }
  match event.unwrap().to_core() {
    None => ()
    Some(_) => fail("theme changes are handled by the host runtime driver")
  }
}
