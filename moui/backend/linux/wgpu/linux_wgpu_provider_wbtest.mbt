///|
test "linux wgpu options default to platform text and host resolver" {
  let options = LinuxWgpuAppOptions::new()
  assert_true(
    options.text_engine ==
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
  )
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match options.scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Linux WGPU scene resolver rejection")
  }
}
