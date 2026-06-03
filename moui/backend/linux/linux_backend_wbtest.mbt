///|
test "linux host options carry optional scene resolver and first-frame smoke" {
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match LinuxHostAppOptions::new().scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Linux scene resolver rejection")
  }
  assert_false(LinuxHostAppOptions::new().exit_after_first_present)
  let resolver = @host.HostWindowSceneResolver::new(resolve=request => {
    @host.HostWindowSceneResolution::SceneResolved(
      @host.HostWindowSceneInstance::new(
        request~,
        runtime=@core.AppRuntime::new_view(
          root=(@core.View::empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = LinuxHostAppOptions::new(
    scene_resolver=resolver,
    exit_after_first_present=true,
  )
  assert_true(options.exit_after_first_present)
  match options.scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Linux scene resolver")
  }
}
