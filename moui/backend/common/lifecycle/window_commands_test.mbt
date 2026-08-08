///|
test "host window commands wrap queue request helpers" {
  let commands = WindowCommands::new()
  inspect(commands.is_empty(), content="true")
  commands.open(
    title="Inspector",
    scene=@backend_host.WindowScene::new(scene_id="inspector", payload="debug"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  let window_id = @backend_host.WindowId::new(9)
  commands.focus(window_id)
  commands.resize(
    window_id,
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  commands.minimize(window_id)
  commands.show(window_id)
  commands.set_primary(window_id)
  commands.close(window_id)
  inspect(commands.pending_count(), content="7")
  let requests = commands.drain()
  inspect(commands.pending_count(), content="0")
  match requests[0] {
    @backend_host.WindowRequest::OpenWindow({ title, scene, primary, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="debug")
      inspect(primary, content="true")
    }
    _ => fail("expected open request")
  }
  match requests[1] {
    @backend_host.WindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected focus request")
  }
  match requests[2] {
    @backend_host.WindowRequest::ResizeWindow(id, metrics) => {
      assert_true(id == window_id)
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    }
    _ => fail("expected resize request")
  }
  match requests[6] {
    @backend_host.WindowRequest::CloseWindow(id) => assert_true(id == window_id)
    _ => fail("expected close request")
  }
}

///|
test "host window commands drain to registry with ordered completions" {
  let registry = WindowRegistry::new()
  let commands = WindowCommands::new()
  commands.open(
    title="Main",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=480.0, height=320.0),
    ),
  )
  let missing = @backend_host.WindowId::new(404)
  commands.focus(missing)
  let completions = commands.drain_to_registry(registry)
  inspect(commands.pending_count(), content="0")
  inspect(commands.completed_count(), content="2")
  inspect(completions.length(), content="2")
  match completions[0].result {
    @backend_host.WindowRequestResult::WindowOpened(id) =>
      inspect(id.value, content="1")
    _ => fail("expected opened window")
  }
  match completions[1].result {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected missing-window rejection")
  }
  inspect(registry.open_window_count(), content="1")
  let completed = commands.drain_completed()
  inspect(completed.length(), content="2")
  inspect(commands.completed_count(), content="0")
}

///|
test "host window commands can drain through runtime slots" {
  let registry = WindowRegistry::new()
  let opened = registry.open(
    title="Main",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  let slots = WindowRuntimeSlots::new()
  let runtime = window_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  assert_true(
    slots.insert_from_registry(
      registry,
      opened,
      driver=@runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    ),
  )
  let commands = WindowCommands::new()
  commands.resize(
    opened,
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  commands.close(@backend_host.WindowId::new(404))
  let completions = drain_to_runtime_slots(commands, registry, slots)
  inspect(completions.length(), content="2")
  match completions[0].result {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == opened)
    _ => fail("expected resize update")
  }
  match slots.lookup(opened) {
    Some({ record: { metrics, .. }, .. }) =>
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    None => fail("expected synced runtime slot")
  }
  match completions[1].result {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot close window: 404")
    _ => fail("expected close rejection")
  }
}
