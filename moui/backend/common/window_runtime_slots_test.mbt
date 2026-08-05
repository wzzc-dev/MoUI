///|
test "host window runtime slots manage multiple window drivers" {
  let registry = WindowRegistry::new()
  let slots = WindowRuntimeSlots::new()
  inspect(slots.is_empty(), content="true")
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    @runtime.WindowSceneResolution::SceneResolved(
      @runtime.WindowSceneInstance::new(
        request~,
        runtime=window_test_runtime(
          root=@views.empty(),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let main_request = @backend_host.WindowOpenRequest::new(
    title="Main",
    scene=@backend_host.WindowScene::main(),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
    primary=true,
  )
  let main_redraws = Ref(0)
  let main_slot = match resolve_open_request(registry, main_request, resolver) {
    @runtime.WindowOpenResolution::OpenResolved(resolved) =>
      WindowRuntimeSlot::from_resolved_open(resolved, schedule_redraw=() => {
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

  let inspector_request = @backend_host.WindowOpenRequest::new(
    title="Inspector",
    scene=@backend_host.WindowScene::new(
      scene_id="inspector",
      payload="outline",
    ),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
  )
  let inspector_redraws = Ref(0)
  let inspector_slot = match
    resolve_open_request(registry, inspector_request, resolver) {
    @runtime.WindowOpenResolution::OpenResolved(resolved) =>
      WindowRuntimeSlot::from_resolved_open(resolved, schedule_redraw=() => {
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
      @backend_host.Event::Focus(
        @backend_host.HostFocusEvent::new(focused=true),
      ),
    ),
  )
  match slots.focused_slot() {
    Some({ id, record, .. }) => {
      assert_true(id == inspector_slot.id)
      assert_true(
        record.phase == @backend_host.WindowLifecyclePhase::WindowFocused,
      )
    }
    None => fail("expected focused inspector slot")
  }
  match slots.lookup(main_slot.id) {
    Some({ record: { phase, .. }, .. }) =>
      assert_true(phase == @backend_host.WindowLifecyclePhase::WindowVisible)
    None => fail("expected main slot")
  }
  inspect(
    slots.apply_host_event(
      registry,
      inspector_slot.id,
      @backend_host.Event::RedrawRequested,
    ),
    content="false",
  )
  match slots.lookup(inspector_slot.id) {
    Some(slot) => slot.driver.request_redraw()
    None => fail("expected inspector slot")
  }
  inspect(inspector_redraws.val, content="1")

  match
    slots.apply_request(
      registry,
      @backend_host.WindowRequest::ResizeWindow(
        inspector_slot.id,
        @core.SurfaceMetrics::from_logical(
          size=@core.Size::new(width=420.0, height=500.0),
        ),
      ),
    ) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == inspector_slot.id)
    _ => fail("expected resize request to update inspector slot")
  }
  match slots.lookup(inspector_slot.id) {
    Some({ record: { metrics, .. }, .. }) =>
      assert_true(
        metrics.logical_size == @core.Size::new(width=420.0, height=500.0),
      )
    None => fail("expected resized inspector slot")
  }
  match
    slots.apply_request(
      registry,
      @backend_host.WindowRequest::SetPrimaryWindow(inspector_slot.id),
    ) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == inspector_slot.id)
    _ => fail("expected set-primary request to update inspector slot")
  }
  match slots.lookup(main_slot.id) {
    Some({ record: { primary, .. }, .. }) => inspect(primary, content="false")
    None => fail("expected main slot")
  }
  match slots.primary_slot() {
    Some({ id, record: { primary, .. }, .. }) => {
      assert_true(id == inspector_slot.id)
      inspect(primary, content="true")
    }
    None => fail("expected primary inspector slot")
  }
  match
    slots.apply_request(
      registry,
      @backend_host.WindowRequest::FocusWindow(@backend_host.WindowId::new(404)),
    ) {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected missing request rejection")
  }

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
      @backend_host.WindowId::new(404),
      driver=main_slot.driver,
    ),
    content="false",
  )
  inspect(
    slots.sync_from_registry(registry, @backend_host.WindowId::new(404)),
    content="false",
  )
  inspect(main_redraws.val, content="0")
}

///|
test "host runtime driver exposes runtime state for platform slots" {
  let runtime = window_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let dark = runtime.environment().with_system_scheme(@core.ColorScheme::Dark)
  driver.set_environment(dark)
  assert_true(driver.environment().color_scheme() == @core.ColorScheme::Dark)
  assert_true(runtime.environment().color_scheme() == @core.ColorScheme::Dark)
  driver.set_text_system(@core.TextSystem::fallback())
  assert_true(driver.focused_text_input() == runtime.focused_text_input())
}
