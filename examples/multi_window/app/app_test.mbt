///|
test "main scene emits an inspector window request" {
  let queue = @host.HostWindowRequestQueue::new()
  let model = Model::new(Main, @host.HostWindowActions::new(queue~))
  ignore(update(model, OpenInspector))
  match queue.drain()[0] {
    @host.HostWindowRequest::OpenWindow({ title, scene, .. }) => {
      inspect(title, content="MoUI Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="main")
    }
    _ => fail("expected inspector open request")
  }
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
    ) == Some(Inspector("main")),
    content="true",
  )
  inspect(
    scene_from_host(@host.HostWindowScene::new(scene_id="unknown")) == None,
    content="true",
  )
}
