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
test "host capability summary combines service input and window readiness" {
  let summary = HostCapabilitySummary::from_contracts(
    info=HostAppInfo::new(
      backend=HostBackendKind::Web,
      description="browser host",
    ),
    services=HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      open_url=true,
      system_theme=true,
    ),
    input=HostInputCapabilities::new(
      pointer=true,
      keyboard=true,
      focus=true,
      text_input=true,
      drag_drop=true,
    ),
    label="Web host",
    window_lifecycle=true,
    multi_window=true,
    async_services=true,
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
}

///|
test "host capability summary reports unavailable host" {
  let summary = HostCapabilitySummary::unavailable()
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
test "window theme change maps to host theme event" {
  let event = window_event_to_host(
    @window_core.WindowEvent::ThemeChanged(@window_core.Theme::Dark),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(HostEvent::ThemeChanged(@core.ColorScheme::Dark)) => ()
    _ => fail("expected dark host theme event")
  }
  match event.unwrap().to_core() {
    None => ()
    Some(_) => fail("theme changes are handled by the host runtime driver")
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
test "host platform window map routes platform window ids" {
  let map = HostPlatformWindowMap::new()
  inspect(map.is_empty(), content="true")
  let platform_main = @window_core.WindowId::from_raw(11)
  let platform_inspector = @window_core.WindowId::from_raw(12)
  let main = HostWindowId::new(1)
  let inspector = HostWindowId::new(2)
  assert_true(map.bind(platform_id=platform_main, host_id=main))
  inspect(
    map.bind(platform_id=platform_main, host_id=inspector),
    content="false",
  )
  inspect(
    map.bind(platform_id=platform_inspector, host_id=main),
    content="false",
  )
  assert_true(map.bind(platform_id=platform_inspector, host_id=inspector))
  inspect(map.count(), content="2")
  match map.lookup_host(platform_main) {
    Some(id) => assert_true(id == main)
    None => fail("expected main host id")
  }
  match map.lookup_platform(inspector) {
    Some(id) => assert_true(id == platform_inspector)
    None => fail("expected inspector platform id")
  }
  match map.remove_host(main) {
    Some(id) => assert_true(id == platform_main)
    None => fail("expected removed main platform id")
  }
  match map.lookup_host(platform_main) {
    Some(_) => fail("expected removed main host lookup")
    None => ()
  }
  match map.remove_platform(platform_inspector) {
    Some(id) => assert_true(id == inspector)
    None => fail("expected removed inspector host id")
  }
  inspect(map.is_empty(), content="true")
}

///|
test "host window scene resolver maps open requests to runtimes" {
  let resolver = HostWindowSceneResolver::new(resolve=request => {
    if request.scene.scene_id == "inspector" {
      HostWindowSceneResolution::SceneResolved(
        HostWindowSceneInstance::new(
          request~,
          runtime=host_test_runtime(
            root=@core.View::empty(),
            size=request.metrics.logical_size,
          ),
        ),
      )
    } else {
      HostWindowSceneResolution::SceneRejected(
        "unknown window scene: " + request.scene.scene_id,
      )
    }
  })
  let request = HostWindowOpenRequest::new(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
  )
  match resolver.resolve(request) {
    HostWindowSceneResolution::SceneResolved({ request, runtime }) => {
      inspect(request.title, content="Inspector")
      inspect(request.scene.payload, content="outline")
      assert_true(runtime.size() == @core.Size::new(width=360.0, height=480.0))
    }
    _ => fail("expected resolved inspector scene")
  }
  let unknown = HostWindowOpenRequest::new(
    title="Unknown",
    scene=HostWindowScene::new(scene_id="unknown"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match resolver.resolve(unknown) {
    HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="unknown window scene: unknown")
    _ => fail("expected unknown scene rejection")
  }
  match HostWindowSceneResolver::unavailable().resolve(request) {
    HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected unavailable resolver rejection")
  }
}

///|
test "host window registry resolves scenes before registering opened windows" {
  let registry = HostWindowRegistry::new()
  let resolver = HostWindowSceneResolver::new(resolve=request => {
    if request.scene.scene_id == "inspector" {
      HostWindowSceneResolution::SceneResolved(
        HostWindowSceneInstance::new(
          request~,
          runtime=host_test_runtime(
            root=@core.View::empty(),
            size=request.metrics.logical_size,
          ),
        ),
      )
    } else {
      HostWindowSceneResolution::SceneRejected(
        "unknown window scene: " + request.scene.scene_id,
      )
    }
  })
  let rejected = HostWindowOpenRequest::new(
    title="Unknown",
    scene=HostWindowScene::new(scene_id="unknown"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match registry.resolve_open_request(rejected, resolver) {
    HostWindowOpenResolution::OpenRejected(message) =>
      inspect(message, content="unknown window scene: unknown")
    _ => fail("expected rejected window scene")
  }
  inspect(registry.open_window_count(), content="0")

  let request = HostWindowOpenRequest::new(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
    primary=true,
  )
  match registry.resolve_open_request(request, resolver) {
    HostWindowOpenResolution::OpenResolved({ id, record, instance }) => {
      assert_true(id == record.id)
      inspect(record.title, content="Inspector")
      inspect(record.scene.scene_id, content="inspector")
      inspect(record.primary, content="true")
      assert_true(
        instance.runtime.size() == @core.Size::new(width=360.0, height=480.0),
      )
      let redraws = Ref(0)
      let slot = HostWindowRuntimeSlot::from_resolved_open(
        { id, record, instance },
        schedule_redraw=() => redraws.val = redraws.val + 1,
      )
      assert_true(slot.id == id)
      inspect(slot.record.scene.payload, content="outline")
      assert_true(
        slot.driver.size() == @core.Size::new(width=360.0, height=480.0),
      )
      slot.driver.request_redraw()
      inspect(redraws.val, content="1")
      let driver_backed = HostWindowRuntimeSlot::from_driver(
        record~,
        driver=slot.driver,
      )
      assert_true(driver_backed.id == id)
      assert_true(driver_backed.driver.size() == slot.driver.size())
    }
    _ => fail("expected resolved open window")
  }
  inspect(registry.open_window_count(), content="1")
}
