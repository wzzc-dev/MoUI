///|
test "host window actions enqueue scene opens on the shared queue" {
  let queue = WindowRequestQueue::new()
  let actions = WindowActions::new(queue~)
  actions.open(
    title="Inspector",
    scene=@backend_host.WindowScene::new(
      scene_id="inspector",
      payload="outline",
    ),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=420.0, height=320.0),
    ),
  )
  match queue.drain()[0] {
    @backend_host.WindowRequest::OpenWindow({ title, scene, metrics, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="outline")
      assert_true(
        metrics.logical_size == @core.Size::new(width=420.0, height=320.0),
      )
    }
    _ => fail("expected inspector open request")
  }
}

///|
test "host window actions enqueue lifecycle requests" {
  let queue = WindowRequestQueue::new()
  let actions = WindowActions::new(queue~)
  let id = @backend_host.WindowId::new(7)
  actions.focus(id)
  actions.set_primary(id)
  actions.minimize(id)
  actions.show(id)
  actions.resize(
    id,
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
  )
  actions.close(id)
  let drained = queue.drain()
  inspect(drained.length(), content="6")
  match drained[0] {
    @backend_host.WindowRequest::FocusWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected focus")
  }
  match drained[1] {
    @backend_host.WindowRequest::SetPrimaryWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected set primary")
  }
  match drained[2] {
    @backend_host.WindowRequest::MinimizeWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected minimize")
  }
  match drained[3] {
    @backend_host.WindowRequest::ShowWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected show")
  }
  match drained[4] {
    @backend_host.WindowRequest::ResizeWindow(window_id, metrics) => {
      inspect(window_id.value, content="7")
      assert_true(
        metrics.logical_size == @core.Size::new(width=800.0, height=600.0),
      )
    }
    _ => fail("expected resize")
  }
  match drained[5] {
    @backend_host.WindowRequest::CloseWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected close")
  }
}
