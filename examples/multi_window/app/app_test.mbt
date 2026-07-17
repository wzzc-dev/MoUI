///|
test "main scene emits an inspector window request" {
  let queue = @host.HostWindowRequestQueue::new()
  let model = Model::new(Main, @host.HostWindowActions::new(queue~))
  ignore(update(model, OpenInspector))
  match queue.drain()[0] {
    @host.HostWindowRequest::OpenWindow({ title, scene, .. }) => {
      inspect(title, content="MoUI Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="shared:0")
    }
    _ => fail("expected inspector open request")
  }
}

///|
test "close and focus enqueue lifecycle requests" {
  let queue = @host.HostWindowRequestQueue::new()
  let windows = @host.HostWindowActions::new(queue~)
  // Use provisional ids (same path as the UI when the host has not reported
  // a window id back into the model).
  ignore(update(Model::new(Main, windows), FocusInspector))
  ignore(update(Model::new(Main, windows), CloseInspector))
  let drained = queue.drain()
  inspect(drained.length(), content="2")
  match drained[0] {
    @host.HostWindowRequest::FocusWindow(id) => inspect(id.value, content="2")
    _ => fail("expected focus")
  }
  match drained[1] {
    @host.HostWindowRequest::CloseWindow(id) => inspect(id.value, content="2")
    _ => fail("expected close")
  }
}

///|
test "shared counter updates without opening a window" {
  let queue = @host.HostWindowRequestQueue::new()
  let model = Model::new(Main, @host.HostWindowActions::new(queue~))
  let next = update(model, IncrementShared)
  inspect(next.shared_count, content="1")
  inspect(queue.pending_count(), content="0")
}

///|
test "scene decoder recognizes the sample scenes" {
  inspect(
    scene_from_host(@host.HostWindowScene::main()) == Some(Main),
    content="true",
  )
  inspect(
    scene_from_host(
      @host.HostWindowScene::new(scene_id="inspector", payload="main"),
    ) ==
    Some(Inspector("main")),
    content="true",
  )
  inspect(
    scene_from_host(@host.HostWindowScene::new(scene_id="unknown")) == None,
    content="true",
  )
}
