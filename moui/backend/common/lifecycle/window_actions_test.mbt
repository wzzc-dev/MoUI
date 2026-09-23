///|
test "host window actions enqueue scene opens on the shared queue" {
  let queue = @lifecycle.WindowRequestQueue::new()
  let actions = @lifecycle.WindowActions::new(queue~)
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
    OpenWindow({ title, scene, metrics, .. }) => {
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
  let queue = @lifecycle.WindowRequestQueue::new()
  let actions = @lifecycle.WindowActions::new(queue~)
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
    FocusWindow(window_id) => inspect(window_id.value, content="7")
    _ => fail("expected focus")
  }
  match drained[1] {
    SetPrimaryWindow(window_id) => inspect(window_id.value, content="7")
    _ => fail("expected set primary")
  }
  match drained[2] {
    MinimizeWindow(window_id) => inspect(window_id.value, content="7")
    _ => fail("expected minimize")
  }
  match drained[3] {
    ShowWindow(window_id) => inspect(window_id.value, content="7")
    _ => fail("expected show")
  }
  match drained[4] {
    ResizeWindow(window_id, metrics) => {
      inspect(window_id.value, content="7")
      assert_true(
        metrics.logical_size == @core.Size::new(width=800.0, height=600.0),
      )
    }
    _ => fail("expected resize")
  }
  match drained[5] {
    CloseWindow(window_id) => inspect(window_id.value, content="7")
    _ => fail("expected close")
  }
}
