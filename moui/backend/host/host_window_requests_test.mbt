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
