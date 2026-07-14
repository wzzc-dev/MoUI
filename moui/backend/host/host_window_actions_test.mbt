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
