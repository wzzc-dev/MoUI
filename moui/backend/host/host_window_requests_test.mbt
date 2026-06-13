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
test "host window lifecycle rejects queued commands after platform close" {
  let registry = HostWindowRegistry::new()
  let closed = registry.open(
    title="Inspector",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  assert_true(registry.close(closed))
  match registry.lookup(closed) {
    Some({ phase, primary, .. }) => {
      assert_true(phase == HostWindowLifecyclePhase::WindowClosed)
      inspect(primary, content="false")
    }
    None => fail("expected closed window record before cleanup")
  }

  let queue = HostWindowRequestQueue::new()
  queue.focus_window(closed)
  queue.resize_window(
    closed,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
  )
  queue.minimize_window(closed)
  queue.show_window(closed)
  queue.set_primary_window(closed)
  queue.close_window(closed)

  let completions = queue.drain_with_handler(request => {
    registry.apply_request(request)
  })
  inspect(queue.pending_count(), content="0")
  inspect(completions.length(), content="6")
  inspect(queue.completed_count(), content="6")
  match completions[0].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 1")
    _ => fail("expected focus rejection for closed window")
  }
  match completions[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot resize window: 1")
    _ => fail("expected resize rejection for closed window")
  }
  match completions[5].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot close window: 1")
    _ => fail("expected close rejection for closed window")
  }
  inspect(registry.remove_closed(), content="1")
  match registry.lookup(closed) {
    Some(_) => fail("expected closed window cleanup")
    None => ()
  }
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
test "host window commands wrap queue request helpers" {
  let commands = HostWindowCommands::new()
  inspect(commands.is_empty(), content="true")
  commands.open(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="debug"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  let window_id = HostWindowId::new(9)
  commands.focus(window_id)
  commands.resize(
    window_id,
    HostSurfaceMetrics::from_logical(
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
    HostWindowRequest::OpenWindow({ title, scene, primary, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="debug")
      inspect(primary, content="true")
    }
    _ => fail("expected open request")
  }
  match requests[1] {
    HostWindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected focus request")
  }
  match requests[2] {
    HostWindowRequest::ResizeWindow(id, metrics) => {
      assert_true(id == window_id)
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    }
    _ => fail("expected resize request")
  }
  match requests[6] {
    HostWindowRequest::CloseWindow(id) => assert_true(id == window_id)
    _ => fail("expected close request")
  }
}

///|
test "host window commands drain to registry with ordered completions" {
  let registry = HostWindowRegistry::new()
  let commands = HostWindowCommands::new()
  commands.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=480.0, height=320.0),
    ),
  )
  let missing = HostWindowId::new(404)
  commands.focus(missing)
  let completions = commands.drain_to_registry(registry)
  inspect(commands.pending_count(), content="0")
  inspect(commands.completed_count(), content="2")
  inspect(completions.length(), content="2")
  match completions[0].result {
    HostWindowRequestResult::WindowOpened(id) => inspect(id.value, content="1")
    _ => fail("expected opened window")
  }
  match completions[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
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
  let registry = HostWindowRegistry::new()
  let opened = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  let slots = HostWindowRuntimeSlots::new()
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  assert_true(
    slots.insert_from_registry(
      registry,
      opened,
      driver=HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    ),
  )
  let commands = HostWindowCommands::new()
  commands.resize(
    opened,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  commands.close(HostWindowId::new(404))
  let completions = commands.drain_to_runtime_slots(registry, slots)
  inspect(completions.length(), content="2")
  match completions[0].result {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == opened)
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
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot close window: 404")
    _ => fail("expected close rejection")
  }
}
