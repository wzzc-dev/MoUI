///|
test "host window registry applies platform-neutral window requests" {
  let registry = WindowRegistry::new()
  let main = registry.open(
    title="Main",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
  )
  let request = @backend_host.WindowRequest::OpenWindow(
    @backend_host.WindowOpenRequest::new(
      title="Inspector",
      scene=@backend_host.WindowScene::new(
        scene_id="inspector",
        payload="outline",
      ),
      metrics=@core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=600.0),
      ),
      primary=true,
    ),
  )
  let inspector = match registry.apply_request(request) {
    @backend_host.WindowRequestResult::WindowOpened(id) => id
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
  match registry.apply_request(@backend_host.WindowRequest::FocusWindow(main)) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == main)
    _ => fail("expected focus request to update main window")
  }
  match registry.focused_window() {
    Some({ id, .. }) => assert_true(id == main)
    None => fail("expected focused main window")
  }
  let resized = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=900.0, height=700.0),
    scale_factor=2.0,
  )
  match
    registry.apply_request(
      @backend_host.WindowRequest::ResizeWindow(main, resized),
    ) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == main)
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
  match
    registry.apply_request(@backend_host.WindowRequest::MinimizeWindow(main)) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == main)
    _ => fail("expected minimize request to update main window")
  }
  match registry.lookup(main) {
    Some({ phase, .. }) =>
      assert_true(phase == @backend_host.WindowLifecyclePhase::WindowMinimized)
    None => fail("expected minimized main window")
  }
  match registry.apply_request(@backend_host.WindowRequest::ShowWindow(main)) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == main)
    _ => fail("expected show request to update main window")
  }
  match registry.lookup(main) {
    Some({ phase, .. }) =>
      assert_true(phase == @backend_host.WindowLifecyclePhase::WindowVisible)
    None => fail("expected visible main window")
  }
  match
    registry.apply_request(@backend_host.WindowRequest::SetPrimaryWindow(main)) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == main)
    _ => fail("expected set-primary request to update main window")
  }
  match registry.primary_window() {
    Some({ id, title, .. }) => {
      assert_true(id == main)
      inspect(title, content="Main")
    }
    None => fail("expected primary main window")
  }
  match
    registry.apply_request(@backend_host.WindowRequest::CloseWindow(inspector)) {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == inspector)
    _ => fail("expected close request to update inspector")
  }
  match registry.lookup(inspector) {
    Some({ phase, .. }) =>
      assert_true(
        phase == @backend_host.WindowLifecyclePhase::WindowCloseRequested,
      )
    None => fail("expected inspector close request phase")
  }
  match
    registry.apply_request(
      @backend_host.WindowRequest::FocusWindow(@backend_host.WindowId::new(404)),
    ) {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected rejected missing window request")
  }
}

