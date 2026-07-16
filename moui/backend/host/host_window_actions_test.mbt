///|
test "host window actions enqueue scene opens on the shared queue" {
  let queue = HostWindowRequestQueue::new()
  let actions = HostWindowActions::new(queue~)
  actions.open(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=420.0, height=320.0),
    ),
  )
  match queue.drain()[0] {
    HostWindowRequest::OpenWindow({ title, scene, metrics, .. }) => {
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
  let queue = HostWindowRequestQueue::new()
  let actions = HostWindowActions::new(queue~)
  let id = HostWindowId::new(7)
  actions.focus(id)
  actions.set_primary(id)
  actions.minimize(id)
  actions.show(id)
  actions.resize(
    id,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
  )
  actions.close(id)
  let drained = queue.drain()
  inspect(drained.length(), content="6")
  match drained[0] {
    HostWindowRequest::FocusWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected focus")
  }
  match drained[1] {
    HostWindowRequest::SetPrimaryWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected set primary")
  }
  match drained[2] {
    HostWindowRequest::MinimizeWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected minimize")
  }
  match drained[3] {
    HostWindowRequest::ShowWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected show")
  }
  match drained[4] {
    HostWindowRequest::ResizeWindow(window_id, metrics) => {
      inspect(window_id.value, content="7")
      assert_true(
        metrics.logical_size == @core.Size::new(width=800.0, height=600.0),
      )
    }
    _ => fail("expected resize")
  }
  match drained[5] {
    HostWindowRequest::CloseWindow(window_id) =>
      inspect(window_id.value, content="7")
    _ => fail("expected close")
  }
}
