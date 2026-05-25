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
test "host window open requests default to main scene" {
  let request = HostWindowOpenRequest::new(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  inspect(request.scene.scene_id, content="main")
  inspect(request.scene.payload, content="")
}

///|
test "host window request queue drains platform-neutral window requests" {
  let queue = HostWindowRequestQueue::new()
  inspect(queue.is_empty(), content="true")
  queue.open_window(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="right-pane"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  let window_id = HostWindowId::new(7)
  queue.focus_window(window_id)
  queue.resize_window(
    window_id,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  queue.minimize_window(window_id)
  queue.show_window(window_id)
  queue.set_primary_window(window_id)
  queue.close_window(window_id)
  inspect(queue.pending_count(), content="7")
  let requests = queue.drain()
  inspect(queue.pending_count(), content="0")
  match requests[0] {
    HostWindowRequest::OpenWindow({ title, scene, primary, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="right-pane")
      inspect(primary, content="true")
    }
    _ => fail("expected open window request")
  }
  match requests[1] {
    HostWindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected focus window request")
  }
  match requests[2] {
    HostWindowRequest::ResizeWindow(id, metrics) => {
      assert_true(id == window_id)
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    }
    _ => fail("expected resize window request")
  }
  match requests[3] {
    HostWindowRequest::MinimizeWindow(id) => assert_true(id == window_id)
    _ => fail("expected minimize window request")
  }
  match requests[4] {
    HostWindowRequest::ShowWindow(id) => assert_true(id == window_id)
    _ => fail("expected show window request")
  }
  match requests[5] {
    HostWindowRequest::SetPrimaryWindow(id) => assert_true(id == window_id)
    _ => fail("expected set primary window request")
  }
  match requests[6] {
    HostWindowRequest::CloseWindow(id) => assert_true(id == window_id)
    _ => fail("expected close window request")
  }
}

///|
test "host window request queue records ordered platform completions" {
  let queue = HostWindowRequestQueue::new()
  queue.open_window(
    title="Inspector",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  let window_id = HostWindowId::new(2)
  queue.focus_window(window_id)
  let drained = queue.drain()
  queue.record_result(
    drained[0],
    HostWindowRequestResult::WindowRejected(
      "open window requests require multi-window host support",
    ),
  )
  queue.record_result(
    drained[1],
    HostWindowRequestResult::WindowUpdated(window_id),
  )
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="2")
  let completed = queue.drain_completed()
  inspect(queue.completed_count(), content="0")
  match completed[0].request {
    HostWindowRequest::OpenWindow({ title, .. }) =>
      inspect(title, content="Inspector")
    _ => fail("expected completed open-window request")
  }
  match completed[0].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(
        message,
        content="open window requests require multi-window host support",
      )
    _ => fail("expected completed open-window rejection")
  }
  match completed[1].request {
    HostWindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected completed focus-window request")
  }
  match completed[1].result {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == window_id)
    _ => fail("expected completed focus-window update")
  }
}

///|
test "host window request queue drains with shared completion handler" {
  let queue = HostWindowRequestQueue::new()
  let existing = HostWindowId::new(1)
  queue.focus_window(existing)
  queue.close_window(HostWindowId::new(404))
  let completions = queue.drain_with_handler(request => {
    match request {
      HostWindowRequest::FocusWindow(id) =>
        HostWindowRequestResult::WindowUpdated(id)
      HostWindowRequest::CloseWindow(_) =>
        HostWindowRequestResult::WindowRejected("missing window")
      _ => HostWindowRequestResult::WindowRejected("unexpected request")
    }
  })
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="2")
  inspect(completions.length(), content="2")
  match completions[0].result {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == existing)
    _ => fail("expected focus completion")
  }
  match completions[1].request {
    HostWindowRequest::CloseWindow(id) => inspect(id.value, content="404")
    _ => fail("expected close request completion")
  }
  match queue.drain_completed()[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="missing window")
    _ => fail("expected recorded close rejection")
  }
  inspect(queue.completed_count(), content="0")
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
          runtime=@core.AppRuntime::new_spec(
            root=@core.ViewSpec::EmptySpec,
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
          runtime=@core.AppRuntime::new_spec(
            root=@core.ViewSpec::EmptySpec,
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

///|
test "host window runtime slots manage multiple window drivers" {
  let registry = HostWindowRegistry::new()
  let slots = HostWindowRuntimeSlots::new()
  inspect(slots.is_empty(), content="true")
  let resolver = HostWindowSceneResolver::new(resolve=request => {
    HostWindowSceneResolution::SceneResolved(
      HostWindowSceneInstance::new(
        request~,
        runtime=@core.AppRuntime::new_spec(
          root=@core.ViewSpec::EmptySpec,
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let main_request = HostWindowOpenRequest::new(
    title="Main",
    scene=HostWindowScene::main(),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
    primary=true,
  )
  let main_redraws = Ref(0)
  let main_slot = match registry.resolve_open_request(main_request, resolver) {
    HostWindowOpenResolution::OpenResolved(resolved) =>
      HostWindowRuntimeSlot::from_resolved_open(resolved, schedule_redraw=() => {
        main_redraws.val = main_redraws.val + 1
      })
    _ => fail("expected main runtime slot")
  }
  assert_true(
    slots.insert_from_registry(registry, main_slot.id, driver=main_slot.driver),
  )
  inspect(
    slots.insert_from_registry(registry, main_slot.id, driver=main_slot.driver),
    content="false",
  )

  let inspector_request = HostWindowOpenRequest::new(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
  )
  let inspector_redraws = Ref(0)
  let inspector_slot = match
    registry.resolve_open_request(inspector_request, resolver) {
    HostWindowOpenResolution::OpenResolved(resolved) =>
      HostWindowRuntimeSlot::from_resolved_open(resolved, schedule_redraw=() => {
        inspector_redraws.val = inspector_redraws.val + 1
      })
    _ => fail("expected inspector runtime slot")
  }
  assert_true(slots.insert(inspector_slot))
  inspect(slots.count(), content="2")
  match slots.primary_slot() {
    Some({ record: { title, .. }, .. }) => inspect(title, content="Main")
    None => fail("expected primary slot")
  }

  assert_true(
    slots.apply_host_event(
      registry,
      inspector_slot.id,
      HostEvent::Focus(HostFocusEvent::new(focused=true)),
    ),
  )
  match slots.focused_slot() {
    Some({ id, record, .. }) => {
      assert_true(id == inspector_slot.id)
      assert_true(record.phase == HostWindowLifecyclePhase::WindowFocused)
    }
    None => fail("expected focused inspector slot")
  }
  inspect(
    slots.apply_host_event(
      registry,
      inspector_slot.id,
      HostEvent::RedrawRequested,
    ),
    content="false",
  )
  match slots.lookup(inspector_slot.id) {
    Some(slot) => slot.driver.request_redraw()
    None => fail("expected inspector slot")
  }
  inspect(inspector_redraws.val, content="1")

  assert_true(registry.close(main_slot.id))
  assert_true(slots.sync_from_registry(registry, main_slot.id))
  inspect(slots.remove_closed(), content="1")
  inspect(slots.count(), content="1")
  match slots.remove(inspector_slot.id) {
    Some(slot) => inspect(slot.record.title, content="Inspector")
    None => fail("expected removed inspector slot")
  }
  inspect(slots.count(), content="0")
  inspect(
    slots.insert_from_registry(
      registry,
      HostWindowId::new(404),
      driver=main_slot.driver,
    ),
    content="false",
  )
  inspect(
    slots.sync_from_registry(registry, HostWindowId::new(404)),
    content="false",
  )
  inspect(main_redraws.val, content="0")
}

///|
test "host window registry applies platform-neutral window requests" {
  let registry = HostWindowRegistry::new()
  let main = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
  )
  let request = HostWindowRequest::OpenWindow(
    HostWindowOpenRequest::new(
      title="Inspector",
      scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
      metrics=HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=600.0),
      ),
      primary=true,
    ),
  )
  let inspector = match registry.apply_request(request) {
    HostWindowRequestResult::WindowOpened(id) => id
    _ => fail("expected opened inspector window")
  }
  match registry.primary_window() {
    Some({ id, title, scene, .. }) => {
      assert_true(id == inspector)
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="outline")
    }
    None => fail("expected primary inspector window")
  }
  match registry.apply_request(HostWindowRequest::FocusWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected focus request to update main window")
  }
  match registry.focused_window() {
    Some({ id, .. }) => assert_true(id == main)
    None => fail("expected focused main window")
  }
  let resized = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=900.0, height=700.0),
    scale_factor=2.0,
  )
  match registry.apply_request(HostWindowRequest::ResizeWindow(main, resized)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected resize request to update main window")
  }
  match registry.lookup(main) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=900.0, height=700.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=1800.0, height=1400.0),
      )
    }
    None => fail("expected resized main window")
  }
  match registry.apply_request(HostWindowRequest::MinimizeWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected minimize request to update main window")
  }
  match registry.lookup(main) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowMinimized)
    None => fail("expected minimized main window")
  }
  match registry.apply_request(HostWindowRequest::ShowWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected show request to update main window")
  }
  match registry.lookup(main) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowVisible)
    None => fail("expected visible main window")
  }
  match registry.apply_request(HostWindowRequest::SetPrimaryWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected set-primary request to update main window")
  }
  match registry.primary_window() {
    Some({ id, title, .. }) => {
      assert_true(id == main)
      inspect(title, content="Main")
    }
    None => fail("expected primary main window")
  }
  match registry.apply_request(HostWindowRequest::CloseWindow(inspector)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == inspector)
    _ => fail("expected close request to update inspector")
  }
  match registry.lookup(inspector) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowCloseRequested)
    None => fail("expected inspector close request phase")
  }
  match
    registry.apply_request(
      HostWindowRequest::FocusWindow(HostWindowId::new(404)),
    ) {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected rejected missing window request")
  }
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
test "host service bridge applies system theme to runtime environment" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(system_theme=true),
    handle=request => {
      match request {
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  match bridge.query_system_theme() {
    Some(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  let environment = @core.Environment::default()
    .with_locale("zh-CN")
    .with_text_scale(1.25)
  let updated = bridge.environment_with_system_theme(environment)
  assert_true(updated.color_scheme == @core.ColorScheme::Dark)
  assert_true(updated.theme.scheme == @core.ColorScheme::Dark)
  inspect(updated.locale, content="zh-CN")
  inspect(updated.text_scale, content="1.25")

  let unavailable = HostServiceBridge::unavailable()
  let unchanged = unavailable.environment_with_system_theme(environment)
  assert_true(unchanged == environment)
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
test "host driver applies theme change to runtime environment" {
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let result = driver.dispatch(HostEvent::ThemeChanged(@core.ColorScheme::Dark))
  assert_true(runtime.environment().color_scheme == @core.ColorScheme::Dark)
  assert_true(runtime.environment().theme.scheme == @core.ColorScheme::Dark)
  inspect(result.redraw_requested, content="true")
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
test "host async service queue tracks pending and completed responses" {
  let queue = HostServiceAsyncQueue::new()
  let first = match
    queue.submit(HostServiceRequest::OpenUrl("https://example.test")) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending open-url request")
  }
  inspect(first.value, content="1")
  inspect(queue.pending_count(), content="1")
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.outstanding_count(), content="1")
  inspect(queue.completed_count(), content="0")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  inspect(queue.pending_count(), content="0")
  inspect(queue.in_flight_count(), content="1")
  assert_true(queue.complete(first, HostServiceResponse::UrlOpened))
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(first) {
    Some({ request: HostServiceRequest::OpenUrl(url), response, .. }) => {
      inspect(url, content="https://example.test")
      match response {
        HostServiceResponse::UrlOpened => ()
        _ => fail("expected completed open-url response")
      }
    }
    _ => fail("expected completed open-url response")
  }
  match pending[0].request {
    HostServiceRequest::OpenUrl(url) =>
      inspect(url, content="https://example.test")
    _ => fail("expected pending open-url request")
  }

  let second = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  assert_true(
    queue.complete(
      second,
      HostServiceResponse::FileDialogSelection(["/tmp/note.md"]),
    ),
  )
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(second) {
    Some({ request: HostServiceRequest::FileDialog(_), response, .. }) =>
      match response {
        HostServiceResponse::FileDialogSelection(paths) =>
          inspect(paths[0], content="/tmp/note.md")
        _ => fail("expected completed file selection")
      }
    _ => fail("expected completed file-dialog response")
  }
  inspect(queue.completed_count(), content="0")
  inspect(
    queue.reject(HostServiceRequestId::new(404), "missing request"),
    content="false",
  )
}

///|
test "host driver applies async clipboard read completion to focused text" {
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
      border: None,
      focused_border: None,
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
  let queue = HostServiceAsyncQueue::new()
  let pending = match
    queue.submit(HostServiceRequest::Clipboard(HostClipboardRequest::ReadText)) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending clipboard read")
  }
  assert_true(
    queue.complete(pending, HostServiceResponse::ClipboardText("later")),
  )
  match queue.take_completed(pending) {
    Some(completion) =>
      ignore(
        driver.dispatch_service_completion(
          completion,
          HostServiceBridge::unavailable(),
        ),
      )
    None => fail("expected completed clipboard read")
  }
  inspect(text.get(), content="later")
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
test "host driver defers paste action command while clipboard read is pending" {
  let pasted = Ref(0)
  let queue = HostServiceAsyncQueue::new()
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Paste),
        handle=() => pasted.val = pasted.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Paste, bridge),
  )
  inspect(pasted.val, content="0")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(pending[0].id, HostServiceResponse::ClipboardText("delayed")),
  )
  for completion in queue.drain_completed() {
    ignore(driver.dispatch_service_completion(completion, bridge))
  }
  inspect(pasted.val, content="1")
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