///|
test "host window lifecycle rejects queued commands after platform close" {
  let registry = WindowRegistry::new()
  let closed = registry.open(
    title="Inspector",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  assert_true(registry.close(closed))
  match registry.lookup(closed) {
    Some({ phase, primary, .. }) => {
      assert_true(phase == @backend_host.WindowLifecyclePhase::WindowClosed)
      inspect(primary, content="false")
    }
    None => fail("expected closed window record before cleanup")
  }

  let queue = WindowRequestQueue::new()
  queue.focus_window(closed)
  queue.resize_window(
    closed,
    @core.SurfaceMetrics::from_logical(
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
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 1")
    _ => fail("expected focus rejection for closed window")
  }
  match completions[1].result {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot resize window: 1")
    _ => fail("expected resize rejection for closed window")
  }
  match completions[5].result {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
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
  let request = @backend_host.WindowOpenRequest::new(
    title="Main",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  inspect(request.scene.scene_id, content="main")
  inspect(request.scene.payload, content="")
}

///|
test "host window completion observers receive results and can unsubscribe" {
  let queue = WindowRequestQueue::new()
  let observed : Array[@backend_host.WindowRequestCompletion] = []
  let unsubscribe = queue.subscribe_completed(completion => {
    observed.push(completion)
  })
  let request = @backend_host.WindowRequest::FocusWindow(
    @backend_host.WindowId::new(7),
  )
  queue.record_result(
    request,
    @backend_host.WindowRequestResult::WindowUpdated(
      @backend_host.WindowId::new(7),
    ),
  )
  inspect(observed.length(), content="1")
  inspect(queue.completed_count(), content="1")
  unsubscribe()
  queue.record_result(
    request,
    @backend_host.WindowRequestResult::WindowRejected("closed"),
  )
  inspect(observed.length(), content="1")
  inspect(queue.completed_count(), content="2")
}

///|
test "host window request queue drains platform-neutral window requests" {
  let queue = WindowRequestQueue::new()
  inspect(queue.is_empty(), content="true")
  queue.open_window(
    title="Inspector",
    scene=@backend_host.WindowScene::new(
      scene_id="inspector",
      payload="right-pane",
    ),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  let window_id = @backend_host.WindowId::new(7)
  queue.focus_window(window_id)
  queue.resize_window(
    window_id,
    @core.SurfaceMetrics::from_logical(
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
    @backend_host.WindowRequest::OpenWindow({ title, scene, primary, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="right-pane")
      inspect(primary, content="true")
    }
    _ => fail("expected open window request")
  }
  match requests[1] {
    @backend_host.WindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected focus window request")
  }
  match requests[2] {
    @backend_host.WindowRequest::ResizeWindow(id, metrics) => {
      assert_true(id == window_id)
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    }
    _ => fail("expected resize window request")
  }
  match requests[3] {
    @backend_host.WindowRequest::MinimizeWindow(id) =>
      assert_true(id == window_id)
    _ => fail("expected minimize window request")
  }
  match requests[4] {
    @backend_host.WindowRequest::ShowWindow(id) => assert_true(id == window_id)
    _ => fail("expected show window request")
  }
  match requests[5] {
    @backend_host.WindowRequest::SetPrimaryWindow(id) =>
      assert_true(id == window_id)
    _ => fail("expected set primary window request")
  }
  match requests[6] {
    @backend_host.WindowRequest::CloseWindow(id) => assert_true(id == window_id)
    _ => fail("expected close window request")
  }
}

///|
test "host window request queue records ordered platform completions" {
  let queue = WindowRequestQueue::new()
  queue.open_window(
    title="Inspector",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  let window_id = @backend_host.WindowId::new(2)
  queue.focus_window(window_id)
  let drained = queue.drain()
  queue.record_result(
    drained[0],
    @backend_host.WindowRequestResult::WindowRejected(
      "open window requests require multi-window host support",
    ),
  )
  queue.record_result(
    drained[1],
    @backend_host.WindowRequestResult::WindowUpdated(window_id),
  )
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="2")
  let completed = queue.drain_completed()
  inspect(queue.completed_count(), content="0")
  match completed[0].request {
    @backend_host.WindowRequest::OpenWindow({ title, .. }) =>
      inspect(title, content="Inspector")
    _ => fail("expected completed open-window request")
  }
  match completed[0].result {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(
        message,
        content="open window requests require multi-window host support",
      )
    _ => fail("expected completed open-window rejection")
  }
  match completed[1].request {
    @backend_host.WindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected completed focus-window request")
  }
  match completed[1].result {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == window_id)
    _ => fail("expected completed focus-window update")
  }
}

///|
test "host window request queue drains with shared completion handler" {
  let queue = WindowRequestQueue::new()
  let existing = @backend_host.WindowId::new(1)
  queue.focus_window(existing)
  queue.close_window(@backend_host.WindowId::new(404))
  let completions = queue.drain_with_handler(request => {
    match request {
      @backend_host.WindowRequest::FocusWindow(id) =>
        @backend_host.WindowRequestResult::WindowUpdated(id)
      @backend_host.WindowRequest::CloseWindow(_) =>
        @backend_host.WindowRequestResult::WindowRejected("missing window")
      _ =>
        @backend_host.WindowRequestResult::WindowRejected("unexpected request")
    }
  })
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="2")
  inspect(completions.length(), content="2")
  match completions[0].result {
    @backend_host.WindowRequestResult::WindowUpdated(id) =>
      assert_true(id == existing)
    _ => fail("expected focus completion")
  }
  match completions[1].request {
    @backend_host.WindowRequest::CloseWindow(id) =>
      inspect(id.value, content="404")
    _ => fail("expected close request completion")
  }
  match queue.drain_completed()[1].result {
    @backend_host.WindowRequestResult::WindowRejected(message) =>
      inspect(message, content="missing window")
    _ => fail("expected recorded close rejection")
  }
  inspect(queue.completed_count(), content="0")
}
