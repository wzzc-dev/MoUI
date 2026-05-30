///|
test "linux skia options default to system font resolution" {
  let options = LinuxSkiaAppOptions::new()
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::SystemFontMgr,
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
    _ => fail("expected default Linux Skia scene resolver rejection")
  }
}

///|
test "linux skia availability follows render skia backend info" {
  assert_true(
    @skia_renderer.backend_info().can_render == @skia_renderer.skia_available(),
  )
  assert_true(
    linux_skia_provider_ready() == @skia_renderer.backend_info().can_render,
  )
}

///|
test "linux skia preflight diagnostic describes unavailable renderer setup" {
  let message = linux_skia_unavailable_message()
  assert_true(message.contains("Linux Skia renderer selected"))
  assert_true(message.contains("skia_mbt/native is unavailable"))
  assert_true(message.contains("real Skia link flags"))
}
